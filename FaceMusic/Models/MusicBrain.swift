//
//  MusicBrain.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//
import Foundation

// MARK: - MusicBrain
class MusicBrain {
    // MARK: Singleton
    static let shared = MusicBrain()

    // MARK: Public Providers
    // A provider that returns the latest detected raw facial pitch (in the same units as ARDataPitchRange expects).
    // Your AR session/update loop should set this to supply the most recent value.
    // Example usage elsewhere:
    // MusicBrain.currentRawPitchProvider = { latestARHeadPitch }
    static var currentRawPitchProvider: (() -> Float?) = { nil }

    /// A provider that returns the user-chosen voice center MIDI note, if available.
    /// By default, this returns the tonic MIDI note that is closest to the middle of the current usable range
    /// as defined by `voicePitchLevel` and `noteRangeSize`.
    static var currentVoiceCenterMIDINoteProvider: (() -> Int?) = { [weak instance = MusicBrain.shared] in
        guard let brain = instance else { return nil }
        return brain.tonicClosestToRangeMiddle()
    }

    // MARK: Tonic / Harmony State
    private(set) var tonicKey: NoteName
    private(set) var tonicScale: ScaleType
    private(set) var tonicChordType: ChordType = .major

    // User-selected chord (if different from the tonic). When nil, fall back to tonic.
    private var userSelectedChord: ChordWithRoot?

    /// Effective current chord used by the app. Falls back to tonic when no selection is made.
    var currentSelectedChord: ChordWithRoot { userSelectedChord ?? ChordWithRoot(root: tonicKey, type: tonicChordType) }

    // MARK: Scale Mask / Quantization Data
    private(set) var customScaleMask: UInt16? // nil = no override
    private var nearestNoteTable: [Int] // Precomputed nearest note lookup table for MIDI notes 0-127.

    // MARK: Voice Mapping Configuration
    private var arPitchRange = ARDataPitchRange()
    private(set) var voicePitchLevel: VoicePitchLevel = .medium
    private(set) var noteRangeSize: NoteRangeSize = .medium

    // When set, bias mapping so that the normalized center (0.5) maps to this MIDI note.
    private var centerTargetMIDINote: Int?

    // MARK: - Init
    // Initialize with default key and scale, and compute lookup table
    init(key: NoteName = .C, scale: ScaleType = .major) {
        self.tonicKey = key
        self.tonicScale = scale
        self.nearestNoteTable = []
        // Attempt to pull initial voice pitch and range from patch settings if present
        applyInitialPatchSettingsIfAvailable()
    }

    // MARK: - Public API: Chord Selection
    /// Selects a chord explicitly chosen by the user.
    func selectChord(root: NoteName, type: ChordType) { userSelectedChord = ChordWithRoot(root: root, type: type) }

    /// Selects a chord explicitly chosen by the user.
    func selectChord(_ chord: ChordWithRoot) { userSelectedChord = chord }

    /// Clears any user-selected chord and falls back to the tonic chord.
    func clearSelectedChord() { userSelectedChord = nil }

    // MARK: - Public API: Voice Settings
    /// Update the voice pitch level and/or note range size, and rebuild quantization accordingly.
    func setVoicePitch(level: VoicePitchLevel? = nil, rangeSize: NoteRangeSize? = nil) {
        if let level { self.voicePitchLevel = level }
        if let rangeSize { self.noteRangeSize = rangeSize }
        updateVoicePitchOrRangeOnly(voicePitchLevel: self.voicePitchLevel, noteRangeSize: self.noteRangeSize)
    }

    /// Public: Set an explicit center target MIDI note. Value will be clamped to 0...127.
    func setCenterTargetMIDINote(_ midiNote: Int?) {
        if let note = midiNote {
            
            Log.line(actor: "🧠 MusicBrain", fn: "setCenterTargetMIDINote", "trying to set to: \(note)")

            centerTargetMIDINote = max(0, min(127, note)) } else { centerTargetMIDINote = nil }
    }

    /// Public: Recompute the center target MIDI note based on the current tonic and voice settings.
    /// This aligns the normalized 0.5 position to the tonic closest to the middle of the current usable range.
    func updateCenterTargetMIDINoteToTonic() {
        
        Log.line(actor: "🧠 MusicBrain", fn: "updateCenterTargetMIDINoteToTonic", "calling closestTonicCenterMIDINoteForCurrentSettings with tonicKey: \(tonicKey)")
        
        centerTargetMIDINote = closestTonicCenterMIDINoteForCurrentSettings(tonic: tonicKey)
    }

    // MARK: - Public API: Key / Scale
    var tonicScalePitchClasses: [Int] {
        if let mask = customScaleMask { return Self.pitchClasses(fromMask: mask) }
        else { return tonicScale.intervals.map { ($0 + tonicKey.rawValue) % 12 } }
    }

    func updateKeyAndScale(key: NoteName, chordType: ChordType, scaleMask: UInt16? = nil, voicePitchLevel: VoicePitchLevel, noteRangeSize: NoteRangeSize) {
        self.tonicKey = key
        self.tonicChordType = chordType
        self.customScaleMask = scaleMask
        self.voicePitchLevel = voicePitchLevel
        self.noteRangeSize = noteRangeSize

        if let mask = scaleMask {
            let scaleNotes = Self.pitchClasses(fromMask: mask)
            Log.line(actor: "🧠 MusicBrain", fn: "updateKeyAndScale", "Using custom scale mask: \(scaleNotes).  Calling rebuildQuantization(\(scaleNotes))")
            rebuildQuantization(withScaleClasses: scaleNotes)
        } else {
            let scale = ScaleType.scaleForChordType(chordType)
            self.tonicScale = scale
            Log.line(actor: "🧠 MusicBrain", fn: "updateKeyAndScale", "Using default scale \(scale).  Calling rebuildQuantization(\(scale.intervals.map { ($0 + key.rawValue) % 12 })")
            rebuildQuantization(withScaleClasses: scale.intervals.map { ($0 + key.rawValue) % 12 })
        }

    }
    
    /// Call this when only the voice pitch or range changes,
    /// and you want to rebuild quantization without resetting key/scale/mask.
    func updateVoicePitchOrRangeOnly(voicePitchLevel: VoicePitchLevel, noteRangeSize: NoteRangeSize) {
        self.voicePitchLevel = voicePitchLevel
        self.noteRangeSize = noteRangeSize
        rebuildQuantization(withScaleClasses: tonicScalePitchClasses)
    }

    // MARK: - Public API: Pitch Range Mapping
    /// Set the pitch mapping range by specifying a new center and span (half-range).
    /// - Parameters:
    ///   - center: The neutral resting raw pitch value.
    ///   - span: Half of the full range around the center. Full range = 2*span.
    func setPitchRange(center: Float, span: Float) { arPitchRange.set(center: center, span: span) }

    /// Recenter the pitch mapping while preserving the current span.
    func recenterPitchRange(to center: Float) { arPitchRange.recenter(to: center) }

    /// Convenience: recenter the pitch mapping using the current facial pitch, if available.
    func recenterPitchRangeFromCurrentFacePitch() {
        arPitchRange.recenterFromCurrentFacePitch()
        updateCenterTargetMIDINoteToTonic()
        Log.line(actor: "🧠 MusicBrain", fn: "recenterPitchRangeFromCurrentFacePitch",
                 "Set center target MIDI to tonic near range middle: \(centerTargetMIDINote) by using tonic: \(tonicKey) and rangeSize: \(noteRangeSize.rangeSize)")
    }

    /// Calibrate the neutral center from a sampled raw pitch value (e.g., current head pose).
    func calibrateCenterFrom(rawPitch: Float) { arPitchRange.calibrateCenter(from: rawPitch) }

    // MARK: - Mapping / Quantization
    // Return the nearest quantized note for a given raw pitch float
    func nearestQuantizedNote(rawPitch: Float, lowestNote: Int, highestNote: Int) -> Int {
        let clampedRaw = Swift.min(Swift.max(rawPitch, arPitchRange.minValue), arPitchRange.maxValue)
        let normalized = (clampedRaw - arPitchRange.minValue) / (arPitchRange.maxValue - arPitchRange.minValue)
        Log.line(actor: "🧠 MusicBrain", fn: "nearestQuantizedNote", "clampedRaw: \(clampedRaw) normalized: \(normalized) lowestNote: \(lowestNote) highestNote: \(highestNote)  centerTargetMIDINote: \(centerTargetMIDINote)")

        let validNotes = nearestNoteTable.filter { $0 >= lowestNote && $0 <= highestNote }
        guard !validNotes.isEmpty else { return lowestNote }
        let baseIndex = Int(round(normalized * Float(validNotes.count - 1)))

        if let targetMIDINote = centerTargetMIDINote, !validNotes.isEmpty {
            let centerIndex = Int(round(0.5 * Float(validNotes.count - 1)))
            var nearestIdx = 0
            var nearestDiff = Int.max
            for (i, note) in validNotes.enumerated() {
                let diff = abs(note - targetMIDINote)
                if diff < nearestDiff { nearestDiff = diff; nearestIdx = i }
            }
            let shift = nearestIdx - centerIndex
            let adjustedIndex = min(max(baseIndex + shift, 0), validNotes.count - 1)
            let result = validNotes[adjustedIndex]
            Log.line(actor: "🧠 MusicBrain", fn: "nearestQuantizedNote", "Returning shifted quantized note: \(result) (targetMIDINote: \(targetMIDINote), baseIndex: \(baseIndex), adjustedIndex: \(adjustedIndex))")
            return result
        } else {
            let result = validNotes[baseIndex]
            Log.line(actor: "🧠 MusicBrain", fn: "nearestQuantizedNote", "Returning result: \(result))")
            return result
        }
    }

    func rebuildQuantization(withScaleClasses scaleClasses: [Int]) {
        Log.line(actor: "🧠 MusicBrain", fn: "rebuildQuantization", "recieved scaleClasses: \(scaleClasses)")
        var result: [Int] = []
        for midiNote in 0...127 where scaleClasses.contains(midiNote % 12) { result.append(midiNote) }
        self.nearestNoteTable = result
    }



    // MARK: - Harmony Helpers
    func chordIntervals(for chordType: ChordType) -> [Int] {
        switch chordType {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .dominant7: return [0, 4, 7, 10]
        case .diminished: return [0, 3, 6]
        case .halfDiminished: return [0, 3, 6, 10]
        case .augmented: return [0, 4, 8]
        }
    }

    // MARK: - Tonic Placement Helpers
    /// Computes the middle MIDI note of the current usable range, centered around the level's center.
    /// The usable span is `noteRangeSize.rangeSize` semitones, centered at `voicePitchLevel.centerMIDINote`.
    /// Returns the midpoint as an integer MIDI note.
    private func currentRangeMiddleMIDINote() -> Int {
        let center = voicePitchLevel.centerMIDINote
        let span = noteRangeSize.rangeSize
        let half = span / 2
        let low = max(0, center - half)
        let high = min(127, center + half)
        return (low + high) / 2
    }

    /// Computes the tonic MIDI note (based on `tonicKey`) closest to the current range middle.
    /// Picks the octave so that the tonic pitch is nearest to the midpoint.
    private func tonicClosestToRangeMiddle() -> Int {
        return closestTonicCenterMIDINoteForCurrentSettings(tonic: tonicKey)
    }

    /// Computes the tonic-centered MIDI note closest to the current voice neutral center,
    /// optionally clamped to the provided range size.
    func closestTonicCenterMIDINoteForCurrentSettings(tonic: NoteName) -> Int {
        
        let voicePitchLevel = self.voicePitchLevel
        let noteRangeSize = self.noteRangeSize
        
        let neutral = voicePitchLevel.centerMIDINote
        
        let tonicPC = tonic.rawValue
        let baseOctave = max(0, min(10, (neutral - tonicPC + 6) / 12))
        var best = 12 * baseOctave + tonicPC
        var bestDiff = abs(best - neutral)

        Log.line(actor: "🧠 MusicBrain", fn: "closestTonicCenterMIDINoteForCurrentSettings", "neutral: \(neutral) noteRangeSize: \(noteRangeSize) tonicPC: \(tonicPC) baseOctave: \(baseOctave) best: \(best) bestDiff: \(bestDiff)")

        for o in [baseOctave - 1, baseOctave + 1] where o >= 0 && o <= 10 {
            let candidate = 12 * o + tonicPC
            let diff = abs(candidate - neutral)
            if diff < bestDiff { best = candidate; bestDiff = diff }
        }

        let span = noteRangeSize.rangeSize
        let half = span / 2
        let low = max(0, neutral - half)
        let high = min(127, neutral + half)
        let result = max(low, min(high, best))
        Log.line(actor: "🧠 MusicBrain", fn: "closestTonicCenterMIDINoteForCurrentSettings", "using span: \(span) — result: \(result)")
        return result
    }

    // MARK: - Static Utilities
    static func pitchClasses(fromMask mask: UInt16) -> [Int] {
        var result: [Int] = []
        for i in 0..<12 { if (mask & (1 << i)) != 0 { result.append(i) } }
        return result
    }

    static func mask(fromPitchClasses classes: Set<Int>) -> UInt16 {
        return classes.reduce(0) { $0 | (1 << $1) }
    }

    func scaleMaskFromCurrentPitchClasses() -> UInt16 {
        return UInt16(tonicScalePitchClasses.reduce(0) { $0 | (1 << ($1 % 12)) })
    }

    /// Toggle the presence of a pitch class in the custom scale mask.
    func togglePitchClass(_ pitchClass: Int) {
        var current = Set(tonicScalePitchClasses)
        if current.contains(pitchClass) { current.remove(pitchClass) } else { current.insert(pitchClass) }
        let mask = MusicBrain.mask(fromPitchClasses: current)
        self.customScaleMask = mask
        rebuildQuantization(withScaleClasses: Array(current))
    }

    /// Clear any custom scale mask and revert to the current key and scale.
    func clearCustomScale() {
        self.customScaleMask = nil
        updateKeyAndScale(key: tonicKey, chordType: tonicChordType, voicePitchLevel: voicePitchLevel, noteRangeSize: noteRangeSize)
    }

    /// Generates an array of NoteNames centered on the given key and ordered by the circle of fifths.
    /// The count parameter determines the number of notes (must be > 0).
    static func circleOfFifthsWindow(center: NoteName, count: Int) -> [NoteName] {
        guard count > 0 else { return [] }
        let half = count / 2
        let start = -half
        let end = start + count
        return (start..<end).map { step in
            let raw = center.rawValue + (7 * step)
            let noteValue = ((raw % 12) + 12) % 12
            guard let note = NoteName(rawValue: noteValue) else { return .C }
            return note
        }
    }

    // MARK: - Private
    private func applyInitialPatchSettingsIfAvailable() {
        if let currentID = PatchManager.shared.currentPatchID,
           let current = PatchManager.shared.getPatchData(forID: currentID) {
            setVoicePitch(level: current.voicePitchLevel, rangeSize: current.noteRangeSize)
            updateCenterTargetMIDINoteToTonic()
            return
        }
        let defaults = PatchManager.shared.defaultPatchSettings
        setVoicePitch(level: defaults.voicePitchLevel, rangeSize: defaults.noteRangeSize)
        updateCenterTargetMIDINoteToTonic()
    }
}

// MARK: - Nested Types
extension MusicBrain {
    struct ChordWithRoot: Equatable, Codable { let root: NoteName; let type: ChordType }
}

// MARK: - ChordType
extension MusicBrain {
    enum ChordType: String, CaseIterable, Codable {
        case major, minor, dominant7, diminished, halfDiminished, augmented

        static let songChordTypes: [ChordType] = [.major, .minor]
        var isSongChordType: Bool { Self.songChordTypes.contains(self) }

        var displayName: String {
            switch self {
            case .major: return "Major"
            case .minor: return "Minor"
            case .dominant7: return "Dominant 7"
            case .diminished: return "Diminished"
            case .halfDiminished: return "Half-Diminished"
            case .augmented: return "Augmented"
            }
        }
        var shortDisplayName: String {
            switch self {
            case .major: return ""
            case .minor: return "m"
            case .dominant7: return "7"
            case .diminished: return "°"
            case .halfDiminished: return "ø"
            case .augmented: return "+"
            }
        }
    }
}

// MARK: - NoteName
extension MusicBrain {
    enum NoteName: Int, CaseIterable, Codable {
        case C = 0, DFlat = 1, D = 2, EFlat = 3, E = 4, F = 5, FSharp = 6, G = 7, AFlat = 8, A = 9, BFlat = 10, B = 11

        var displayName: String {
            switch self {
            case .C: return "C"
            case .DFlat: return "D♭"
            case .D: return "D"
            case .EFlat: return "E♭"
            case .E: return "E"
            case .F: return "F"
            case .FSharp: return "F♯"
            case .G: return "G"
            case .AFlat: return "A♭"
            case .A: return "A"
            case .BFlat: return "B♭"
            case .B: return "B"
            }
        }

        static func noteAndOctave(for midiNote: Int) -> (NoteName, Int) {
            let note = NoteName(rawValue: midiNote % 12) ?? .C
            let octave = midiNote / 12 - 1
            return (note, octave)
        }

        static func nameWithOctave(forMIDINote midiNote: Int) -> String {
            let (note, octave) = noteAndOctave(for: midiNote)
            return "\(note.displayName)\(octave)"
        }
    }
}

// MARK: - ScaleType
extension MusicBrain {
    enum ScaleType: String, CaseIterable {
        case major, minor, pentatonic, chromatic, mixolydian, diminished, wholeTone, locrian

        var intervals: [Int] {
            switch self {
            case .major: return [0, 2, 4, 5, 7, 9, 11]
            case .minor: return [0, 2, 3, 5, 7, 8, 10]
            case .pentatonic: return [0, 2, 4, 7, 9]
            case .chromatic: return Array(0...11)
            case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
            case .diminished: return [0, 2, 3, 5, 6, 8, 9, 11]
            case .wholeTone: return [0, 2, 4, 6, 8, 10]
            case .locrian: return [0, 2, 3, 5, 6, 8, 10]
            }
        }

        static func scaleForChordType(_ chordType: ChordType) -> ScaleType {
            switch chordType {
            case .major: return .major
            case .minor: return .minor
            case .dominant7: return .mixolydian
            case .diminished: return .diminished
            case .halfDiminished: return .locrian
            case .augmented: return .wholeTone
            }
        }
    }
}

// MARK: - VoicePitchLevel
extension MusicBrain {
    enum VoicePitchLevel: String, Codable, CaseIterable {
        case veryHigh, high, medium, low, veryLow

        var centerMIDINote: Int {
            switch self {
            case .veryHigh: return 84
            case .high: return 72
            case .medium: return 60
            case .low: return 48
            case .veryLow: return 36
            }
        }

        var label: String {
            switch self {
            case .veryHigh: return "Very High"
            case .high: return "High"
            case .medium: return "Medium"
            case .low: return "Low"
            case .veryLow: return "Very Low"
            }
        }
    }
}

// MARK: - NoteRangeSize
extension MusicBrain {
    enum NoteRangeSize: String, Codable, CaseIterable {
        case small, medium, large, xLarge

        var rangeSize: Int {
            switch self {
            case .small: return 24
            case .medium: return 48
            case .large: return 64
            case .xLarge: return 128
            }
        }

        var label: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            case .xLarge: return "X-Large"
            }
        }
    }
}

// MARK: - ARDataPitchRange
extension MusicBrain {
    struct ARDataPitchRange {
        var center: Float = -0.275
        var span: Float = 1.075

        var minValue: Float { center - span }
        var maxValue: Float { center + span }

        #if DEBUG
        func debugDescription() -> String {
            "ARDataPitchRange(center: \(center), span: \(span), min: \(minValue), max: \(maxValue))"
        }
        #endif

        mutating func set(center: Float, span: Float) {
            self.center = center
            self.span = Swift.max(0.001, span)
        }

        mutating func recenter(to newCenter: Float) { self.center = newCenter }
        mutating func calibrateCenter(from rawPitch: Float) { self.center = rawPitch }

        mutating func recenterFromCurrentFacePitch() {
            Log.line(actor: "🧠 MusicBrain", fn: "recenterFromCurrentFacePitch", "ARDataPitchRange.recenterFromCurrentFacePitch called")
            let provider = MusicBrain.currentRawPitchProvider
            if let pitch = provider() { self.center = pitch }
        }
    }
}

