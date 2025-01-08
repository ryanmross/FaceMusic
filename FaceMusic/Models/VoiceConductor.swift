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
           updateIntervalChordTypes()
       }
   }
    
    var chordType: ChordType
    
    var intervalChordTypes: [(key: Key, chordType: ChordType)] = []
    
    
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
            if isPlaying && isReadyToPlay {  // Only start voices when data is ready
                voices.forEach { $0.start() }
            } else {
                voices.forEach { $0.stop() }
            }
        }
    }

    private var voices: [VocalTract] = []
    private var isReadyToPlay = false  // Flag to track when data is ready

    
    init() {

        // get default key from appSettings
        self.key = appSettings.defaultKey
        self.chordType = appSettings.defaultChordType
        
        
        self.harmonyMaker = HarmonyMaker()
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
        
        updateIntervalChordTypes()  // Update intervals and chord types at startup
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
    
    func updateIntervalChordTypes() {
        
        // Extract root and intervals from the current scale
        let root = key.root
        let scale = key.scale
        let intervals = scale.intervals
        
        // Clear the existing data
        intervalChordTypes.removeAll()
        
        // Loop through each interval in the current scale
        for (index, interval) in intervals.enumerated() {
            // Calculate the new root note for the scale by shifting
            let newRoot = root.canonicalNote.shiftUp(interval)
            
            
            
            
            let newInterval = shiftArray(intervals, by: index)
            let newScale = Scale(intervals: intervals, description: "Scale shifted by \(index)")
            
            var newChordType: ChordType
            
            // Assuming appSettings.scales is an array of tuples: [(key: String, value: Scale)]
            if let foundScale = appSettings.scales.first(where: { $0.scale == newScale }) {
                newChordType = foundScale.chordType
                // Now newChordType has the ChordType corresponding to the newScale
                print("Found ChordType for \(newScale.description): \(newChordType)")
            } else {
                newChordType = ChordType.major
                print("Scale \(newScale.description) not found in appSettings.scales.")
            }
            
            
            let newKey = Key(root: newRoot!.noteClass, scale: newScale)
        
            
            // Store the new key and its chordType in the intervalChordTypes array
            intervalChordTypes.append((key: newKey, chordType: newChordType))
        }
        
        // Debug print
        print("Updated Interval Chord Types: \(intervalChordTypes.map { "\($0.key.root.letter): \($0.chordType)" })")
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
        
        var harmonies: [Pitch]
        
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

        /*
         harmonies = harmonyMaker.voiceChord(key: key, chordType: chordType, currentPitch: currentPitch, numOfVoices: numOfVoices)
        
         */
         
        if faceData.horizPosition == .left {
            // facing left
            
            let newKeyAndChordType = intervalChordTypes[4]
            print("**Facing Left: Setting up harmonies with key: (")
            harmonies = harmonyMaker.voiceChord(key: newKeyAndChordType.key, chordType: newKeyAndChordType.chordType, currentPitch: currentPitch, numOfVoices: numOfVoices)

            //harmonies = chordMaker(inputNote: scaledNote, key: 7, scaleQuality: "major", numberOfVoices: self.voices.count)
        } else if faceData.horizPosition == .right {
            // facing right

            

            let newKeyAndChordType = intervalChordTypes[5]
            
            harmonies = harmonyMaker.voiceChord(key: newKeyAndChordType.key, chordType: newKeyAndChordType.chordType, currentPitch: currentPitch, numOfVoices: numOfVoices)

            //harmonies = chordMaker(inputNote: scaledNote, key: 5, scaleQuality: "major", numberOfVoices: self.voices.count)
        } else {
            // facing center
            //harmonies = chordMaker(inputNote: scaledNote, key: 0, scaleQuality: "major", numberOfVoices: self.voices.count)
            harmonies = harmonyMaker.voiceChord(key: key, chordType: chordType, currentPitch: currentPitch, numOfVoices: numOfVoices)

        }
        
        while harmonies.count < numOfVoices {
            harmonies.append(harmonies.last ?? currentPitch) // Repeat the last harmony or use `currentPitch`
        }
        
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
        

        

        
        
        // Ensure the voices are ready to start only when we receive the first pitch
        if !isReadyToPlay {
            isReadyToPlay = true
            // Start the audio playback once data is ready
            isPlaying = true  // This will trigger the didSet for isPlaying
        }
        
        
        
        
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
        //print("Voices: \(voices)")
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



/*  CODE FOR FINDING NEW KEY
 //index of what inverval we want to shift by
 let scaleNumber = 4
 
 let root = key.root
 let scale = key.scale
 let intervals = scale.intervals
 
 // choose new note and account for arrays starting at 0
 let newRoot = root.canonicalNote.shiftUp(intervals[scaleNumber + 1])
 
 let newIntervals = shiftArray(intervals, by: scaleNumber)
 let newScale = Scale(intervals: intervals, description: "Scale shifted by \(scaleNumber)")
 
 var newChordType: ChordType
 
 // Assuming appSettings.scales is an array of tuples: [(key: String, value: Scale)]
 if let foundScale = appSettings.scales.first(where: { $0.scale == newScale }) {
 newChordType = foundScale.chordType
 // Now newChordType has the ChordType corresponding to the newScale
 print("Found ChordType for \(newScale): \(newChordType)")
 } else {
 newChordType = ChordType.major
 print("Scale \(newScale) not found in appSettings.scales.")
 }
 
 
 let newKey = Key(root: newRoot!.noteClass, scale: newScale)
 
 */
