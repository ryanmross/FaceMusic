//
//  MusicBrain.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//
import Foundation

class MusicBrain {
    // Enum for chord types
    enum ChordType: String, CaseIterable, Codable {
        case major
        case minor
        case dominant7
        case diminished
        case augmented
        
        
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
            case .dominant7:
                return .mixolydian
            case .diminished:
                return .diminished
            case .augmented:
                return .wholeTone
            }
        }
    }
    
    private enum ARDataPitchRange {
        // the range of the data coming in from ARKit from the head that we will convert to pitch.
        static let min: Float = -1.0
        static let max: Float = 0.45
    }
    

    // Current key and scale state
    private(set) var currentKey: NoteName
    private(set) var currentScale: ScaleType
    private(set) var currentChordType: ChordType = .major
    
    private(set) var customScaleMask: UInt16? // nil = no override
    
    var currentScalePitchClasses: [Int] {
        if let mask = customScaleMask {
            return Self.pitchClasses(fromMask: mask)
        } else {
            return currentScale.intervals
        }
    }

    // Precomputed nearest note lookup table for MIDI notes 0-127.
    // Each entry is a nearest quantized note
    private var nearestNoteTable: [Int]
    
    static let shared = MusicBrain()

    // Initialize with default key and scale, and compute lookup table
    init(key: NoteName = .C, scale: ScaleType = .major) {
        self.currentKey = key
        self.currentScale = scale
        self.nearestNoteTable = []
        updateKeyAndScale(key: key, chordType: .major)
    }

    
    func updateKeyAndChordType(key: NoteName, chordType: ChordType) {
        
        //print("updateKeyAndChordType() received chordType: \(chordType)")
        
        self.currentChordType = chordType

        let scale = ScaleType.scaleForChordType(chordType)
        updateKeyAndScale(key: key, chordType: chordType)
    }
    
    
    func updateKeyAndScale(key: NoteName, chordType: ChordType, scaleMask: UInt16? = nil) {
        self.currentKey = key
        self.currentChordType = chordType
        self.customScaleMask = scaleMask

        if let mask = scaleMask {
            let scaleNotes = Self.pitchClasses(fromMask: mask)
            rebuildQuantization(withScaleClasses: scaleNotes)
        } else {
            let scale = ScaleType.scaleForChordType(chordType)
            self.currentScale = scale
            rebuildQuantization(withScaleClasses: scale.intervals.map { ($0 + key.rawValue) % 12 })
        }
    }

    // Return the nearest quantized note for a given raw pitch float
    func nearestQuantizedNote(
        rawPitch: Float,
        lowestNote: Int,
        highestNote: Int
    ) -> Int {
        let clampedRaw = min(max(rawPitch, ARDataPitchRange.min), ARDataPitchRange.max)
        let normalized = (clampedRaw - ARDataPitchRange.min) / (ARDataPitchRange.max - ARDataPitchRange.min)
        let validNotes = nearestNoteTable.filter { $0 >= lowestNote && $0 <= highestNote }
        guard !validNotes.isEmpty else { return lowestNote }
        let index = Int(round(normalized * Float(validNotes.count - 1)))
        return validNotes[index]
    }
    
    
    func chordIntervals(for chordType: ChordType) -> [Int] {
        switch chordType {
        case .major:
            return [0, 4, 7] // root, major third, perfect fifth
        case .minor:
            return [0, 3, 7] // root, minor third, perfect fifth
        case .dominant7:
            return [0, 4, 7, 10] // root, major third, perfect fifth, minor seventh
        case .diminished:
            return [0, 3, 6] // root, minor third, diminished fifth
        case .augmented:
            return [0, 4, 8] // root, major third, augmented fifth
        
        }
    }
    
    private func rebuildQuantization(withScaleClasses scaleClasses: [Int], lowNote: Int = 0, highNote: Int = 127) {
        var result: [Int] = []
        for midiNote in lowNote...highNote {
            let pitchClass = midiNote % 12
            if scaleClasses.contains(pitchClass) {
                result.append(midiNote)
            }
        }
        self.nearestNoteTable = result
    }
    
    
}


    

extension MusicBrain {
    static func mask(fromPitchClasses classes: Set<Int>) -> UInt16 {
        return classes.reduce(0) { $0 | (1 << $1) }
    }
}

extension MusicBrain {
    static func pitchClasses(fromMask mask: UInt16) -> [Int] {
        var result: [Int] = []
        for i in 0..<12 {
            if (mask & (1 << i)) != 0 {
                result.append(i)
            }
        }
        return result
    }
}
