import AudioKit
import AudioToolbox
import SoundpipeAudioKit
import Tonic

class VoiceConductor: ObservableObject, HasAudioEngine {
    
    var faceData: FaceData?
    let engine = AudioEngine()
    
    // need to let user pick these
    var key: Key = Key(root: .C , scale: .minor)
    
    var pitchSet = PitchSet()
    
    
    
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








    
    func midiNoteToFrequency(_ midiNote: Int8) -> Float {
        return Float(440.0 * pow(2.0, (Float(midiNote) - 69.0) / 12.0))
    }

   
}

