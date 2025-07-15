//
//  MusicBrain.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//

class MusicBrain {
    // Enum for chord types
    enum ChordType: String, CaseIterable, Codable {
        case major
        case minor
        case diminished
        case augmented
        case dominant7
        // Add other chord types as needed
    }

    // Enum for note names
    enum NoteName: Int, CaseIterable, Codable {
        case C = 0
        case CSharp = 1
        case D = 2
        case DSharp = 3
        case E = 4
        case F = 5
        case FSharp = 6
        case G = 7
        case GSharp = 8
        case A = 9
        case ASharp = 10
        case B = 11
        
        var displayName: String {
            switch self {
            case .C: return "C"
            case .CSharp: return "C#"
            case .D: return "D"
            case .DSharp: return "D#"
            case .E: return "E"
            case .F: return "F"
            case .FSharp: return "F#"
            case .G: return "G"
            case .GSharp: return "G#"
            case .A: return "A"
            case .ASharp: return "A#"
            case .B: return "B"
            }
        }
        
        static func noteAndOctave(for midiNote: Int) -> (NoteName, Int) {
            let note = NoteName(rawValue: midiNote % 12) ?? .C
            let octave = midiNote / 12 - 1
            return (note, octave)
        }
        
        static func nameWithOctave(forMIDINote midiNote: Int) -> String {
            let (note, octave) = noteAndOctave(for: midiNote)
            return "\(note.displayName)\(octave)"
        }
    }

    // Enum for scale types
    enum ScaleType: String, CaseIterable {
        case major
        case minor
        case pentatonic
        case chromatic
        case mixolydian
        case diminished
        case wholeTone

        // Return intervals for each scale
        var intervals: [Int] {
            switch self {
            case .major:
                return [0, 2, 4, 5, 7, 9, 11]
            case .minor:
                return [0, 2, 3, 5, 7, 8, 10]
            case .pentatonic:
                return [0, 2, 4, 7, 9]
            case .chromatic:
                return Array(0...11)
            case .mixolydian:
                return [0, 2, 4, 5, 7, 9, 10]
            case .diminished:
                return [0, 2, 3, 5, 6, 8, 9, 11]
            case .wholeTone:
                return [0, 2, 4, 6, 8, 10]
            }
        }

        static func scaleForChordType(_ chordType: ChordType) -> ScaleType {
            switch chordType {
            case .major:
                return .major
            case .minor:
                return .minor
            case .diminished:
                return .diminished
            case .augmented:
                return .wholeTone
            case .dominant7:
                return .mixolydian
            }
        }
    }

    // Current key and scale state
    private(set) var currentKey: NoteName
    private(set) var currentScale: ScaleType
    private(set) var currentChordType: ChordType = .major

    // Precomputed nearest note lookup table for MIDI notes 0-127.
    // Each entry is a tuple: (nearest quantized note, offset from original note)
    private var nearestNoteTable: [(note: Int, offset: Int)]
    
    static let shared = MusicBrain()

    // Initialize with default key and scale, and compute lookup table
    init(key: NoteName = .C, scale: ScaleType = .major) {
        self.currentKey = key
        self.currentScale = scale
        self.nearestNoteTable = Array(repeating: (note: 0, offset: 0), count: 128)
        updateKeyAndScale(key: key, scale: scale)
    }

    
    func updateKeyAndChordType(key: NoteName, chordType: ChordType) {
        
        //print("updateKeyAndChordType() received chordType: \(chordType)")
        
        self.currentChordType = chordType

        let scale = ScaleType.scaleForChordType(chordType)
        updateKeyAndScale(key: key, scale: scale)
    }
    
    
    // Update the current key and scale, and recompute the nearest note lookup table
    func updateKeyAndScale(key: NoteName, scale: ScaleType) {
        self.currentKey = key
        self.currentScale = scale

        let keyOffset = NoteName.allCases.firstIndex(of: key) ?? 0
        let scaleNotes = scale.intervals.map { ($0 + keyOffset) % 12 }

        // Precompute nearest quantized notes for all MIDI notes 0-127
        for midiNote in 0..<128 {
            let octave = midiNote / 12
            let noteInOctave = midiNote % 12

            // Find the closest scale note in the octave
            var minDistance = 12
            var closestNoteInOctave = noteInOctave
            for scaleNote in scaleNotes {
                let distance = abs(scaleNote - noteInOctave)
                if distance < minDistance {
                    minDistance = distance
                    closestNoteInOctave = scaleNote
                }
            }

            let quantizedNote = octave * 12 + closestNoteInOctave
            let offset = quantizedNote - midiNote
            nearestNoteTable[midiNote] = (note: quantizedNote, offset: offset)
        }
    }

    // Return the nearest quantized note and offset for a given MIDI note
    func nearestQuantizedNote(for midiNote: Int) -> (note: Int, offset: Int) {
        guard midiNote >= 0 && midiNote < 128 else {
            // If out of range, clamp to nearest valid MIDI note
            let clampedNote = min(max(midiNote, 0), 127)
            return nearestNoteTable[clampedNote]
        }
        return nearestNoteTable[midiNote]
    }
    
    
    func chordIntervals(for chordType: ChordType) -> [Int] {
        switch chordType {
        case .major:
            return [0, 4, 7] // root, major third, perfect fifth
        case .minor:
            return [0, 3, 7] // root, minor third, perfect fifth
        case .diminished:
            return [0, 3, 6] // root, minor third, diminished fifth
        case .augmented:
            return [0, 4, 8] // root, major third, augmented fifth
        case .dominant7:
            return [0, 4, 7, 10] // root, major third, perfect fifth, minor seventh
        }
    }
}

