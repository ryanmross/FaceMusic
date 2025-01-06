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
    
    // pitchSet is a PitchSet of what pitches are available in the current key
    var pitchSet = PitchSet()
    
    var currentPitch: Pitch?
    
    @Published var isPlaying: Bool = false {
        didSet {
            if isPlaying {
                voc.start()    // Start voc
                voc2.start()   // Start voc2
            } else {
                voc.stop()     // Stop voc
                voc2.stop()    // Stop voc2
            }
        }
    }

    var voc = VocalTract()
    
    var voc2 = VocalTract()


    init() {

        // Add voc to the mixer
        mixer.addInput(voc)
        mixer.addInput(voc2)
        
        // Set the mixer as the output of the audio engine
        engine.output = mixer
        
        do {
            try engine.start()
            print("Audio engine started successfully.")
        } catch let error as NSError {
            print("Audio engine failed to start with error: \(error.localizedDescription)")
        }
        
        // get default key from appSettings
        self.key = appSettings.defaultKey
        refreshPitchSet()
        self.currentPitch = nil
    }
    
    func refreshPitchSet() {
        print("***********REFRESH PITCH SET")
        pitchSet = PitchSet() // Initialize the PitchSet here
        
        for midiNote in 0...127 { // MIDI note range
            let pitch = Pitch(intValue: midiNote)
            if pitch.existsNaturally(in: self.key) {
                pitchSet.add(pitch)
            }
        }
    }
    

    func pauseAudio() {
        engine.stop()
    }

    func resumeAudio() {
        do {
            try engine.start()
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
        
        let interpolatedPitch: Int8 = Int8(interpolatedValues[.pitch] ?? 0)
        let interpolatedJawOpen: Float = interpolatedValues[.jawOpen] ?? 0
        let interpolatedMouthFunnel: Float = interpolatedValues[.mouthFunnel] ?? 0
        

        currentPitch = self.mapToNearestScaleTone(midiNote: interpolatedPitch)
        
        let midiNoteToFrequency: Float = self.midiNoteToFrequency(currentPitch!.midiNoteNumber)

        self.voc.frequency = midiNoteToFrequency
        self.voc.tongueDiameter = interpolatedJawOpen
        self.voc.tonguePosition = interpolatedMouthFunnel
        self.voc.tenseness = 1.0
        self.voc.nasality = 0.0
        
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
        
        return "Frequency: \(String(describing: voc.frequency)) \nisPlaying: \(String(describing: isPlaying)) \n"
        
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

