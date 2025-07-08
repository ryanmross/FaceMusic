import Foundation
import Tonic

class HarmonyMaker {
    
    let appSettings = AppSettings()
    
    // Function to generate harmony by picking notes from the chord and key
    func voiceChord(key: Key, chordType: ChordType, currentPitch: Pitch, numOfVoices: Int8 = 1) -> [Pitch] {
        // Ensure at least one voice is requested
        guard numOfVoices > 0 else { return [] }
        
        //print("voiceChord called, with key: \(key.root) chordType: \(chordType.description) currentPitch: \(currentPitch.midiNoteNumber) numOfVoices: \(numOfVoices)")
        
        let chord = Chord(key.root, type: chordType)
        
        // Initialize the harmony array starting with the current pitch
        var harmony: [Pitch] = [currentPitch]
        
        // Generate a set of all possible pitches for the chord in the given key
        var chordPitches: [Pitch] = []
        
        for noteClass in chord.noteClasses {
            //print("noteClass: \(noteClass.description)")
            // Map each NoteClass to every possible Pitch in MIDI range (0 to 127)
            chordPitches += (0...127).compactMap { midiValue in
                let pitch = Pitch(intValue: midiValue)
                
                let note = Note(pitch: pitch, key: key)
                return note.noteClass == noteClass ? pitch : nil
            }
        }
        
        
        // Filter out non-root notes below the lowNoteThreshold
        let rootNoteClass = chord.root
        chordPitches = chordPitches.filter { pitch in
            pitch.midiNoteNumber >= appSettings.lowNoteThreshold || Note(pitch: pitch, key: key).noteClass == rootNoteClass
        }
        
        // Sort the pitches to ensure proper ordering for finding lower notes
        chordPitches.sort(by: { $0.midiNoteNumber > $1.midiNoteNumber }) // Descending order
        
        // Start from the current pitch and pick the next lower note for each voice
        var currentPitch = currentPitch
        for _ in 1..<numOfVoices {
            if let nextLowerPitch = chordPitches.first(where: { $0.midiNoteNumber < currentPitch.midiNoteNumber }) {
                harmony.append(nextLowerPitch)
                currentPitch = nextLowerPitch
            } else if let lowestPitch = chordPitches.last {
                // No lower note available, double the lowest root note by transposing up an octave
                let doubledPitch = Pitch(intValue: Int(lowestPitch.midiNoteNumber) + 12)
                harmony.append(doubledPitch)
                currentPitch = doubledPitch
            } else {
                break // Stop if there are no valid pitches in the chord
            }
        }
        
        return harmony
    }
}
