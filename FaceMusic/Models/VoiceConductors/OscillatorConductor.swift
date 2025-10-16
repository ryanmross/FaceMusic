import AudioKit
import AudioKitEX
import CAudioKitEX
import AudioToolbox
import SoundpipeAudioKit
import AnyCodable

class OscillatorConductor: ObservableObject, HasAudioEngine, VoiceConductorProtocol {
    

    static var id: String { "OscillatorConductor" }
    static var displayName: String = "Oscillator"
    static var version: Int = 1
    
    // Chain per voice: MorphingOscillator -> VocalTractFilter -> LowPassButterworthFilter -> Fader
    private var voiceBundles: [(voice: MorphingOscillator, filter: VocalTractFilter, lowpass: LowPassButterworthFilter, fader: Fader)] = []
    
    var faceData: FaceData?
    let engine = AudioEngineManager.shared.engine
    

    static var defaultPatches: [PatchSettings] {
        return [
            PatchSettings(
                id: -2001,
                name: "Osc Saw Lead",
                tonicKey: .C,
                tonicChord: .major,
                numOfVoices: 3,
                glissandoSpeed: 20.0,
                voicePitchLevel: VoicePitchLevel.medium,
                noteRangeSize: NoteRangeSize.medium,
                version: Self.version,
                conductorID: Self.id,
                imageName: "oscillator_saw_icon",
                conductorSpecificSettings: [
                    "vibratoAmount": AnyCodable(50.0),
                    "waveformMorph": AnyCodable(3.0),
                    "lowPassCutoff": AnyCodable(10000.0)
                ]
            ),
            PatchSettings(
                id: -2002,
                name: "Osc Smooth Sine",
                tonicKey: .C,
                tonicChord: .minor,
                numOfVoices: 2,
                glissandoSpeed: 30.0,
                voicePitchLevel: VoicePitchLevel.medium,
                noteRangeSize: NoteRangeSize.medium,
                version: Self.version,
                conductorID: Self.id,
                imageName: "oscillator_sine_icon",
                conductorSpecificSettings: [
                    "vibratoAmount": AnyCodable(20.0),
                    "waveformMorph": AnyCodable(2.0),
                    "lowPassCutoff": AnyCodable(12000.0)
                ]
            )
        ]
    }

    static var defaultPatch: PatchSettings {
        return defaultPatches.first!
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

    // Continuous morph value for MorphingOscillator.index (0.0 = triangle, 1.0 = square, 2.0 = sine, 3.0 = saw)
    @Published var waveformMorph: Float = 0.0 {
        didSet {
            // Clamp 0...3
            if waveformMorph < 0.0 { waveformMorph = 0.0 }
            if waveformMorph > 3.0 { waveformMorph = 3.0 }
            // Apply to all existing voices
            for bundle in voiceBundles {
                bundle.voice.index = AUValue(waveformMorph)
            }
        }
    }

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

    // LPF settings are stored and persisted in **Hz**.
    // Shared mapping constants and helpers (log scale 20 Hz .. 20 kHz)
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

    @Published var globalLowPassCutoffHz: Float = 10000.0 { // Hz, Butterworth LPF cutoff
        didSet {
            // Sanitize to audible range and apply live
            let clamped = max(lpfMinHz, min(lpfMaxHz, globalLowPassCutoffHz))
            if globalLowPassCutoffHz != clamped { globalLowPassCutoffHz = clamped; return }
            
            //Log.line(actor: "〰️ OscillatorConductor", fn: "var globalLowPassCutoffHz", "\(globalLowPassCutoffHz)")

            
            
            // Push to all active voices in real-time
            for bundle in voiceBundles {
                if bundle.lowpass.cutoffFrequency != clamped {
                    bundle.lowpass.cutoffFrequency = clamped
                }
            }
            
        }
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
            Log.line(actor: "〰️ OscillatorConductor", fn: "numOfVoices", "numOfVoices changed to \(numOfVoices), triggering updateVoiceCount()")

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
    }
    
    internal func updateVoiceCount() {
        
        let currentCount = voiceBundles.count
        let desiredCount = numOfVoices
        
        Log.line(actor: "〰️ OscillatorConductor", fn: "updateVoiceCount", "Update voice count with numOfVoices: \(numOfVoices). currentCount: \(currentCount), desiredCount: \(desiredCount)")
        
        if currentCount == desiredCount {
            Log.line(actor: "〰️ OscillatorConductor", fn: "updateVoiceCount", "Voice count unchanged.  currentCount: \(currentCount), desiredCount: \(desiredCount)")

        } else if currentCount < desiredCount {
            
            Log.line(actor: "〰️ OscillatorConductor", fn: "updateVoiceCount", "Adding voices. currentCount: \(currentCount), desiredCount: \(desiredCount)")

            for _ in currentCount..<desiredCount {
                let osc = MorphingOscillator(waveformArray: [Table(.triangle), Table(.square), Table(.sine), Table(.sawtooth)])
                osc.index = AUValue(waveformMorph)
                let filter = VocalTractFilter(osc)
                let lowpass = LowPassButterworthFilter(filter)
                lowpass.cutoffFrequency = globalLowPassCutoffHz
                let fader = Fader(lowpass, gain: 0.0)
                AudioEngineManager.shared.addToMixer(node: fader)
                voiceBundles.append((voice: osc, filter: filter, lowpass: lowpass, fader: fader))
                vibratoActivationTime.append(0.0)
                if audioState == .playing {
                    Log.line(actor: "〰️ OscillatorConductor", fn: "updateVoiceCount", "Starting new voice.")

                    startVoice(fader, voice: osc, filter: filter, lowpass: lowpass)
                }
            }
        } else {
            
            Log.line(actor: "〰️ OscillatorConductor", fn: "updateVoiceCount", "Removing voices. currentCount: \(currentCount), desiredCount: \(desiredCount)")

            for _ in desiredCount..<currentCount {
                if let last = voiceBundles.popLast() {
                    Log.line(actor: "〰️ OscillatorConductor", fn: "updateVoiceCount", "Stopping voice.")

                    stopVoice(last.fader, voice: last.voice, filter: last.filter, lowpass: last.lowpass)
                    AudioEngineManager.shared.removeFromMixer(node: last.fader)
                    vibratoActivationTime.removeLast()
                }
            }
        }
        
        // log mixer state
        AudioEngineManager.shared.logMixerState("after updateVoiceCount")
    }

    private func startVoice(_ fader: Fader, voice: MorphingOscillator, filter: VocalTractFilter, lowpass: LowPassButterworthFilter) {
        fader.gain = 0.0
        
        Log.line(actor: "〰️ OscillatorConductor", fn: "startVoice", "with lowpass: \(globalLowPassCutoffHz)")

        voice.index = AUValue(waveformMorph)
        voice.start()
        filter.start()
        lowpass.cutoffFrequency = globalLowPassCutoffHz
        lowpass.start()
        let fadeEvent = AutomationEvent(targetValue: 1.0, startTime: 0.0, rampDuration: 0.1)
        fader.automateGain(events: [fadeEvent])
    }

    private func stopVoice(_ fader: Fader, voice: MorphingOscillator, filter: VocalTractFilter, lowpass: LowPassButterworthFilter) {
        Log.line(actor: "〰️ OscillatorConductor", fn: "stopVoice", "")

        lowpass.stop()
        let fadeEvent = AutomationEvent(targetValue: 0.0, startTime: 0.0, rampDuration: 0.1)
        fader.automateGain(events: [fadeEvent])
        filter.stop()
        voice.stop()
    }
    
    func stopAllVoices() {
        Log.line(actor: "〰️ OscillatorConductor", fn: "stopAllVoices", "")

        for bundle in voiceBundles {
            stopVoice(bundle.fader, voice: bundle.voice, filter: bundle.filter, lowpass: bundle.lowpass)
        }
    }
    
    func updateIntervalChordTypes() {
        // Removed: No longer used with MusicBrain types
    }
    

    func disconnectFromMixer() {
        
        Log.line(actor: "〰️ OscillatorConductor", fn: "disconnectFromMixer", "🔌 Disconnecting voices from mixer...")

        voiceBundles.forEach { bundle in
            AudioEngineManager.shared.removeFromMixer(node: bundle.fader)
            if audioState == .playing {
                bundle.lowpass.stop()
                bundle.filter.stop()
                bundle.voice.stop()
            }
        }
        audioState = .stopped
    }

    func connectToMixer() {
        
        Log.line(actor: "〰️ OscillatorConductor", fn: "connectToMixer", "🔗 Reconnecting voices to mixer. Only starts them if audio is playing.")

        for bundle in voiceBundles {
            AudioEngineManager.shared.removeFromMixer(node: bundle.fader)
            AudioEngineManager.shared.addToMixer(node: bundle.fader)
            if audioState == .playing {
                startVoice(bundle.fader, voice: bundle.voice, filter: bundle.filter, lowpass: bundle.lowpass)
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
                let filter = voiceBundles[index].filter
                let lowpass = voiceBundles[index].lowpass
                
                // LPF is driven by globalLowPassCutoffHz's didSet; just mirror if needed
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

                // Apply filter parameters
                filter.jawOpen = faceData.jawOpen
                filter.tongueDiameter = faceData.tongueDiameter
                filter.tonguePosition = faceData.tonguePosition
                filter.lipShape = faceData.lipOpen
                filter.nasality = 0.0
            }
        }

        //print("audioState: \(audioState)")

        if audioState == .waitingForFaceData {
            
            Log.line(actor: "〰️ OscillatorConductor", fn: "updateWithFaceData", "setting audioState to .playing")

            audioState = .playing

            for (index, voiceBundle) in self.voiceBundles.enumerated() {
                let delay = Double(index) * 0.1
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.startVoice(voiceBundle.fader, voice: voiceBundle.voice, filter: voiceBundle.filter, lowpass: voiceBundle.lowpass)
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
        
        Log.line(actor: "〰️ OscillatorConductor", fn: "applySettings", "applySettings called")

        
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
        
        self.numOfVoices = settings.numOfVoices
    }
    
    func applyConductorSpecificSettings(from patch: PatchSettings) {
        logPatches(patch, label: "〰️ OscillatorConductor.applyConductorSpecificSettings called with patch")

        if let anyValue = patch.conductorSpecificSettings?["vibratoAmount"]?.value {
            if let vibrato = FloatValue(from: anyValue) {
                self.vibratoAmount = vibrato
                self.conductorSpecificSettings["vibratoAmount"] = vibrato
            }
        }
        // Removed waveformIndex block as per instructions

        // Optional: load continuous waveform morph if present
        if let anyMorph = patch.conductorSpecificSettings?["waveformMorph"]?.value,
           let morph = FloatValue(from: anyMorph) {
            self.waveformMorph = max(0.0, min(3.0, morph))
            self.conductorSpecificSettings["waveformMorph"] = self.waveformMorph
        }
        // Optional: load low pass cutoff if present (always apply/persist in **Hz**).
        if let anyLP = patch.conductorSpecificSettings?["lowPassCutoff"]?.value,
           let lowPassCutoffHz = FloatValue(from: anyLP) {

            
            //Log.line(actor: "〰️ OscillatorConductor", fn: "applyConductorSpecificSettings", "lowPassCutoffHz: \(lowPassCutoffHz), patch.conductorSpecificSettings[lowpasscutoff]: \(String(describing: patch.conductorSpecificSettings?["lowPassCutoff"]?.value))")


            let clamped = max(lpfMinHz, min(lpfMaxHz, lowPassCutoffHz))
            self.globalLowPassCutoffHz = clamped
            self.conductorSpecificSettings["lowPassCutoff"] = clamped
            
            
            //Log.line(actor: "〰️ OscillatorConductor", fn: "applyConductorSpecificSettings", "lowPassCutoffHz: \(clamped)")

        }
    }

    // Safely coerce a heterogeneous value (from AnyCodable) into an Int
    private func intValue(from any: Any) -> Int? {
        switch any {
        case let v as Int:
            return v
        case let v as Int8:
            return Int(v)
        case let v as Int16:
            return Int(v)
        case let v as Int32:
            return Int(v)
        case let v as Int64:
            return Int(v)
        case let v as UInt:
            return Int(v)
        case let v as UInt8:
            return Int(v)
        case let v as UInt16:
            return Int(v)
        case let v as UInt32:
            return Int(v)
        case let v as UInt64:
            return Int(v)
        case let v as Float:
            return Int(v)
        case let v as Double:
            return Int(v)
        case let s as String:
            return Int(s)
        default:
            return nil
        }
    }
    
    func exportConductorSpecificSettings() -> [String: Any]? {
        return [
            "vibratoAmount": self.vibratoAmount,
            "waveformMorph": self.waveformMorph,
            "lowPassCutoff": self.globalLowPassCutoffHz
        ]
    }
    
    
    func exportCurrentSettings() -> PatchSettings {
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
    
    // Adds four tick dots aligned to integer positions (0,1,2,3) on a UISlider
    private func addTickDots(to slider: UISlider, dotColor: UIColor = .tertiaryLabel) {
        // Remove existing ticks if re-adding
        slider.subviews.filter { $0.tag == 999_001 }.forEach { $0.removeFromSuperview() }

        // Ensure layout is up to date
        slider.layoutIfNeeded()

        // Compute track rect in slider's coordinate space
        let trackRect = slider.trackRect(forBounds: slider.bounds)
        let trackOriginX = trackRect.origin.x
        let trackWidth = trackRect.width
        let trackCenterY = trackRect.midY

        // For values 0..3, compute normalized position and x location
        for i in 0...3 {
            let normalized = CGFloat(i) / 3.0
            let x = trackOriginX + normalized * trackWidth

            let dotSize: CGFloat = 6.0
            let dot = UIView(frame: CGRect(x: x - dotSize/2, y: trackCenterY - dotSize/2, width: dotSize, height: dotSize))
            dot.backgroundColor = dotColor
            dot.layer.cornerRadius = dotSize / 2
            dot.isUserInteractionEnabled = false
            dot.tag = 999_001 // mark for cleanup if needed
            dot.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
            slider.addSubview(dot)
        }
    }
    
    // Align an array of labels so their centers sit on the slider's integer tick positions (0..3)
    private func alignLabels(_ labels: [UILabel], to slider: UISlider) {
        slider.layoutIfNeeded()
        guard let superview = slider.superview, !labels.isEmpty else { return }

        let trackRect = slider.trackRect(forBounds: slider.bounds)
        let trackOriginX = trackRect.origin.x
        let trackWidth = trackRect.width

        // Convert slider origin to the labels' superview coordinate space
        let sliderOriginInSuperview = slider.convert(CGPoint.zero, to: superview)

        for (i, label) in labels.enumerated() {
            let normalized = CGFloat(i) / 3.0 // 0, 1/3, 2/3, 1
            let xInSlider = trackOriginX + normalized * trackWidth
            let xInSuperview = sliderOriginInSuperview.x + xInSlider

            // Ensure the label has a valid size before positioning
            label.sizeToFit()
            var frame = label.frame
            frame.origin.x = xInSuperview - frame.width / 2.0
            // Keep current y (labels container controls vertical position)
            label.frame = frame
        }
    }
    
    // MARK: - VoiceConductorProtocol

    
    func makeSettingsUI(target: Any?, valueChangedAction: Selector, touchUpAction: Selector) -> [UIView] {
        var views: [UIView] = []

        // Waveform using reusable helper with track-aligned labels and tick dots
        let waveform = createLabeledSlider(
            title: "Waveform",
            minLabel: "", // ignored when trackLabels provided
            maxLabel: "",
            minValue: 0.0,
            maxValue: 3.0,
            initialValue: self.waveformMorph,
            target: target,
            valueChangedAction: valueChangedAction,
            touchUpAction: touchUpAction,
            trackLabels: ["Triangle", "Square", "Sine", "Saw"],
            integerTickCount: 4,
            showShadedBox: true,
            liveUpdate: { [weak self] (v: Float) in
                self?.waveformMorph = v
            },
            persist: { [weak self] (v: Float) in
                self?.waveformMorph = v
                self?.conductorSpecificSettings["waveformMorph"] = v
            }
        )
        // Removed waveform.slider.accessibilityIdentifier that referred to waveformIndex; keep it for waveformMorph only if needed
        waveform.slider.accessibilityIdentifier = "waveformMorph"
        views.append(waveform.container)

        // Low Pass control (logarithmic mapping)
        let currentCutoff = max(lpfMinHz, min(lpfMaxHz, self.globalLowPassCutoffHz))
        
        //print("lowPass currentCutoff: \(currentCutoff)")
        
        // we are storing lowPass as Hz everywhere we can.  toSlider converts the hz being sent to the slider to a 0-1 float so that it can be displayed
        let lowPass = createLabeledSlider(
            title: "Low Pass",
            minLabel: "20 Hz",
            maxLabel: "20 kHz",
            minValue: 0.0,        // normalized 0..1
            maxValue: 1.0,
            initialValue: currentCutoff,  // in hz
            target: target,
            valueChangedAction: valueChangedAction,
            touchUpAction: touchUpAction,
            showShadedBox: true,
            liveUpdate: { [weak self] (hz: Float) in
                guard let self = self else { return }
                // Push to engine in real time via didSet
                self.globalLowPassCutoffHz = hz
            },
            persist: { [weak self] (hz: Float) in
                guard let self = self else { return }
                // Finalize value and persist to settings in Hz
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

        let vibratoSlider = createLabeledSlider(
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

        vibratoSlider.slider.accessibilityIdentifier = "vibratoAmount"
        vibratoSlider.valueLabel.accessibilityIdentifier = "vibratoAmountValueLabel"

        vibratoSlider.slider.addAction(UIAction { _ in
            vibratoSlider.valueLabel.text = "\(Int(vibratoSlider.slider.value)) ms"
        }, for: .valueChanged)

        views.append(vibratoSlider.container)
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

extension OscillatorConductor: ConductorValueMappingProviding {
    var valueConverters: [String: (Float) -> Float] {
        return [
            // Map normalized 0..1 slider value to Hz using existing helper
            "lowPassCutoff": { [weak self] normalized in
                guard let self = self else { return normalized }
                return self.lpfNormalizedToHz(normalized)
            }
        ]
    }
}

