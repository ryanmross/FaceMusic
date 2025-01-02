import AudioKit
import AudioToolbox
import SoundpipeAudioKit
import Tonic

class VoiceConductor: ObservableObject, HasAudioEngine {
    
    var faceData: FaceData?
    
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

        let scaledNote = self.mapToNearestScaleTone(interpolatedPitch)
        let midiNoteToFrequency: Float = self.midiNoteToFrequency(scaledNote)

        self.voc.frequency = midiNoteToFrequency
        self.voc.tongueDiameter = interpolatedJawOpen
        self.voc.tonguePosition = interpolatedMouthFunnel
        self.voc.tenseness = 1.0
        self.voc.nasality = 0.0

    }

    
    
    func mapToNearestScaleTone(_ midiNote: Int8) -> Int8 {
        // Define the MIDI note numbers for the C major scale
        let scale: [Int8] = [0, 2, 4, 5, 7, 9, 11,
                                        12, 14, 16, 17, 19, 21, 23,
                                        24, 26, 28, 29, 31, 33, 35,
                                        36, 38, 40, 41, 43, 45, 47,
                                        48, 50, 52, 53, 55, 57, 59,
                                        60, 62, 64, 65, 67, 69, 71,
                                        72, 74, 76, 77, 79, 81, 83,
                                        84, 86, 88, 89, 91, 93, 95,
                                        96, 98, 100, 101, 103, 105, 107,
                                        108, 110, 112, 113, 115, 117, 119,
                                        120, 122, 124, 125, 127]
        
        // Find the nearest note in the C major scale
        var nearestNote = scale[0]
        var minDistance = abs(Int(midiNote) - Int(nearestNote))
        
        for note in scale {
            let distance = abs(Int(midiNote) - Int(note))
            if distance < minDistance {
                minDistance = distance
                nearestNote = note
            }
        }
        
        return nearestNote
    }
    
    func midiNoteToFrequency(_ midiNote: Int8) -> Float {
        return Float(440.0 * pow(2.0, (Float(midiNote) - 69.0) / 12.0))
    }
    
    
    
    
    let engine = AudioEngine()

    @Published var isPlaying: Bool = false {
        didSet { isPlaying ? voc.start() : voc.stop() }
    }

    var voc = VocalTract()

    init() {
        engine.output = voc
        do {
            try engine.start()
            print("Audio engine started successfully.")
        } catch let error as NSError {
            print("Audio engine failed to start with error: \(error.localizedDescription)")
        }
    }
}

