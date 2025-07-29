//
//  OscillatorConductor 2.swift
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

class VoiceHarmonizerConductor: ObservableObject, HasAudioEngine, VoiceConductorProtocol {
    

    static var id: String { "VoiceHarmonizerConductor" }
    static var displayName: String = "Voice Harmonizer"
    
    private var voiceBundles: [(voice: MorphingOscillator, fader: Fader)] = []
    
    var faceData: FaceData?
    let engine = AudioEngineManager.shared.engine
    

    static var defaultPatches: [PatchSettings] {
        return [
            PatchSettings(
                id: 3001,
                name: "Harmonizer 1",
                key: .C,
                chordType: .major,
                numOfVoices: 3,
                glissandoSpeed: 20.0,
                voicePitchLevel: VoicePitchLevel.medium,
                noteRangeSize: NoteRangeSize.medium,
                version: 1,
                conductorID: Self.id,
                imageName: "harmonizer_default_1",
                conductorSpecificSettings: [
                    "vibratoAmount": AnyCodable(50.0)
                ]
                
                
            ),
            PatchSettings(
                id: 3002,
                name: "Harmonizer 2",
                key: .D,
                chordType: .minor,
                numOfVoices: 4,
                glissandoSpeed: 25.0,
                voicePitchLevel: VoicePitchLevel.medium,
                noteRangeSize: NoteRangeSize.medium,
                version: 1,
                conductorID: Self.id,
                imageName: "harmonizer_default_2",
                conductorSpecificSettings: [
                    "vibratoAmount": AnyCodable(90.0)
                ]
                
                
            )
        ]
    }
    
    var audioState: AudioState = .stopped
    
    var conductorSpecificSettings: [String: Any] = [:]
    
    var currentSettings: PatchSettings?

    var chordType: MusicBrain.ChordType
    
    var currentPitch: Int?
    
    var harmonyMaker: HarmonyMaker = HarmonyMaker()
    
    var voicePitchLevel: VoicePitchLevel
    
    var noteRangeSize: NoteRangeSize
    
    
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
            print("OscillatorConductor: numOfVoices changed to \(numOfVoices), triggering updateVoiceCount()")
            updateVoiceCount()
        }
    }
    
    
    private var hasFaceData = false  // Flag to track when data is ready

    private var latestHarmonies: [Int]? = nil
    
    required init() {
        // get default key from defaultSettings
        let defaultSettings = PatchManager.shared.defaultPatchSettings
        self.chordType = defaultSettings.chordType
        
        self.glissandoSpeed = defaultSettings.glissandoSpeed
        self.numOfVoices = defaultSettings.numOfVoices
        self.currentSettings = defaultSettings
        self.audioState = .waitingForFaceData
        self.voicePitchLevel = defaultSettings.voicePitchLevel
        self.noteRangeSize = defaultSettings.noteRangeSize

    }
    
    internal func updateVoiceCount() {
        
        let currentCount = voiceBundles.count
        let desiredCount = numOfVoices
        
        print("OscillatorConductor.updateVoiceCount(): Update voice count with numOfVoices: \(numOfVoices). currentCount: \(currentCount), desiredCount: \(desiredCount)")
        
        if currentCount == desiredCount {
            print("OscillatorConductor.updateVoiceCount(): Voice count unchanged.  currentCount: \(currentCount), desiredCount: \(desiredCount)")

        } else if currentCount < desiredCount {
            print("OscillatorConductor.updateVoiceCount(): Adding voices. currentCount: \(currentCount), desiredCount: \(desiredCount)")
            for _ in currentCount..<desiredCount {
                let voc = MorphingOscillator(waveformArray: [Table(.triangle), Table(.square), Table(.sine), Table(.sawtooth)])

                
                let fader = Fader(voc, gain: 0.0)
                //AudioEngineManager.shared.removeFromMixer(node: fader) // Ensure node isn't already in mixer
                AudioEngineManager.shared.addToMixer(node: fader)
                voiceBundles.append((voice: voc, fader: fader))
                vibratoActivationTime.append(0.0)
                if audioState == .playing {
                    print("OscillatorConductor.updateVoiceCount(): Starting new voice.")
                    startVoice(fader, voice: voc)
                }
            }
        } else {
            print("OscillatorConductor.updateVoiceCount(): Removing voices. currentCount: \(currentCount), desiredCount: \(desiredCount)")
            for _ in desiredCount..<currentCount {
                if let last = voiceBundles.popLast() {
                    print("OscillatorConductor.updateVoiceCount(): Stopping voice.")
                    stopVoice(last.fader, voice: last.voice)
                    AudioEngineManager.shared.removeFromMixer(node: last.fader)
                    vibratoActivationTime.removeLast()
                }
            }
        }
        
        // log mixer state
        AudioEngineManager.shared.logMixerState("after updateVoiceCount")
    }

    private func startVoice(_ fader: Fader, voice: MorphingOscillator) {
        fader.gain = 0.0
        print("OscillatorConductor.startVoice()")
        voice.start()
        let fadeEvent = AutomationEvent(targetValue: 1.0, startTime: 0.0, rampDuration: 0.1)
        fader.automateGain(events: [fadeEvent])
    }

    private func stopVoice(_ fader: Fader, voice: MorphingOscillator) {
        print("OscillatorConductor.stopVoice()")
        let fadeEvent = AutomationEvent(targetValue: 0.0, startTime: 0.0, rampDuration: 0.1)
        fader.automateGain(events: [fadeEvent])
        voice.stop()
        
    }
    
    func stopAllVoices() {
        print("OscillatorConductor.stopAllVoices()")
        for bundle in voiceBundles {
            stopVoice(bundle.fader, voice: bundle.voice)
        }
    }
    
    func updateIntervalChordTypes() {
        // Removed: No longer used with MusicBrain types
    }
    

    func disconnectFromMixer() {
        print("OscillatorConductor: 🔌 Disconnecting voices from mixer...")
        voiceBundles.forEach { bundle in
            AudioEngineManager.shared.removeFromMixer(node: bundle.fader)
            // Extra safeguard to prevent duplicate stops
            if audioState == .playing {
                bundle.voice.stop()
            }
        }
        audioState = .stopped
    }

    func connectToMixer() {
        print("OscillatorConductor: 🔗 Reconnecting voices to mixer. Only starts them if audio is playing.")
        for bundle in voiceBundles {
            // Always try removing first (safe even if not connected)
            AudioEngineManager.shared.removeFromMixer(node: bundle.fader)

            // Then re-add
            AudioEngineManager.shared.addToMixer(node: bundle.fader)

            if audioState == .playing {
                startVoice(bundle.fader, voice: bundle.voice)
            }
        }
    }

    
    func updateWithFaceData(_ faceData: FaceData) {
        // this gets called when we get new AR data from the face

        self.faceData = faceData

        var harmonies: [Int]

        // Use extracted interpolation method
        let interpolatedValues = interpolateFaceParameters(from: faceData)

        let interpolatedJawOpen: Float = interpolatedValues[.jawOpen] ?? 0
        let interpolatedMouthFunnel: Float = interpolatedValues[.mouthFunnel] ?? 0
        let interpolatedMouthClose: Float = interpolatedValues[.mouthClose] ?? 0

        //print("Interpolated Jaw Open: // \(interpolatedJawOpen)")

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
        //print("🔔 Posting HighlightPianoKey for note \(displayNote)")
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("HighlightPianoKey"), object: nil, userInfo: ["midiNote": displayNote])
        }

        // Use harmonyMaker with current key, no chordType argument
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
            harmonies.append(harmonies.last ?? currentPitch) // Repeat the last harmony or use `currentPitch`
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
                let voice = voiceBundles[index].voice
                let currentFrequency = midiNoteToFrequency(harmony)
                let previousTargetFrequency = Self.lastTargetFrequency[index]

                // If frequency changes significantly, start new glissando
                if abs(currentFrequency - previousTargetFrequency) > 0.1 {
                    Self.glissandoStartTime[index] = now
                    Self.glissandoEndTime[index] = now + (Double(glissandoSpeed) / 1000)
                    vibratoActivationTime[index] = Self.glissandoEndTime[index]
                    Self.targetFrequency[index] = currentFrequency
                    Self.frequencyStartValue[index] = voice.frequency
                    Self.lastTargetFrequency[index] = currentFrequency
                    Self.shouldApplyGlissando[index] = true
                }

                // Apply glissando if active
                if Self.shouldApplyGlissando[index] {
                    let glissDuration = Self.glissandoEndTime[index] - Self.glissandoStartTime[index]
                    let glissProgress = (now - Self.glissandoStartTime[index]) / glissDuration
                    let clampedProgress = max(0.0, min(1.0, glissProgress))
                    voice.frequency = Self.frequencyStartValue[index] + Float(clampedProgress) * (Self.targetFrequency[index] - Self.frequencyStartValue[index])

                    if clampedProgress >= 1.0 {
                        Self.shouldApplyGlissando[index] = false
                    }
                }
                // Vibrato is applied only after glissando is finished and after vibrato activation time
                if !Self.shouldApplyGlissando[index] && now > vibratoActivationTime[index] {
                    let harmonyAttenuation: Float = (index == 0) ? 1.0 : 0.4 // Lead voice full vibrato, harmonies less
                    let attenuatedVibrato = vibratoAmount * harmonyAttenuation
                    let vibratoOffset = sin(vibratoPhase) * (attenuatedVibrato / 100.0)
                    let vibratoFreq = currentFrequency * pow(2.0, vibratoOffset / 12.0)
                    voice.frequency = vibratoFreq
                }

                
                voice.index = interpolatedJawOpen
                //voice.lipShape = interpolatedMouthClose

            }
        }

        //print("audioState: \(audioState)")

        if audioState == .waitingForFaceData {
            print("OscillatorConductor.updateWithFaceData() setting audioState to .playing")
            audioState = .playing

            for (index, voiceBundle) in self.voiceBundles.enumerated() {
                let delay = Double(index) * 0.1
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.startVoice(voiceBundle.fader, voice: voiceBundle.voice)
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
        self.numOfVoices = settings.numOfVoices
        self.chordType = settings.chordType
        self.glissandoSpeed = settings.glissandoSpeed
        self.voicePitchLevel = settings.voicePitchLevel
        self.noteRangeSize = settings.noteRangeSize
        self.currentSettings = settings
        applyConductorSpecificSettings(from: settings)
    }
    
    func applyConductorSpecificSettings(from patch: PatchSettings) {
        print("OscillatorConductor.applyConductorSpecificSettings called with patch: \(patch)")

        if let anyValue = patch.conductorSpecificSettings?["vibratoAmount"]?.value {
            if let vibrato = FloatValue(from: anyValue) {
                self.vibratoAmount = vibrato
                self.conductorSpecificSettings["vibratoAmount"] = vibrato
            }
        }
    }

    
    func exportConductorSpecificSettings() -> [String: Any]? {
        return ["vibratoAmount": self.vibratoAmount]
    }
    
    
    func exportCurrentSettings() -> PatchSettings {
        return PatchSettings(
            id: currentSettings?.id ?? -1,
            name: currentSettings?.name ?? "Untitled Patch",
            key: MusicBrain.shared.currentKey,
            chordType: self.chordType,
            numOfVoices: self.numOfVoices,
            glissandoSpeed: self.glissandoSpeed,
            voicePitchLevel: self.voicePitchLevel,
            noteRangeSize: self.noteRangeSize,
            version: 1,
            conductorID: type(of: self).id,
            conductorSpecificSettings: exportConductorSpecificSettings()?.mapValues { AnyCodable($0) }
        )
    }
    
    // MARK: - VoiceConductorProtocol

    
    func makeSettingsUI(target: Any?, valueChangedAction: Selector, touchUpAction: Selector) -> [UIView] {
        var views: [UIView] = []

        let sliderData = createLabeledSlider(
            title: "Vibrato Amount",
            minLabel: "None",
            maxLabel: "Wide",
            minValue: 0.0,
            maxValue: 100.0,
            initialValue: self.vibratoAmount,
            target: target,
            valueChangedAction: valueChangedAction,
            touchUpAction: touchUpAction
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
            result += "\nVoice \(index + 1): Frequency: \(bundle.voice.frequency)"
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
