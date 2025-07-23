import Foundation

class HarmonyMaker {
    
    private var previousPitch: Int?
    
    func voiceChord(currentPitch: Int, numOfVoices: Int = 1) -> [Int] {
        guard numOfVoices > 0 else { return [] }
        previousPitch = currentPitch

        let key = MusicBrain.shared.currentKey
        let chordType = MusicBrain.shared.currentChordType
        let intervals = MusicBrain.shared.chordIntervals(for: chordType)

        // Extract 3rd and 7th intervals if present
        let thirdInterval = intervals.count > 1 ? intervals[1] : nil
        let seventhInterval = intervals.count > 3 ? intervals[3] : nil

        let rootPitch = key.rawValue + 12 * 4 // Base octave 4

        var harmony: [Int] = [currentPitch]
        if numOfVoices == 1 { return harmony }

        var possibleHarmonies: Set<Int> = []

        // Explicit prioritization for dominant 7th chords
        if chordType == .dominant7 {
            // Add the 3rd and 7th to possibleHarmonies if they are below currentPitch
            if let third = thirdInterval {
                let thirdPitch = key.rawValue + third + 12 * 3
                if thirdPitch < currentPitch {
                    possibleHarmonies.insert(thirdPitch)
                }
            }
            if let seventh = seventhInterval {
                let seventhPitch = key.rawValue + seventh + 12 * 3
                if seventhPitch < currentPitch {
                    possibleHarmonies.insert(seventhPitch)
                }
            }
        }

        // Determine clarity thresholds
        let muddyThreshold = 48
        let veryMuddyThreshold = 36

        // Add chord tones below currentPitch down to rootPitch - 2 octaves
        for octave in stride(from: 7, through: 2, by: -1) {
            let base = 12 * octave
            for interval in intervals {
                let pitch = key.rawValue + interval + base
                if pitch < currentPitch {
                    // New muddy/very muddy logic
                    if pitch < veryMuddyThreshold {
                        if interval == intervals[0] || (intervals.count > 2 && interval == intervals[2]) {
                            possibleHarmonies.insert(pitch)
                        }
                    } else if pitch < muddyThreshold {
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

        // Previous pitch and contrary motion logic
        let previousPitch = previousPitch ?? currentPitch
        let sopranoMotion = currentPitch - previousPitch
        let favorsContraryMotion: (Int) -> Bool = { note in
            let harmonyMotion = note - currentPitch
            return (harmonyMotion < 0) != (sopranoMotion > 0)
        }

        for note in sorted {
            if selected.count >= numOfVoices - 1 { break }
            // Leave more space below the soprano
            if note >= currentPitch - 3 { continue }
            let interval = lastPitch - note
            let minSpacing = max(3, 12 - currentPitch / 12)
            let maxSpacing = 12
            let isForbiddenInterval = [7, 12].contains(abs(lastPitch - note))

            if interval >= minSpacing && interval <= maxSpacing &&
               !isForbiddenInterval &&
               favorsContraryMotion(note) {
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
            // Use minSpacing/maxSpacing logic for spacing
            let minSpacing = max(3, 12 - currentPitch / 12)
            let maxSpacing = 12
            let last = finalHarmony.last ?? currentPitch
            let interval = abs(last - candidate)
            if !finalHarmony.contains(candidate) && interval >= minSpacing && interval <= maxSpacing {
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
