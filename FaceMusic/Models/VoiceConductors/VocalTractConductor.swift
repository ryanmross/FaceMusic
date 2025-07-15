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
    let engine = AudioEngine()
    let mixer = Mixer()
    

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

        engine.output = mixer

        updateVoiceCount()
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
                mixer.addInput(fader)
                voiceBundles.append((voice: voc, fader: fader))
                if audioState == .playing {
                    startVoice(fader, voice: voc)
                }
            }
        } else {
            for _ in desiredCount..<currentCount {
                if let last = voiceBundles.popLast() {
                    stopVoice(last.fader, voice: last.voice)
                    mixer.removeInput(last.fader)
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
            engine.stop()
        } else {
            // Fade out voices first
            print("**stop engine with fadeout")
            voiceBundles.forEach { stopVoice($0.fader, voice: $0.voice) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.engine.stop()
            }
        }
    }

    func startEngine() {
        do {
            print("**start engine")
            try engine.start()
            audioState = .waitingForFaceData
        } catch {
            print("Error starting audio engine: \(error)")
        }
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
        
        // we are interpolating pitch here instead of above.

        let mappedPitch = FaceDataBrain().mapPitch(rawPitch: faceData.pitch, lowRange: self.lowestNote, highRange: self.highestNote)
        
        //print("mappedPitch: \(mappedPitch)")

        let interpolatedJawOpen: Float = interpolatedValues[.jawOpen] ?? 0
        let interpolatedMouthFunnel: Float = interpolatedValues[.mouthFunnel] ?? 0
        let interpolatedMouthClose: Float = interpolatedValues[.mouthClose] ?? 0
        
        //print("Interpolated Jaw Open: // \(interpolatedJawOpen)")
        
        // our current pitch
        let (quantizedMidiNote, offset) = MusicBrain.shared.nearestQuantizedNote(for: mappedPitch)
        currentPitch = quantizedMidiNote // or store separately
        
        guard let currentPitch = currentPitch else { return }

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
