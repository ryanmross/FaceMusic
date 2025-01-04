import AudioKit
import AudioToolbox
import SoundpipeAudioKit
import Tonic

class VoiceConductor: ObservableObject, HasAudioEngine {
    
    var faceData: FaceData?
    let engine = AudioEngine()
    let mixer = Mixer()
    
    // need to let user pick these
    var key: Key = Key(root: .C , scale: .minor)
    
    var pitchSet = PitchSet()
    
    
    
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
        
        // create the pitch set with pitches based on our key
        self.pitchSet = refreshPitchSet(for: self.key)
        
    }
    
    func refreshPitchSet(for key: Key) -> PitchSet {
        pitchSet = PitchSet() // Initialize the PitchSet here
        
        for midiNote in -60...120 { // MIDI note range from -60 (C-2) to 120 (B8)
            let pitch = Pitch(intValue: midiNote)
            if pitch.existsNaturally(in: key) {
                pitchSet.add(pitch)
            }
        }
        return pitchSet
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

        let interpolatedPitch: Int8 = Int8(faceData.pitch.interpolated(
            fromLowerBound: -1,
            fromUpperBound: 0.4,
            toLowerBound: 35,
            toUpperBound: 100))

        let interpolatedJawOpen: Float = faceData.jawOpen.interpolated(
            fromLowerBound: 0,
            fromUpperBound: 1,
            toLowerBound: 1,
            toUpperBound: 0)

        let interpolatedMouthClose: Float = faceData.mouthClose.interpolated(
            fromLowerBound: 0,
            fromUpperBound: 1,
            toLowerBound: 0,
            toUpperBound: 1)

        let interpolatedMouthFunnel: Float = faceData.mouthFunnel.interpolated(
            fromLowerBound: 0,
            fromUpperBound: 1,
            toLowerBound: 0,
            toUpperBound: 1)

        let scaledNote = self.mapToNearestScaleTone(midiNote: interpolatedPitch, key: self.key)
        let midiNoteToFrequency: Float = self.midiNoteToFrequency(scaledNote)

        self.voc.frequency = midiNoteToFrequency
        self.voc.tongueDiameter = interpolatedJawOpen
        self.voc.tonguePosition = interpolatedMouthFunnel
        self.voc.tenseness = 1.0
        self.voc.nasality = 0.0
        
    }

    func mapToNearestScaleTone(midiNote: Int8, key: Key) -> Int8 {
        let inputPitch = Pitch(intValue: Int(midiNote))
        var closestPitch: Pitch? = nil
        var smallestDifference = Int8.max

        // Loop through a range of possible MIDI notes and compare with pitchSet
        for i in -60...120 { // MIDI note range
            let pitch = Pitch(intValue: i)
            if pitch.existsNaturally(in: key) && pitchSet.contains(pitch) {
                let difference = abs(pitch.midiNoteNumber - inputPitch.midiNoteNumber)
                if difference < smallestDifference {
                    smallestDifference = difference
                    closestPitch = pitch
                }
            }
        }
        
        return Int8(closestPitch!.intValue )
    }


//    func mapToNearestScaleTone(midiNote: Int8, key: Key) -> Int8 {
//        // Define the MIDI note numbers for the C major scale
//        let scale: [Int8] = [0, 2, 4, 5, 7, 9, 11,
//                                        12, 14, 16, 17, 19, 21, 23,
//                                        24, 26, 28, 29, 31, 33, 35,
//                                        36, 38, 40, 41, 43, 45, 47,
//                                        48, 50, 52, 53, 55, 57, 59,
//                                        60, 62, 64, 65, 67, 69, 71,
//                                        72, 74, 76, 77, 79, 81, 83,
//                                        84, 86, 88, 89, 91, 93, 95,
//                                        96, 98, 100, 101, 103, 105, 107,
//                                        108, 110, 112, 113, 115, 117, 119,
//                                        120, 122, 124, 125, 127]
//        
//        // Find the nearest note in the C major scale
//        var nearestNote = scale[0]
//        var minDistance = abs(Int(midiNote) - Int(nearestNote))
//        
//        for note in scale {
//            let distance = abs(Int(midiNote) - Int(note))
//            if distance < minDistance {
//                minDistance = distance
//                nearestNote = note
//            }
//        }
//        
//        return nearestNote
//    }



    
    func midiNoteToFrequency(_ midiNote: Int8) -> Float {
        return Float(440.0 * pow(2.0, (Float(midiNote) - 69.0) / 12.0))
    }

   
}

