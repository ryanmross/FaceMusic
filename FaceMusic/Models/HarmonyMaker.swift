import Foundation
import Tonic

class HarmonyMaker {
    // Function to generate harmony by picking notes from the chord and key
    func voiceChord(key: Key, chord: Chord, currentPitch: Pitch, numOfVoices: Int8 = 1) -> [Pitch] {
        // Initialize the harmony array starting with the current pitch
        var harmony: [Pitch] = [currentPitch]
        
        // Generate a set of all possible pitches for the chord in the given key
        var chordPitches: [Pitch] = []
        for noteClass in chord.noteClasses {
            print("noteClass: \(noteClass.description)")
            // Map each NoteClass to every possible Pitch in MIDI range (0 to 127)
            chordPitches += (0...127).compactMap { midiValue in
                let pitch = Pitch(intValue: midiValue)
                
                let note = Note(pitch: pitch, key: key)
                return note.noteClass == noteClass ? pitch : nil
            }
        }
        
        // Sort the pitches to ensure proper ordering for finding lower notes
        chordPitches.sort(by: { $0.midiNoteNumber > $1.midiNoteNumber }) // Descending order
        
        // Start from the current pitch and pick the next lower note for each voice
        var currentPitch = currentPitch
        for i in 1..<numOfVoices {
            
            if let nextLowerPitch = chordPitches.first(where: { $0.midiNoteNumber < currentPitch.midiNoteNumber }) {
                harmony.append(nextLowerPitch)
                currentPitch = nextLowerPitch
                print("\(i): \(nextLowerPitch.midiNoteNumber)")
            } else {
                print("No lower note found for currentPitch: \(currentPitch.midiNoteNumber)")
                break
            }
        }
        
        return harmony
    }
}
