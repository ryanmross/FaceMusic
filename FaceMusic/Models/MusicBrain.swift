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
        case halfDiminished
        case augmented
        
        // Add other chord types as needed
        
        var displayName: String {
            switch self {
            case .major: return "Major"
            case .minor: return "Minor"
            case .dominant7: return "Dominant 7"
            case .diminished: return "Diminished"
            case .halfDiminished: return "Half-Diminished"
            case .augmented: return "Augmented"
            }
        }
        var shortDisplayName: String {
            switch self {
            case .major: return ""
            case .minor: return "m"
            case .dominant7: return "7"
            case .diminished: return "°"
            case .halfDiminished: return "ø"
            case .augmented: return "+"
            }
        }
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
        case locrian

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
            case .locrian:
                return [0, 2, 3, 5, 6, 8, 10]
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
            case .halfDiminished:
                return .locrian
            case .augmented:
                return .wholeTone
            }
        }
    }
    
    // A provider that returns the latest detected raw facial pitch (in the same units as ARDataPitchRange expects).
    // Your AR session/update loop should set this to supply the most recent value.
    // Example usage elsewhere:
    // MusicBrain.currentRawPitchProvider = { latestARHeadPitch }
    static var currentRawPitchProvider: (() -> Float?) = { nil }
    
    private struct ARDataPitchRange {
        // Represents the mapping range for ARKit head rotation to pitch.
        // `center` is the neutral resting position. `span` is half the full range.
        // min = center - span, max = center + span
        var center: Float = -0.275 // initial neutral center between -1.0 and 0.45
        var span: Float = 0.725    // half of the default full range (approx (0.45 - (-1.0)) / 2)

        var minValue: Float { center - span }
        var maxValue: Float { center + span }

        mutating func set(center: Float, span: Float) {
            self.center = center
            self.span = Swift.max(0.001, span) // avoid zero/negative span
        }

        mutating func recenter(to newCenter: Float) {
            self.center = newCenter
        }

        mutating func calibrateCenter(from rawPitch: Float) {
            // Set the neutral center to the provided raw pitch value
            self.center = rawPitch
        }
        
        /// Recenters to the current facial pitch using the shared provider, if available.
        /// If no provider is set or it returns nil, this is a no-op.
        mutating func recenterFromCurrentFacePitch() {
            
            Log.line(actor: "🧠 MusicBrain", fn: "recenterFromCurrentFacePitch", "ARDataPitchRange.recenterFromCurrentFacePitch called")

            let provider = MusicBrain.currentRawPitchProvider
            if let pitch = provider() {
                self.center = pitch
            }
        }
    }
    

    // Current key and scale state
    private(set) var currentKey: NoteName
    private(set) var currentScale: ScaleType
    private(set) var currentChordType: ChordType = .major
    
    private(set) var customScaleMask: UInt16? // nil = no override
    private var arPitchRange = ARDataPitchRange()
    
    var currentScalePitchClasses: [Int] {
        if let mask = customScaleMask {
            return Self.pitchClasses(fromMask: mask)
        } else {
            return currentScale.intervals.map { ($0 + currentKey.rawValue) % 12 }
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
        //updateKeyAndScale(key: key, chordType: .major)
    }
    
    static func pitchClasses(fromMask mask: UInt16) -> [Int] {
        var result: [Int] = []
        for i in 0..<12 {
            if (mask & (1 << i)) != 0 {
                result.append(i)
            }
        }
        return result
    }
    
    static func mask(fromPitchClasses classes: Set<Int>) -> UInt16 {
        return classes.reduce(0) { $0 | (1 << $1) }
    }

    func scaleMaskFromCurrentPitchClasses() -> UInt16 {
        return UInt16(currentScalePitchClasses.reduce(0) { $0 | (1 << ($1 % 12)) })
    }

    
    func updateKeyAndScale(key: NoteName, chordType: ChordType, scaleMask: UInt16? = nil) {
        self.currentKey = key
        self.currentChordType = chordType
        self.customScaleMask = scaleMask

        if let mask = scaleMask {
            // if scaleMask contains a custom scale
            
            let scaleNotes = Self.pitchClasses(fromMask: mask)
            
            Log.line(actor: "🧠 MusicBrain", fn: "updateKeyAndScale", "Using custom scale mask: \(scaleNotes).  Calling rebuildQuantization(\(scaleNotes))")

            rebuildQuantization(withScaleClasses: scaleNotes)
        } else {
            // if scaleMask is nil and we want to use default key and scale
            
            let scale = ScaleType.scaleForChordType(chordType)
            self.currentScale = scale
            
            Log.line(actor: "🧠 MusicBrain", fn: "updateKeyAndScale", "Using default scale \(scale).  Calling rebuildQuantization(\(scale.intervals.map { ($0 + key.rawValue) % 12 })")

            rebuildQuantization(withScaleClasses: scale.intervals.map { ($0 + key.rawValue) % 12 })
        }
    }

    // Return the nearest quantized note for a given raw pitch float
    func nearestQuantizedNote(
        rawPitch: Float,
        lowestNote: Int,
        highestNote: Int
    ) -> Int {
        let clampedRaw = Swift.min(Swift.max(rawPitch, arPitchRange.minValue), arPitchRange.maxValue)
        let normalized = (clampedRaw - arPitchRange.minValue) / (arPitchRange.maxValue - arPitchRange.minValue)
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
        case .halfDiminished:
            return [0, 3, 6, 10] // root, minor third, diminished fifth, minor seventh
        case .augmented:
            return [0, 4, 8] // root, major third, augmented fifth
        
        }
    }
    
    func rebuildQuantization(withScaleClasses scaleClasses: [Int]) {
        
        Log.line(actor: "🧠 MusicBrain", fn: "rebuildQuantization", "recieved scaleClasses: \(scaleClasses)")

        var result: [Int] = []
        for midiNote in 0...127 where scaleClasses.contains(midiNote % 12) {
            result.append(midiNote)
        }
        self.nearestNoteTable = result
    }
    
    /// Toggle the presence of a pitch class in the custom scale mask.
    func togglePitchClass(_ pitchClass: Int) {
        var current = Set(currentScalePitchClasses)
        if current.contains(pitchClass) {
            current.remove(pitchClass)
        } else {
            current.insert(pitchClass)
        }
        let mask = MusicBrain.mask(fromPitchClasses: current)
        self.customScaleMask = mask
        rebuildQuantization(withScaleClasses: Array(current))
    }

    /// Clear any custom scale mask and revert to the current key and scale.
    func clearCustomScale() {
        self.customScaleMask = nil
        updateKeyAndScale(key: currentKey, chordType: currentChordType)
    }
    
    /// Call this when only the voice pitch or range changes,
    /// and you want to rebuild quantization without resetting key/scale/mask.
    func updateVoicePitchOrRangeOnly() {
        // This is a placeholder for logic that reacts to voice pitch/range changes
        // without resetting the customScaleMask or currentKey/Scale
        rebuildQuantization(withScaleClasses: currentScalePitchClasses)
    }

    /// Set the pitch mapping range by specifying a new center and span (half-range).
    /// - Parameters:
    ///   - center: The neutral resting raw pitch value.
    ///   - span: Half of the full range around the center. Full range = 2*span.
    func setPitchRange(center: Float, span: Float) {
        arPitchRange.set(center: center, span: span)
    }

    /// Recenter the pitch mapping while preserving the current span.
    func recenterPitchRange(to center: Float) {
        arPitchRange.recenter(to: center)
    }

    /// Convenience: recenter the pitch mapping using the current facial pitch, if available.
    func recenterPitchRangeFromCurrentFacePitch() {
        arPitchRange.recenterFromCurrentFacePitch()
    }

    /// Calibrate the neutral center from a sampled raw pitch value (e.g., current head pose).
    func calibrateCenterFrom(rawPitch: Float) {
        arPitchRange.calibrateCenter(from: rawPitch)
    }
    
    /// Generates an array of NoteNames centered on the given key and ordered by the circle of fifths.
    /// The count parameter determines the number of notes (must be > 0).
    static func circleOfFifthsWindow(center: NoteName, count: Int) -> [NoteName] {
        guard count > 0 else { return [] }
        let half = count / 2
        let start = -half
        let end = start + count
        return (start..<end).map { step in
            let raw = center.rawValue + (7 * step)
            let noteValue = ((raw % 12) + 12) % 12
            guard let note = NoteName(rawValue: noteValue) else {
                // Fallback: this should never happen, but return a sensible default
                return .C
            }
            return note
        }
    }
}

    








