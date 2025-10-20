//
//  VocalTractConductor 2.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/26/25.
//


import AudioKit
import AudioKitEX
import CAudioKitEX
import AudioToolbox
import SoundpipeAudioKit
import AnyCodable

class VocalTractConductor: ObservableObject, HasAudioEngine, VoiceConductorProtocol {
    
    

    static var id: String { "VocalTractConductor" }
    static var displayName: String = "Vocal Tract"
    static var version: Int = 1
    
    // Each voice bundle: (glottis, filter, lowpass, fader)
    private var voiceBundles: [(glottis: VocalGlottis, filter: VocalTractFilter, lowpass: LowPassButterworthFilter, fader: Fader)] = []
    
    var faceData: FaceData?
    let engine = AudioEngineManager.shared.engine
    

    static var defaultPatches: [PatchSettings] {
        return [
            PatchSettings(
                id: -1001,
                name: "Classic Tract",
                tonicKey: .C,
                tonicChord: .major,
                numOfVoices: 3,
                glissandoSpeed: 20.0,
                voicePitchLevel: VoicePitchLevel.medium,
                noteRangeSize: NoteRangeSize.medium,
                version: Self.version,
                conductorID: Self.id,
                imageName: "icon_vocaltract_classic",
                conductorSpecificSettings: [
                    "vibratoAmount": AnyCodable(20.0)
                ]
            ),
            PatchSettings(
                id: -1002,
                name: "Wide Vibrato",
                tonicKey: .C,
                tonicChord: .minor,
                numOfVoices: 4,
                glissandoSpeed: 30.0,
                voicePitchLevel: VoicePitchLevel.medium,
                noteRangeSize: NoteRangeSize.medium,
                version: Self.version,
                conductorID: Self.id,
                imageName: "icon_vocaltract_widevibrato",
                conductorSpecificSettings: [
                    "vibratoAmount": AnyCodable(90.0)
                ]
            )
        ]
    }
    
    var audioState: AudioState = .stopped
    
    var conductorSpecificSettings: [String: Any] = [:]
    
    var currentSettings: PatchSettings?

    var tonicChord: MusicBrain.ChordType
    
    var currentPitch: Int?
    
    var harmonyMaker: HarmonyMaker = HarmonyMaker()
    
    var voicePitchLevel: VoicePitchLevel
    
    var noteRangeSize: NoteRangeSize
    
    var scaleMask: UInt16?
    
    
    
    var lowestNote: Int {
        let centerNote = voicePitchLevel.centerMIDINote
        let halfRange = NoteRangeSize.medium.rangeSize / 2
        return centerNote - halfRange
    }

    var highestNote: Int {
        let centerNote = voicePitchLevel.centerMIDINote
        let halfRange = noteRangeSize.rangeSize / 2
        return centerNote + halfRange
    }
    
    var glissandoSpeed: Float

    // vibratoAmount is always scaled 0–100; scale to 0–1 semitone in getter/setter
    @Published var vibratoAmount: Float = 0.0 {
        didSet {
            // Clamp vibratoAmount to 0–100 if needed
            if vibratoAmount < 0.0 { vibratoAmount = 0.0 }
            if vibratoAmount > 100.0 { vibratoAmount = 100.0 }
            conductorSpecificSettings["vibratoAmount"] = vibratoAmount
        }
    }
    var vibratoRate: Float = 5.0
    private var vibratoPhase: Float = 0.0
    private var vibratoActivationTime: [TimeInterval] = []

    @Published var globalLowPassCutoffHz: Float = 10000.0 { // Hz, Butterworth LPF cutoff
        didSet {
            let clamped = max(lpfMinHz, min(lpfMaxHz, globalLowPassCutoffHz))
            if globalLowPassCutoffHz != clamped { globalLowPassCutoffHz = clamped; return }
            for bundle in voiceBundles {
                if bundle.lowpass.cutoffFrequency != clamped {
                    bundle.lowpass.cutoffFrequency = clamped
                }
            }
        }
    }

    // LPF settings are stored and persisted in Hz. Shared mapping constants and helpers (log scale 20 Hz .. 20 kHz)
    private let lpfMinHz: Float = 20.0
    private let lpfMaxHz: Float = 20000.0

    private func lpfNormalizedToHz(_ t: Float) -> Float {
        let tn = max(0.0, min(1.0, t))
        let hz = lpfMinHz * pow(lpfMaxHz / lpfMinHz, tn)
        return max(lpfMinHz, min(lpfMaxHz, hz))
    }

    private func lpfHzToNormalized(_ hz: Float) -> Float {
        let clamped = max(lpfMinHz, min(lpfMaxHz, hz))
        return log(clamped / lpfMinHz) / log(lpfMaxHz / lpfMinHz)
    }

    private var baseFrequencies: [Float] = []
    private var lastUpdateTime: TimeInterval = CACurrentMediaTime()

    // --- GLISSANDO/VIBRATO STATE ---
    // These arrays store state for each voice
    static var lastTargetFrequency: [Float] = []
    static var glissandoStartTime: [TimeInterval] = []
    static var glissandoEndTime: [TimeInterval] = []
    static var frequencyStartValue: [Float] = []
    static var targetFrequency: [Float] = []
    static var shouldApplyGlissando: [Bool] = []

    var outputNode: Node {
        return voiceBundles.first?.fader ?? Mixer()
    }
    
    @Published var numOfVoices: Int {
        didSet {
            
            Log.line(actor: "😮 VocalTractConductor", fn: "var numOfVoices.didSet", "numOfVoices changed to \(numOfVoices), triggering updateVoiceCount()")

            updateVoiceCount()
        }
    }
    
    
    private var hasFaceData = false  // Flag to track when data is ready

    private var latestHarmonies: [Int]? = nil
    
    required init() {
        // get default key from defaultSettings
        let defaultSettings = PatchManager.shared.defaultPatchSettings
        self.tonicChord = defaultSettings.tonicChord
        self.glissandoSpeed = defaultSettings.glissandoSpeed
        self.numOfVoices = defaultSettings.numOfVoices
        self.currentSettings = defaultSettings
        self.audioState = .waitingForFaceData
        self.voicePitchLevel = defaultSettings.voicePitchLevel
        self.noteRangeSize = defaultSettings.noteRangeSize
        self.scaleMask = nil
        
    }
    
    internal func updateVoiceCount() {
        let currentCount = voiceBundles.count
        let desiredCount = numOfVoices
        
        Log.line(actor: "😮 VocalTractConductor", fn: "updateVoiceCount", "Update voice count with numOfVoices: \(numOfVoices). currentCount: \(currentCount), desiredCount: \(desiredCount)")

        if currentCount == desiredCount {
            Log.line(actor: "😮 VocalTractConductor", fn: "updateVoiceCount", "Voice count unchanged.  currentCount: \(currentCount), desiredCount: \(desiredCount)")

        } else if currentCount < desiredCount {
            
            Log.line(actor: "😮 VocalTractConductor", fn: "updateVoiceCount", "Adding voices. currentCount: \(currentCount), desiredCount: \(desiredCount)")

            for _ in currentCount..<desiredCount {
                let glottis = VocalGlottis()
                let filter = VocalTractFilter(glottis)
                let lowpass = LowPassButterworthFilter(filter)
                lowpass.cutoffFrequency = globalLowPassCutoffHz
                let fader = Fader(lowpass, gain: 0.0)
                AudioEngineManager.shared.addToMixer(node: fader)
                voiceBundles.append((glottis: glottis, filter: filter, lowpass: lowpass, fader: fader))
                vibratoActivationTime.append(0.0)
                if audioState == .playing {
                    
                    Log.line(actor: "😮 VocalTractConductor", fn: "updateVoiceCount", "Starting new voice.")

                    startVoice(fader, glottis: glottis, filter: filter, lowpass: lowpass)
                }
            }
        } else {
            
            Log.line(actor: "😮 VocalTractConductor", fn: "updateVoiceCount", "Removing voices. currentCount: \(currentCount), desiredCount: \(desiredCount)")

            for _ in desiredCount..<currentCount {
                if let last = voiceBundles.popLast() {
                    
                    Log.line(actor: "😮 VocalTractConductor", fn: "updateVoiceCount", "Stopping voice.")

                    stopVoice(last.fader, glottis: last.glottis, filter: last.filter, lowpass: last.lowpass)
                    AudioEngineManager.shared.removeFromMixer(node: last.fader)
                    vibratoActivationTime.removeLast()
                }
            }
        }
        AudioEngineManager.shared.logMixerState("after updateVoiceCount")
    }

    private func startVoice(_ fader: Fader, glottis: VocalGlottis, filter: VocalTractFilter, lowpass: LowPassButterworthFilter) {
        fader.gain = 0.0
        Log.line(actor: "😮 VocalTractConductor", fn: "startVoice", "")

        glottis.start()
        filter.start()
        lowpass.cutoffFrequency = globalLowPassCutoffHz
        lowpass.start()
        let fadeEvent = AutomationEvent(targetValue: 1.0, startTime: 0.0, rampDuration: 0.1)
        fader.automateGain(events: [fadeEvent])
    }

    private func stopVoice(_ fader: Fader, glottis: VocalGlottis, filter: VocalTractFilter, lowpass: LowPassButterworthFilter) {
        Log.line(actor: "😮 VocalTractConductor", fn: "stopVoice", "")

        lowpass.stop()
        let fadeEvent = AutomationEvent(targetValue: 0.0, startTime: 0.0, rampDuration: 0.1)
        fader.automateGain(events: [fadeEvent])
        glottis.stop()
        filter.stop()
    }
    
    func stopAllVoices() {
        Log.line(actor: "😮 VocalTractConductor", fn: "stopAllVoices", "")

        for bundle in voiceBundles {
            stopVoice(bundle.fader, glottis: bundle.glottis, filter: bundle.filter, lowpass: bundle.lowpass)
        }
    }
    
    func updateIntervalChordTypes() {
        // Removed: No longer used with MusicBrain types
    }
    

    func disconnectFromMixer() {
        
        Log.line(actor: "😮 VocalTractConductor", fn: "disconnectFromMixer", "🔌 Disconnecting voices from mixer...")

        voiceBundles.forEach { bundle in
            AudioEngineManager.shared.removeFromMixer(node: bundle.fader)
            if audioState == .playing {
                bundle.lowpass.stop()
                bundle.glottis.stop()
                bundle.filter.stop()
            }
        }
        audioState = .stopped
    }

    func connectToMixer() {
        Log.line(actor: "😮 VocalTractConductor", fn: "connectToMixer", "🔗 Reconnecting voices to mixer. Only starts them if audio is playing.")

        
        for bundle in voiceBundles {
            AudioEngineManager.shared.removeFromMixer(node: bundle.fader)
            AudioEngineManager.shared.addToMixer(node: bundle.fader)
            if audioState == .playing {
                startVoice(bundle.fader, glottis: bundle.glottis, filter: bundle.filter, lowpass: bundle.lowpass)
            }
        }
    }

    
    func updateWithFaceData(_ faceData: FaceData) {
        // this gets called when we get new AR data from the face

        self.faceData = faceData

        var harmonies: [Int]

        // Use extracted interpolation method
        let interpolatedValues = interpolateFaceParameters(from: faceData)

        // Map raw face pitch directly to nearest quantized note using MusicBrain
        let quantizedNote = MusicBrain.shared.nearestQuantizedNote(
            rawPitch: faceData.pitch,
            lowestNote: self.lowestNote,
            highestNote: self.highestNote
        )

        currentPitch = quantizedNote
        guard let currentPitch = currentPitch else { return }

        let keyIndex = currentPitch % 12
        let displayNote = 60 + keyIndex // force note into C4–B4 range
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("HighlightPianoKey"), object: nil, userInfo: ["midiNote": displayNote])
        }

        // Use harmonyMaker with current pitch and numOfVoices
        harmonies = harmonyMaker.voiceChord(currentPitch: currentPitch, numOfVoices: numOfVoices)

        // Ensure lead note is first
        if let index = harmonies.firstIndex(of: currentPitch) {
            harmonies.remove(at: index)
        }
        harmonies.insert(currentPitch, at: 0)

        // Store harmonies for later use in returnMusicStats()
        latestHarmonies = harmonies

        let now = CACurrentMediaTime()
        let deltaTime = Float(now - lastUpdateTime)
        lastUpdateTime = now

        vibratoPhase += 2 * Float.pi * vibratoRate * deltaTime
        if vibratoPhase > 2 * Float.pi {
            vibratoPhase -= 2 * Float.pi
        }

        while harmonies.count < numOfVoices {
            harmonies.append(harmonies.last ?? currentPitch)
        }

        // Ensure arrays are sized properly
        let voicesCount = numOfVoices
        while Self.lastTargetFrequency.count < voicesCount { Self.lastTargetFrequency.append(0.0) }
        while Self.glissandoStartTime.count < voicesCount { Self.glissandoStartTime.append(0.0) }
        while Self.glissandoEndTime.count < voicesCount { Self.glissandoEndTime.append(0.0) }
        while Self.frequencyStartValue.count < voicesCount { Self.frequencyStartValue.append(0.0) }
        while Self.targetFrequency.count < voicesCount { Self.targetFrequency.append(0.0) }
        while Self.shouldApplyGlissando.count < voicesCount { Self.shouldApplyGlissando.append(false) }

        for (index, harmony) in harmonies.enumerated() {
            if index < voiceBundles.count {
                let glottis = voiceBundles[index].glottis
                let filter = voiceBundles[index].filter
                let lowpass = voiceBundles[index].lowpass
                // Keep lowpass cutoff in sync with published value
                if lowpass.cutoffFrequency != globalLowPassCutoffHz {
                    lowpass.cutoffFrequency = globalLowPassCutoffHz
                }
                let currentFrequency = midiNoteToFrequency(harmony)
                let previousTargetFrequency = Self.lastTargetFrequency[index]

                // If frequency changes significantly, start new glissando
                if abs(currentFrequency - previousTargetFrequency) > 0.1 {
                    Self.glissandoStartTime[index] = now
                    Self.glissandoEndTime[index] = now + (Double(glissandoSpeed) / 1000)
                    vibratoActivationTime[index] = Self.glissandoEndTime[index]
                    Self.targetFrequency[index] = currentFrequency
                    Self.frequencyStartValue[index] = glottis.frequency
                    Self.lastTargetFrequency[index] = currentFrequency
                    Self.shouldApplyGlissando[index] = true
                }

                // Apply glissando if active
                if Self.shouldApplyGlissando[index] {
                    let glissDuration = Self.glissandoEndTime[index] - Self.glissandoStartTime[index]
                    let glissProgress = (now - Self.glissandoStartTime[index]) / glissDuration
                    let clampedProgress = max(0.0, min(1.0, glissProgress))
                    glottis.frequency = Self.frequencyStartValue[index] + Float(clampedProgress) * (Self.targetFrequency[index] - Self.frequencyStartValue[index])
                    if clampedProgress >= 1.0 {
                        Self.shouldApplyGlissando[index] = false
                    }
                }
                // Vibrato is applied only after glissando is finished and after vibrato activation time
                if !Self.shouldApplyGlissando[index] && now > vibratoActivationTime[index] {
                    let harmonyAttenuation: Float = (index == 0) ? 1.0 : 0.4
                    let attenuatedVibrato = vibratoAmount * harmonyAttenuation
                    let vibratoOffset = sin(vibratoPhase) * (attenuatedVibrato / 100.0)
                    let vibratoFreq = currentFrequency * pow(2.0, vibratoOffset / 12.0)
                    glottis.frequency = vibratoFreq
                }

                // Apply glottis parameters
                glottis.tenseness = 0.6 // Could be parameterized

                // Apply filter parameters
                filter.jawOpen = faceData.jawOpen
                filter.tongueDiameter = faceData.tongueDiameter
                filter.tonguePosition = faceData.tonguePosition
                filter.lipShape = faceData.lipOpen
                filter.nasality = 0.0
            }
        }

        if audioState == .waitingForFaceData {
            
            Log.line(actor: "😮 VocalTractConductor", fn: "updateWithFaceData", "setting audioState to .playing")

            audioState = .playing
            for (index, voiceBundle) in self.voiceBundles.enumerated() {
                let delay = Double(index) * 0.1
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.startVoice(voiceBundle.fader, glottis: voiceBundle.glottis, filter: voiceBundle.filter, lowpass: voiceBundle.lowpass)
                }
            }
        }
    }

    private func interpolateFaceParameters(from faceData: FaceData) -> [AudioGenerationParameter: Float] {
        var interpolatedValues: [AudioGenerationParameter: Float] = [:]
        for parameter in AudioGenerationParameter.allCases {
            let bounds = parameter.metadata
            let rawValue = faceData[keyPath: parameter.keyPath]
            let interpolatedValue = rawValue.interpolated(
                fromLowerBound: bounds.fromLower,
                fromUpperBound: bounds.fromUpper,
                toLowerBound: bounds.toLower,
                toUpperBound: bounds.toUpper
            )
            interpolatedValues[parameter] = interpolatedValue
        }
        return interpolatedValues
    }
    
    func applySettings(_ settings: PatchSettings) {
        Log.line(actor: "😮 VocalTractConductor", fn: "applySettings", "applySettings called")

        
        self.currentSettings = settings
        applyConductorSpecificSettings(from: settings)
        
        self.tonicChord = settings.tonicChord
        self.glissandoSpeed = settings.glissandoSpeed
        self.voicePitchLevel = settings.voicePitchLevel
        self.noteRangeSize = settings.noteRangeSize
        if let mask = settings.scaleMask {
            self.scaleMask = mask
            MusicBrain.shared.updateKeyAndScale(key: settings.tonicKey, chordType: settings.tonicChord, scaleMask: mask)
        } else {
            MusicBrain.shared.updateKeyAndScale(key: settings.tonicKey, chordType: settings.tonicChord)
        }
        
        // numOfVoices last because this starts the voices
        self.numOfVoices = settings.numOfVoices
    }
    
    func applyConductorSpecificSettings(from patch: PatchSettings) {
        //logPatches(patch, label: "😮 VocalTractConductor.applyConductorSpecificSettings called with patch.conductorSpecificSettings \(String(describing: patch.conductorSpecificSettings))")


        if let anyValue = patch.conductorSpecificSettings?["vibratoAmount"]?.value {
            if let vibrato = FloatValue(from: anyValue) {
                self.vibratoAmount = vibrato
                self.conductorSpecificSettings["vibratoAmount"] = vibrato
            }
        }

        if let anyLP = patch.conductorSpecificSettings?["lowPassCutoff"]?.value,
           let lowPassCutoffHz = FloatValue(from: anyLP) {
            let clamped = max(lpfMinHz, min(lpfMaxHz, lowPassCutoffHz))
            self.globalLowPassCutoffHz = clamped
            self.conductorSpecificSettings["lowPassCutoff"] = clamped
        }
    }

    
    func exportConductorSpecificSettings() -> [String: Any]? {
        return [
            "vibratoAmount": self.vibratoAmount,
            "lowPassCutoff": self.globalLowPassCutoffHz
        ]
    }
    
    
    func exportCurrentSettings() -> PatchSettings {
        
        Log.line(actor: "😮 VocalTractConductor", fn: "exportCurrentSettings", "")

        let lowestNote = self.lowestNote
        let highestNote = self.highestNote
        return PatchSettings(
            id: currentSettings?.id ?? -1,
            name: currentSettings?.name ?? "Untitled Patch",
            tonicKey: MusicBrain.shared.tonicKey,
            tonicChord: self.tonicChord,
            numOfVoices: self.numOfVoices,
            glissandoSpeed: self.glissandoSpeed,
            voicePitchLevel: self.voicePitchLevel,
            noteRangeSize: self.noteRangeSize,
            scaleMask: self.scaleMask,
            version: Self.version,
            conductorID: type(of: self).id,
            conductorSpecificSettings: exportConductorSpecificSettings()?.mapValues { AnyCodable($0) }
        )
    }
    
    // MARK: - VoiceConductorProtocol

    
    func makeSettingsUI(target: Any?, valueChangedAction: Selector, touchUpAction: Selector) -> [UIView] {
        var views: [UIView] = []

        let currentCutoff = max(lpfMinHz, min(lpfMaxHz, self.globalLowPassCutoffHz))
        let lowPass = createLabeledSlider(
            title: "Low Pass",
            minLabel: "20 Hz",
            maxLabel: "20 kHz",
            minValue: 0.0,
            maxValue: 1.0,
            initialValue: currentCutoff,
            target: target,
            valueChangedAction: valueChangedAction,
            touchUpAction: touchUpAction,
            showShadedBox: true,
            liveUpdate: { [weak self] (hz: Float) in
                self?.globalLowPassCutoffHz = hz
            },
            persist: { [weak self] (hz: Float) in
                guard let self = self else { return }
                self.globalLowPassCutoffHz = hz
                self.conductorSpecificSettings["lowPassCutoff"] = self.globalLowPassCutoffHz
            },
            toDisplay: { [weak self] (t: Float) in
                guard let self = self else { return 0.0 }
                return self.lpfNormalizedToHz(t)
            },
            toSlider: { [weak self] (freq: Float) in
                guard let self = self else { return 0.0 }
                return self.lpfHzToNormalized(freq)
            },
            formatValueLabel: { (freq: Float) in
                if freq >= 1000 {
                    return String(format: "%.1f kHz", freq / 1000.0)
                } else {
                    return String(format: "%.0f Hz", freq)
                }
            }
        )
        lowPass.slider.accessibilityIdentifier = "lowPassCutoff"
        lowPass.valueLabel.accessibilityIdentifier = "lowPassCutoffValueLabel"
        views.append(lowPass.container)

        let sliderData = createLabeledSlider(
            title: "Vibrato Amount",
            minLabel: "None",
            maxLabel: "Wide",
            minValue: 0.0,
            maxValue: 100.0,
            initialValue: self.vibratoAmount,
            target: target,
            valueChangedAction: valueChangedAction,
            touchUpAction: touchUpAction,
            showShadedBox: true,
            liveUpdate: { [weak self] (v: Float) in
                self?.vibratoAmount = v
            },
            persist: { [weak self] (v: Float) in
                guard let self = self else { return }
                self.vibratoAmount = v
                self.conductorSpecificSettings["vibratoAmount"] = v
            }
        )

        sliderData.slider.accessibilityIdentifier = "vibratoAmount"
        sliderData.valueLabel.accessibilityIdentifier = "vibratoAmountValueLabel"

        sliderData.slider.addAction(UIAction { _ in
            sliderData.valueLabel.text = "\(Int(sliderData.slider.value)) ms"
        }, for: .valueChanged)

        views.append(sliderData.container)
        return views
    }




    

  
    func returnAudioStats() -> String {
        var result = "audioState: \(audioState)"
        for (index, bundle) in voiceBundles.enumerated() {
            result += "\nVoice \(index + 1): Frequency: \(bundle.glottis.frequency)"
        }
        return result
    }
    
    func returnMusicStats() -> String {
        guard let harmonies = latestHarmonies, !harmonies.isEmpty else {
            return "Pitch data is unavailable."
        }
        
        guard let unwrappedPitch = currentPitch else {
            return "Pitch data is unavailable."
        }

        let noteInOctave = unwrappedPitch % 12
        let octave = unwrappedPitch / 12 - 1 // Middle C = C4

        let noteName = MusicBrain.NoteName.allCases[noteInOctave].displayName

        var result = "\(noteName)\(octave) (MIDI \(unwrappedPitch))"

        let harmonyNotesOnly = harmonies.dropFirst()
        if numOfVoices > 1 && !harmonyNotesOnly.isEmpty {
            for harmonyNote in harmonyNotesOnly {
                let harmonyNoteInOctave = harmonyNote % 12
                let harmonyOctave = harmonyNote / 12 - 1
                let harmonyNoteName = MusicBrain.NoteName.allCases[harmonyNoteInOctave].displayName
                result += "\n\(harmonyNoteName)\(harmonyOctave) (MIDI \(harmonyNote))"
            }
        }

        return result
    }

}

extension VocalTractConductor: ConductorValueMappingProviding {
    var valueConverters: [String: (Float) -> Float] {
        return [
            "lowPassCutoff": { [weak self] normalized in
                guard let self = self else { return normalized }
                return self.lpfNormalizedToHz(normalized)
            }
        ]
    }
}

