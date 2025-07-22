import Foundation

class HarmonyMaker {
    
    let appSettings = AppSettings()
    
    // Function to generate harmony by picking notes from the chord and key
    func voiceChord(currentPitch: Int, numOfVoices: Int = 1) -> [Int] {
        guard numOfVoices > 0 else { return [] }

        let key = MusicBrain.shared.currentKey

        let intervals = MusicBrain.shared.chordIntervals(for: MusicBrain.shared.currentChordType).sorted()
        
        //print("Intervals: \(intervals)")
        
        // Always include the lead note on top
        var harmony: [Int] = [currentPitch]

        if numOfVoices == 1 {
            return harmony
        }

        //print("key.rawValue: \(key.rawValue) key: \(key)")
        
        // Compute the root pitch around octave 4
        let rootPitch = key.rawValue + 12 * 4
        
        //print("rootPitch: \(rootPitch)")

        var harmoniesBelow: [Int] = []
        var octaveOffset = 0

        while harmoniesBelow.count < numOfVoices - 2 {
            for interval in intervals {
                let note = rootPitch + interval - 12 * octaveOffset
                if note < currentPitch {
                    harmoniesBelow.append(note)
                    if harmoniesBelow.count == numOfVoices - 2 {
                        break
                    }
                }
            }
            octaveOffset += 1
        }

        // Add the lowest note as the chord root in a lower octave
        var lowestRoot = rootPitch
        while lowestRoot >= currentPitch - 12 {
            lowestRoot -= 12
        }

        harmony.append(lowestRoot)
        harmony.append(contentsOf: harmoniesBelow)

        print("Harmony MIDI notes: \(harmony.sorted(by: >))")
        
        return harmony.sorted(by: >)
    }
}
