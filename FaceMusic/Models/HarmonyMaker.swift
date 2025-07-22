import Foundation

class HarmonyMaker {
    
    let appSettings = AppSettings()
    
    func voiceChord(currentPitch: Int, numOfVoices: Int = 1) -> [Int] {
        guard numOfVoices > 0 else { return [] }

        let key = MusicBrain.shared.currentKey
        let chordType = MusicBrain.shared.currentChordType
        let intervals = MusicBrain.shared.chordIntervals(for: chordType)

        let rootPitch = key.rawValue + 12 * 4 // Base octave 4

        var harmony: [Int] = [currentPitch]
        if numOfVoices == 1 { return harmony }

        var possibleHarmonies: Set<Int> = []

        // Determine clarity thresholds
        let muddyThreshold = 48
        let veryMuddyThreshold = 36

        // Add chord tones below currentPitch down to rootPitch - 2 octaves
        for octave in stride(from: 7, through: 2, by: -1) {
            let base = 12 * octave
            for interval in intervals {
                let pitch = key.rawValue + interval + base
                if pitch < currentPitch {
                    // Avoid muddy intervals in low register
                    if pitch < veryMuddyThreshold {
                        // Only allow root and fifth
                        if interval == intervals[0] || (intervals.count > 2 && interval == intervals[2]) {
                            possibleHarmonies.insert(pitch)
                        }
                    } else if pitch < muddyThreshold {
                        // Avoid 7ths and 3rds
                        if interval != intervals[1] && (intervals.count < 4 || interval != intervals[3]) {
                            possibleHarmonies.insert(pitch)
                        }
                    } else {
                        possibleHarmonies.insert(pitch)
                    }
                }
            }
        }

        // Ensure 3rd is present
        let third = key.rawValue + intervals[1] + 12 * 3
        if third < currentPitch {
            possibleHarmonies.insert(third)
        }

        // Ensure 5th if available
        if intervals.count > 2 {
            let fifth = key.rawValue + intervals[2] + 12 * 3
            if fifth < currentPitch {
                possibleHarmonies.insert(fifth)
            }
        }

        // Sort by descending and pick voices that are reasonably spaced
        let sorted = possibleHarmonies.sorted(by: >)
        var selected: [Int] = []
        var lastPitch = currentPitch

        for note in sorted {
            if selected.count >= numOfVoices - 1 { break }
            let interval = lastPitch - note
            if interval >= 3 && interval <= 12 { // avoid too tight or too wide
                selected.append(note)
                lastPitch = note
            }
        }

        // Fallback: If no notes were selected and more than one voice is requested,
        // pick the highest available possible harmony below currentPitch
        if selected.isEmpty && numOfVoices > 1 {
            if let backupNote = sorted.first {
                selected.append(backupNote)
            }
        }

        harmony.append(contentsOf: selected)

        // Ensure a strong bass root if currentPitch is high, while respecting voice count
        let bassThreshold = 65
        let bassRoot = key.rawValue + 12 * 4 + intervals.first!
        if currentPitch >= bassThreshold && !harmony.contains(bassRoot) {
            if harmony.count >= numOfVoices {
                // Replace the lowest harmony note with bassRoot, only if not already present
                harmony[harmony.count - 1] = bassRoot
            } else {
                harmony.append(bassRoot)
            }
        }

        // Deduplicate and sort
        var finalHarmony = Array(Set(harmony)).sorted(by: >)

        // Fill in with extra harmonies if under voice count
        var fillIndex = 0
        while finalHarmony.count < numOfVoices && fillIndex < sorted.count {
            let candidate = sorted[fillIndex]
            if !finalHarmony.contains(candidate) {
                finalHarmony.append(candidate)
            }
            fillIndex += 1
        }

        // If still not enough, duplicate next highest pitch (not a low muddy note)
        if finalHarmony.count < numOfVoices {
            let bassDuplicationThreshold = 36
            var fillPitch = finalHarmony.first(where: { $0 > bassDuplicationThreshold }) ?? finalHarmony.last!
            while finalHarmony.count < numOfVoices {
                finalHarmony.append(fillPitch)
            }
        }
        
        
        finalHarmony.sort(by: >)

        print("Harmony: \(finalHarmony)")
        return finalHarmony
    }
}
