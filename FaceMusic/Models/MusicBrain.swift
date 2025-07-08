//
//  MusicBrain.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//


struct MusicBrain {
    // Enum for chord types
    enum ChordType: String, CaseIterable {
        case major
        case minor
        case diminished
        case augmented
        case suspended
        // Add other chord types as needed
    }

    // Enum for note names
    enum NoteName: String, CaseIterable {
        case C, CSharp, D, DSharp, E, F, FSharp, G, GSharp, A, ASharp, B
    }

    // Enum for scale types
    enum ScaleType: String, CaseIterable {
        case major
        case minor
        case pentatonic
        case chromatic

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
            }
        }
    }

    static let defaultKey: NoteName = .C
    static let defaultScale: ScaleType = .major
    static let defaultChordType: ChordType = .major

    // Quantize a MIDI note (0-127) to the nearest note in the scale
    static func quantize(midiNote: Int, key: NoteName, scale: ScaleType) -> Int {
        let keyOffset = NoteName.allCases.firstIndex(of: key) ?? 0
        let octave = midiNote / 12
        let noteInOctave = midiNote % 12

        let scaleNotes = scale.intervals.map { ($0 + keyOffset) % 12 }
        let closest = scaleNotes.min(by: { abs($0 - noteInOctave) < abs($1 - noteInOctave) }) ?? noteInOctave

        return octave * 12 + closest
    }
}
