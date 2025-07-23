import AudioKit
import AudioKitEX
import CAudioKitEX
import AudioToolbox
import SoundpipeAudioKit

class VocalTractConductor: ObservableObject, HasAudioEngine, VoiceConductorProtocol {
    

    static var id: String = "vocaltract"
    static var displayName: String = "Vocal Tract"
    
    private var voiceBundles: [(voice: VocalTract, fader: Fader)] = []
    
    var faceData: FaceData?
    let engine = AudioEngineManager.shared.engine
    

    static let defaultSettings = PatchSettings.default()
    
    enum AudioState {
        case stopped
        case waitingForFaceData
        case playing
    }
    
    var audioState: AudioState = .stopped
    
    var currentSettings: PatchSettings?

    var chordType: MusicBrain.ChordType
    
    var currentPitch: Int?
    
    var harmonyMaker: HarmonyMaker = HarmonyMaker()
    
    var lowestNote: Int
    var highestNote: Int
    var glissandoSpeed: Float
    
    @Published var numOfVoices: Int {
        didSet {
            updateVoiceCount()
        }
    }
    
    
    private var hasFaceData = false  // Flag to track when data is ready

    private var latestHarmonies: [Int]? = nil
    
    required init() {
        // get default key from defaultSettings
        let defaultSettings = PatchManager.shared.defaultPatchSettings
        self.chordType = defaultSettings.chordType
        self.lowestNote = defaultSettings.lowestNote
        self.highestNote = defaultSettings.highestNote
        self.glissandoSpeed = defaultSettings.glissandoSpeed
        self.numOfVoices = defaultSettings.numOfVoices
        self.currentSettings = defaultSettings

        AudioEngineManager.shared.engine.output = AudioEngineManager.shared.mixer
        

        updateVoiceCount()
        voiceBundles.forEach { $0.voice.start(); $0.voice.stop() }
        
    }
    
    internal func updateVoiceCount() {
        print("Update voice count with numOfVoices: \(numOfVoices)")
        let currentCount = voiceBundles.count
        let desiredCount = numOfVoices

        if currentCount == desiredCount {
            print("Voice count unchanged—refreshing voices")
            /*
            voiceBundles.forEach { stopVoice($0.fader, voice: $0.voice) }
            for (fader, voice) in voiceBundles.map({ ($0.fader, $0.voice) }) {
                if audioState == .playing {
                    startVoice(fader, voice: voice)
                }
            }
             */
        } else if currentCount < desiredCount {
            for _ in currentCount..<desiredCount {
                let voc = VocalTract()
                let fader = Fader(voc, gain: 0.0)
                AudioEngineManager.shared.mixer.addInput(fader)
                voiceBundles.append((voice: voc, fader: fader))
                if audioState == .playing {
                    startVoice(fader, voice: voc)
                }
            }
        } else {
            for _ in desiredCount..<currentCount {
                if let last = voiceBundles.popLast() {
                    stopVoice(last.fader, voice: last.voice)
                    AudioEngineManager.shared.mixer.removeInput(last.fader)
                }
            }
        }
    }

    private func startVoice(_ fader: Fader, voice: VocalTract) {
        fader.gain = 0.0
        print("startVoice...")
        voice.start()
        let fadeEvent = AutomationEvent(targetValue: 1.0, startTime: 0.0, rampDuration: 0.1)
        fader.automateGain(events: [fadeEvent])
    }

    private func stopVoice(_ fader: Fader, voice: VocalTract) {
        print("stopVoice...")
        let fadeEvent = AutomationEvent(targetValue: 0.0, startTime: 0.0, rampDuration: 0.1)
        fader.automateGain(events: [fadeEvent])
        voice.stop()
        
    }
    
    func updateIntervalChordTypes() {
        // Removed: No longer used with MusicBrain types
    }
    

    func stopEngine(immediate: Bool = false) {

        audioState = .stopped

        if immediate {
            // Immediately stop voices and engine, no fade
            print("**stop engine immediately")
            voiceBundles.forEach { voiceBundle in
                voiceBundle.voice.stop()
            }
            AudioEngineManager.shared.stopEngine()
        } else {
            // Fade out voices first
            print("**stop engine with fadeout")
            voiceBundles.forEach { stopVoice($0.fader, voice: $0.voice) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                AudioEngineManager.shared.stopEngine()
            }
        }
    }

    func startEngine() {
        AudioEngineManager.shared.startEngine()
        audioState = .waitingForFaceData

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("Engine warmed up, ready for face data.")
        }

        let outputNode = AudioEngineManager.shared.engine.avEngine.outputNode
        print("Engine started with sample rate: \(outputNode.outputFormat(forBus: 0).sampleRate)")
    }
    
    func updateWithFaceData(_ faceData: FaceData) {
        // this gets called when we get new AR data from the face
        
        self.faceData = faceData
        
        var harmonies: [Int]
        
        // grab AudioGenerationParameters from its file along with the interpolation bounds (tweak in AudioGenerationParameterMetadata file to adjust)
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

        // if faceData.horizPosition == .left {
        
        
        while harmonies.count < numOfVoices {
            harmonies.append(harmonies.last ?? currentPitch) // Repeat the last harmony or use `currentPitch`
        }
        
        for (index, harmony) in harmonies.enumerated() {
            if index < voiceBundles.count {
                let voice = voiceBundles[index].voice
                //voice.frequency = midiNoteToFrequency(harmony)
                
                let targetFreq = midiNoteToFrequency(harmony)
                if glissandoSpeed > 0 {
                    //print ("ramping to \(targetFreq)")
                    voice.$frequency.ramp(to: targetFreq, duration: Float(glissandoSpeed) / 1000.0)
                } else {
                    voice.frequency = targetFreq
                }
                
                
                voice.jawOpen = interpolatedJawOpen
                voice.lipShape = interpolatedMouthClose
                voice.tongueDiameter = 0.5
                voice.tonguePosition = 0.5
                voice.tenseness = 0.6
                voice.nasality = 0.0
            }
        }
        
        if audioState == .waitingForFaceData {
            audioState = .playing
            voiceBundles.forEach { voiceBundle in
                startVoice(voiceBundle.fader, voice: voiceBundle.voice)
            }
        }
        

        
        
        
}
    
    func applySettings(_ settings: PatchSettings) {
        self.numOfVoices = settings.numOfVoices
        self.chordType = settings.chordType
        self.lowestNote = settings.lowestNote
        self.highestNote = settings.highestNote
        self.glissandoSpeed = settings.glissandoSpeed
        self.currentSettings = settings
        
        updateVoiceCount()
    }
    
    func exportCurrentSettings() -> PatchSettings {
        return PatchSettings(
            id: currentSettings?.id ?? -1,
            name: currentSettings?.name ?? "Untitled Patch",
            key: MusicBrain.shared.currentKey,
            chordType: self.chordType,
            numOfVoices: self.numOfVoices,
            glissandoSpeed: self.glissandoSpeed,
            lowestNote: self.lowestNote,
            highestNote: self.highestNote,
            activeVoiceID: type(of: self).id
        )
    }

    
    func midiNoteToFrequency(_ midiNote: Int) -> Float {
        return Float(440.0 * pow(2.0, (Float(midiNote) - 69.0) / 12.0))
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
