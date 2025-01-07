import AudioKit
import AudioToolbox
import SoundpipeAudioKit
import Tonic

class VoiceConductor: ObservableObject, HasAudioEngine {
    
    var faceData: FaceData?
    let engine = AudioEngine()
    let mixer = Mixer()
    
    let appSettings = AppSettings()
    
    // need to let user pick these
    
    
    // key is a Tonic key that we keep updated with the user's current key
    var key: Key {
       didSet {
           refreshPitchSet()
       }
   }
    
    var chordType: ChordType
    
    // pitchSet is a PitchSet of what pitches are available in the current key
    var pitchSet = PitchSet()
    
    var currentPitch: Pitch?
    
    var harmonyMaker: HarmonyMaker
    
    @Published var numOfVoices: Int8 = 1 {
        didSet {
            pauseAudio()
            setupVoices()
            resumeAudio()
        }
    }
    
    
    @Published var isPlaying: Bool = false {
        didSet {
            if isPlaying {
                // Start all vocal tract objects in the voices array
                voices.forEach { $0.start() }
            } else {
                // Stop all vocal tract objects in the voices array
                voices.forEach { $0.stop() }
            }
        }
    }

    private var voices: [VocalTract] = []
    
    init() {

        // get default key from appSettings
        self.key = appSettings.defaultKey
        self.chordType = appSettings.defaultChordType
        
        
        self.harmonyMaker = HarmonyMaker()
        refreshPitchSet()
        setupVoices()
        
        // Set the mixer as the output of the audio engine
        engine.output = mixer
        
        do {
            try engine.start()
            print("Audio engine started successfully.")
        } catch let error as NSError {
            print("Audio engine failed to start with error: \(error.localizedDescription)")
        }
        

        self.harmonyMaker = HarmonyMaker()

        refreshPitchSet()
        self.currentPitch = nil
    }
    
    private func setupVoices() {
        
        print("SETUP VOICES.  numOfVoices: \(numOfVoices)")
        // Remove existing inputs from the mixer
        voices.forEach { mixer.removeInput($0) }
        voices.removeAll()
        
        // Create the new set of voices
        for _ in 0..<numOfVoices {
            let voc = VocalTract()
            mixer.addInput(voc)
            voices.append(voc)
        }
    }
    
    func refreshPitchSet() {
        print("**REFRESH PITCH SET")
        pitchSet = PitchSet() // Initialize the PitchSet here
        
        for midiNote in 0...127 { // MIDI note range
            let pitch = Pitch(intValue: midiNote)
            if pitch.existsNaturally(in: self.key) {
                pitchSet.add(pitch)
            }
        }
    }
    

    func pauseAudio() {
        print("**pause audio")
        isPlaying = false
        engine.stop()
    }

    func resumeAudio() {
        do {
            print("**resume audio")
            try engine.start()
            isPlaying = true
        } catch {
            print("Error resuming audio engine: \(error)")
        }
    }
    
    func updateWithNewData(with faceData: FaceData) {
        
        self.faceData = faceData
        
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
        
        let interpolatedPitchValue = interpolatedValues[.pitch] ?? 0.0
        let clampedInterpolatedPitch = min(max(interpolatedPitchValue, Float(Int8.min)), Float(Int8.max))
        let interpolatedPitch: Int8 = Int8(clampedInterpolatedPitch)

        let interpolatedJawOpen: Float = interpolatedValues[.jawOpen] ?? 0
        let interpolatedMouthFunnel: Float = interpolatedValues[.mouthFunnel] ?? 0
        
        
        
        // our current pitch
        currentPitch = self.mapToNearestScaleTone(midiNote: interpolatedPitch)
        
        guard let currentPitch = currentPitch else { return }
        let harmonies = harmonyMaker.voiceChord(key: key, chordType: chordType, currentPitch: currentPitch, numOfVoices: numOfVoices)
        
        for (index, harmony) in harmonies.enumerated() {
            if index < voices.count {
                let voice = voices[index]
                voice.frequency = midiNoteToFrequency(harmony.midiNoteNumber)
                voice.tongueDiameter = interpolatedValues[.jawOpen] ?? 0.5
                voice.tonguePosition = interpolatedValues[.mouthFunnel] ?? 0.5
                voice.tenseness = 1.0
                voice.nasality = 0.0
            }
        }
        /*
        if faceData.horizPosition == .left {
            // facing left
            harmonyNotes = chordMaker(inputNote: scaledNote, key: 7, scaleQuality: "major", numberOfVoices: self.voices.count)
        } else if faceData.horizPosition == .right {
            // facing right
            harmonyNotes = chordMaker(inputNote: scaledNote, key: 5, scaleQuality: "major", numberOfVoices: self.voices.count)
        } else {
            // facing center
            harmonyNotes = chordMaker(inputNote: scaledNote, key: 0, scaleQuality: "major", numberOfVoices: self.voices.count)
        }
        */
        
        
        
        
        
    }

    func mapToNearestScaleTone(midiNote: Int8) -> Pitch {
        //print("midiNote: \(midiNote)")
        
        let inputPitch = Pitch(intValue: Int(midiNote))
        var closestPitch: Pitch? = nil
        var smallestDifference = Int.max

        // Use BitSetAdapter's forEach to iterate only over the active pitches in the pitchSet
        pitchSet.forEach { pitch in
            let difference: Int = Int(abs(pitch.midiNoteNumber - inputPitch.midiNoteNumber))
            
            // Update the closest pitch if a smaller difference is found
            if difference < smallestDifference {
                smallestDifference = difference
                closestPitch = pitch
            }
        }
        
        guard let validClosestPitch = closestPitch else {
            print("No matching pitch found in pitchSet.")
            return inputPitch  // Return the original midiNote if no closest pitch was found
        }
        
        //print("Closest Pitch: \(validClosestPitch.midiNoteNumber)")
       
        return validClosestPitch
    }

    
    func midiNoteToFrequency(_ midiNote: Int8) -> Float {
        return Float(440.0 * pow(2.0, (Float(midiNote) - 69.0) / 12.0))
    }
  
    func returnAudioStats() -> String {
        print("Voices: \(voices)")
        return "Frequency: \(String(describing: voices[0].frequency)) \nisPlaying: \(String(describing: isPlaying)) \n"
        
    }
    
    func returnMusicStats() -> String {
        
        // Safely unwrap the optional currentPitch
        guard let unwrappedPitch = currentPitch else {
            return "Pitch data is unavailable."
        }

        // Create a Note instance with the unwrapped pitch
        let note = Note(pitch: unwrappedPitch, key: key)

        // Print debug information
        //print("Key: \(key.root), Note: \(note.letter)\(note.accidental)\(note.octave)")
        
        return String("Key: \(key.root) \(key.scale.description), Note: \(note.letter)\(note.accidental)\(note.octave)")
        
    }
    
    
   
}



