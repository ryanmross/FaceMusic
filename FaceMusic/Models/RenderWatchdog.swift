//
//  RenderWatchdog.swift
//  FaceMusic
//
//  Created by Ryan Ross on 8/10/25.
//

import AVFoundation
import os.log
import os.signpost
import Foundation
import QuartzCore

/// Lightweight audio watchdog to help correlate UI events with audio glitches.
///
/// What it measures:
/// 1) Inter-buffer gap (time between consecutive taps) vs expected IO buffer period.
/// 2) Time spent inside the tap closure (as a proxy for per-buffer work on that thread).
/// 3) Emits signposts readable in Instruments (Logging/System Trace) and prints to console.
final class RenderWatchdog {
    static let shared = RenderWatchdog()

    // MARK: - Logging
    private let log = OSLog(subsystem: "com.RyanRoss.FaceMusic", category: "render")

    // MARK: - Timebase & Session
    private var timebase = mach_timebase_info_data_t(numer: 0, denom: 0)
    private var lastHostTime: UInt64?
    private var lastWhenHost: UInt64?
    private var sampleRate: Double = 48000
    private var expectedMsFromSession: Double?

    // MARK: - State
    private var isAttached = false
    private weak var tappedNode: AVAudioNode?

    // MARK: - Config
    struct Config {
        /// Additional cushion in ms before we consider a gap an XRUN (still applied after minOverrun checks).
        var gapToleranceMs: Double = 0.10
        /// Minimum absolute overrun (in ms) to count as an underrun (filters normal jitter around long buffers).
        var minOverrunMs: Double = 0.5
        /// Minimum relative overrun (as a fraction of expected) to count as an underrun.
        var minOverrunPercent: Double = 0.005  // 0.5% of expected
        /// Time window for considering a burst of underruns as a "glitch start".
        var glitchWindowSeconds: Double = 0.7
        /// Number of underruns within the window to declare glitching.
        var glitchBurstCount: Int = 3
        /// Time (s) with no underruns to consider glitch ended.
        var glitchQuiescentSeconds: Double = 0.5
        /// If true, expected inter-tap gap uses the **larger** of session IO and buffer-derived period.
        /// This avoids false positives when taps are on long internal buffers.
        var useMaxExpectedGap: Bool = true
        /// Emit a signpost if TapCPU exceeds this many ms (0 disables this check).
        var tapCpuWarnMs: Double = 1.5
    }

    var config = Config()

    // MARK: - Derived metrics (mutable)
    private var recentXrunTimes: [UInt64] = []   // host times of recent XRUNs
    private var recentOverruns: [(t: UInt64, overMs: Double)] = []
    private var glitching: Bool = false
    // Rolling stats for inter-tap deltas (ms)
    private var recentDeltaMs: [Double] = []
    private let maxRecentDelta = 50
    private var lastGlitchChangeHostTime: UInt64? = nil
    private var sampleCounter: UInt64 = 0

    /// Optional observer for UI to react to glitch state changes (e.g., show a badge)
    var onGlitchStateChanged: ((Bool) -> Void)?

    private init() {
        mach_timebase_info(&timebase)
    }

    // MARK: - Public API
    /// Attach a tap to the given node (typically the engine's mixer or output node)
    /// and start emitting signposts/console logs.
    func attach(to node: AVAudioNode, engine: AVAudioEngine) {
        guard !isAttached else { return }
        isAttached = true
        tappedNode = node

        // Reset transient metrics
        recentXrunTimes.removeAll(keepingCapacity: true)
        recentOverruns.removeAll(keepingCapacity: true)
        glitching = false
        lastGlitchChangeHostTime = nil
        lastHostTime = nil

        // Cache session characteristics for expected buffer period
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(true, options: [])
            expectedMsFromSession = session.ioBufferDuration * 1000.0
            sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        } catch {
            expectedMsFromSession = nil
        }

        let fmt = node.outputFormat(forBus: 0)

        os_signpost(.event, log: log, name: "WatchdogAttach", "rate=%{public}.0fHz sessionIO=%{public}.3fms bufCh=%{public}d",
                    sampleRate, expectedMsFromSession ?? -1, Int(fmt.channelCount))
        print("[RenderWatchdog] attach: sr=\(sampleRate), sessionIO=\(expectedMsFromSession ?? -1)ms, ch=\(fmt.channelCount)")

        node.installTap(onBus: 0, bufferSize: 0, format: fmt) { [weak self] buffer, when in
            guard let self else { return }

            // Signpost interval around tap work
            let spID = OSSignpostID(log: self.log)
            os_signpost(.begin, log: self.log, name: "TapProcessing", signpostID: spID)
            let start = mach_absolute_time()
            defer {
                let end = mach_absolute_time()
                let durMs = self.toMillis(end &- start)
                os_signpost(.end, log: self.log, name: "TapProcessing", signpostID: spID)
                os_signpost(.event, log: self.log, name: "TapCPU", "ms=%{public}.3f", durMs)
                if self.config.tapCpuWarnMs > 0, durMs >= self.config.tapCpuWarnMs {
                    os_signpost(.event, log: self.log, name: "TapCPUHigh", "ms=%{public}.3f", durMs)
                }
            }

            // Inter-buffer gap check (use render timestamp when.hostTime if available)
            let nowHost: UInt64 = (when.hostTime != 0) ? when.hostTime : mach_absolute_time()
            self.sampleCounter &+= 1
            defer { 
                self.lastHostTime = nowHost
                self.lastWhenHost = nowHost
            }

            if let last = self.lastWhenHost {
                // Observed gap (ms) based on host timestamps provided by the audio render callback
                let observedMs = self.toMillis(nowHost &- last)

                // Expected gap from buffer length and sample rate (ms) — this matches the tap cadence
                let expectedMsBuf = Double(buffer.frameLength) / self.sampleRate * 1000.0

                // Optionally compare against the session IO period and pick the larger if configured
                let sessionMs = self.expectedMsFromSession ?? 0
                let expectedMs = self.config.useMaxExpectedGap ? max(sessionMs, expectedMsBuf) : expectedMsBuf

                // Keep rolling window of observed deltas for adaptive deviation-based thresholding
                self.recentDeltaMs.append(observedMs)
                if self.recentDeltaMs.count > self.maxRecentDelta {
                    self.recentDeltaMs.removeFirst(self.recentDeltaMs.count - self.maxRecentDelta)
                }
                // Compute mean and stddev of recent deltas
                let mean = self.recentDeltaMs.reduce(0, +) / Double(self.recentDeltaMs.count)
                let variance = self.recentDeltaMs.reduce(0) { $0 + pow($1 - mean, 2) } / Double(max(1, self.recentDeltaMs.count - 1))
                let stddev = sqrt(variance)

                // Calculate overrun (observed - expected)
                let overMs = observedMs - expectedMs

                // Dynamic thresholds tuned for long (~100ms) buffers.
                // Base threshold is the greater of absolute floor and relative %, plus a small tolerance.
                let pctThresh = expectedMs * self.config.minOverrunPercent
                let absFloor = self.config.minOverrunMs
                let baseNeeded = max(absFloor, pctThresh) + self.config.gapToleranceMs
                // Also require deviation beyond recent jitter (use 1.5σ, clamped to a tiny floor).
                let devNeeded = max(0.15, 1.5 * stddev)
                let needed = max(baseNeeded, devNeeded)
                let meaningful = overMs >= needed

                // Occasionally sample gaps so we can verify expected vs observed in Instruments.
                if (self.sampleCounter & 0x0F) == 0 { // every 16 buffers
                    os_signpost(.event, log: self.log, name: "GapSample",
                                "obs=%{public}.3fms exp=%{public}.3fms over=%{public}.3fms std=%{public}.3f",
                                observedMs, expectedMs, overMs, stddev)
                }

                if meaningful {
                    // Count as a meaningful underrun
                    recentXrunTimes.append(nowHost)
                    recentOverruns.append((t: nowHost, overMs: overMs))

                    // Prune to the configured sliding window
                    let windowSec = self.config.glitchWindowSeconds
                    let cutoffTicks = nowHost &- self.secondsToTicks(windowSec)
                    if let firstIdxToKeep = recentXrunTimes.firstIndex(where: { $0 >= cutoffTicks }) {
                        if firstIdxToKeep > 0 { recentXrunTimes.removeFirst(firstIdxToKeep) }
                    } else {
                        recentXrunTimes.removeAll(keepingCapacity: true)
                    }
                    if let firstOvIdx = recentOverruns.firstIndex(where: { $0.t >= cutoffTicks }) {
                        if firstOvIdx > 0 { recentOverruns.removeFirst(firstOvIdx) }
                    } else {
                        recentOverruns.removeAll(keepingCapacity: true)
                    }

                    // Emit the XRUN with magnitude
                    os_signpost(.event, log: self.log, name: "XRUN",
                                "gap=%{public}.4fms expected=%{public}.4fms over=%{public}.3fms need=%{public}.3fms frames=%{public}u std=%{public}.3f",
                                observedMs, expectedMs, overMs, needed, buffer.frameLength, stddev)
                    os_log("XRUN gap=%.4f expected=%.4f over=%.3f need=%.3f frames=%u std=%.3f",
                           log: self.log, type: .info, observedMs, expectedMs, overMs, needed, buffer.frameLength, stddev)

                    // Determine glitching state transitions (rate-based)
                    if !glitching && recentXrunTimes.count >= self.config.glitchBurstCount {
                        glitching = true
                        lastGlitchChangeHostTime = nowHost
                        // Compute average overrun magnitude in window for context
                        let avgOver = recentOverruns.map { $0.overMs }.reduce(0, +) / Double(max(1, recentOverruns.count))
                        os_signpost(.event, log: self.log, name: "GlitchStart",
                                    "xruns=%{public}d window=%{public}.2fs avgOverMs=%{public}.2f std=%.3f",
                                    recentXrunTimes.count, self.config.glitchWindowSeconds, avgOver, stddev)
                        print("[RenderWatchdog] GlitchStart xruns=\(recentXrunTimes.count) avgOverMs=\(String(format: "%.2f", avgOver)) window=\(self.config.glitchWindowSeconds)s std=\(String(format: "%.3f", stddev))")
                        onGlitchStateChanged?(true)
                    }
                } else {
                    // No meaningful underrun on this cycle. If we are in glitching state, check for quiescence.
                    if glitching {
                        let quiescentSec = self.config.glitchQuiescentSeconds
                        let cutoffTicks = nowHost &- self.secondsToTicks(quiescentSec)
                        if let lastRecent = recentXrunTimes.last, lastRecent < cutoffTicks {
                            glitching = false
                            lastGlitchChangeHostTime = nowHost
                            os_signpost(.event, log: self.log, name: "GlitchEnd")
                            print("[RenderWatchdog] GlitchEnd")
                            onGlitchStateChanged?(false)
                        }
                    }
                }
            } else {
                // First tap: seed lastWhenHost using the render timestamp
                os_signpost(.event, log: self.log, name: "TapPrimed",
                            "frames=%{public}u expectedIO=%{public}.3fms",
                            buffer.frameLength, self.expectedMsFromSession ?? -1)
            }
        }
    }

    func detach() {
        guard let node = tappedNode, isAttached else { return }
        node.removeTap(onBus: 0)
        tappedNode = nil
        isAttached = false
        lastHostTime = nil
        os_signpost(.event, log: log, name: "WatchdogDetach")
        print("[RenderWatchdog] detach")
    }

    // MARK: - Helpers
    private func toMillis(_ ticks: UInt64) -> Double {
        Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000.0
    }

    private func toSeconds(_ ticks: UInt64) -> Double {
        Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000.0
    }

    private func secondsToTicks(_ seconds: Double) -> UInt64 {
        let nanos = seconds * 1_000_000_000.0
        let ticks = nanos * Double(timebase.denom) / Double(timebase.numer)
        return UInt64(max(0, ticks))
    }

    // MARK: - Introspection
    func isGlitching() -> Bool { glitching }
}
