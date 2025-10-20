import Foundation

class HarmonyMaker {
    
    private let minHarmonyPitch = 36
    private var previousPitch: Int?
    
    func voiceChord(currentPitch: Int, numOfVoices: Int = 1) -> [Int] {
        
        // currentPitch is the leading tone we are currently playing
        // currentChordRoot is the chord root we are building harmonies around
        // currentChordType is the chord type of the chord we are building harmonies around
        
        let currentSelectedChord: MusicBrain.ChordWithRoot = MusicBrain.shared.currentSelectedChord
        
        let currentChordRoot = currentSelectedChord.root
        let currentChordType = currentSelectedChord.type
        
        
        guard numOfVoices > 0 else { return [] }
        previousPitch = currentPitch

        let intervals = MusicBrain.shared.chordIntervals(for: currentChordType)

        var candidates: [Int] = []
        for octave in stride(from: 7, through: 2, by: -1) {
            // starting in octave 7, working down to octave 2
            
            let base = 12 * octave
            
            for interval in intervals {
                // step through each interval in musicbrain
                let pitch = currentChordRoot.rawValue + interval + base
                if pitch < currentPitch && pitch >= minHarmonyPitch {
                    // put all scale tones lower than currentPitch and above minHarmonyPitch into candidates
                    candidates.append(pitch)
                }
            }
        }

        struct ScoredNote {
            let pitch: Int
            let score: Int
        }

        let muddyThreshold = 48
        let veryMuddyThreshold = 36
        let previous = previousPitch ?? currentPitch
        let sopranoMotion = currentPitch - previous

        func score(note: Int) -> Int {
            var s = 0
            let interval = (note - currentChordRoot.rawValue) % 12

            // Prioritize essential chord tones
            if interval == intervals[1] { s += 30 } // 3rd
            if intervals.count > 3 && interval == intervals[3] { s += 25 } // 7th
            if interval == intervals[0] { s += 40 } // root (stronger priority)
            if intervals.count > 2 && interval == intervals[2] { s += 10 } // 5th

            // Penalize muddy regions more strongly
            if note < veryMuddyThreshold {
                s -= 50
            } else if note < muddyThreshold {
                s -= 25
            }

            // Encourage contrary motion
            let harmonyMotion = note - currentPitch
            if (harmonyMotion < 0) != (sopranoMotion > 0) {
                s += 5
            }

            // Penalize tight spacing
            if currentPitch - note < 3 {
                s -= 10
            }

            return s
        }

        var scored: [ScoredNote] = candidates.map { ScoredNote(pitch: $0, score: score(note: $0)) }
        scored.sort { $0.score > $1.score }

        var final: [Int] = [currentPitch]
        var used: Set<Int> = [currentPitch]

        for cand in scored {
            if final.count >= numOfVoices { break }
            if !used.contains(cand.pitch) {
                final.append(cand.pitch)
                used.insert(cand.pitch)
            }
        }

        // Fallback if not enough voices
        if final.count < numOfVoices {
            let fill = scored.prefix(numOfVoices - final.count).map { $0.pitch }
            final.append(contentsOf: fill.filter { !used.contains($0) })
        }

        // Final sort and return
        final = Array(Set(final)).sorted(by: >)
        let noteNames = final.map { MusicBrain.NoteName.nameWithOctave(forMIDINote: $0) }
        //print("Harmony: \(final) - \(noteNames)")
        return final
    }
}
