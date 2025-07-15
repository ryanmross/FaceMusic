import Foundation


class AppSettings {

    // MARK: - Settings

    let defaultKey: MusicBrain.NoteName = .C
    let defaultChordType: MusicBrain.ChordType = .major
    
    
    // Define keys as an array of tuples
    let keyOptions: [(string: String, key: MusicBrain.NoteName)] = [
        ("C", .C), ("C#", .CSharp), ("D", .D), ("D#", .DSharp),
        ("E", .E), ("F", .F), ("F#", .FSharp), ("G", .G),
        ("G#", .GSharp), ("A", .A), ("A#", .ASharp), ("B", .B)
    ]

    // Define scales as an array of tuples
    /*
    let scales: [(string: String, scale: Scale, chordType: ChordType)] = [
        ("Major", .major, .major), ("Minor", .minor, .minor), ("Diminished", .wholeDiminished, .dim7), ("Half-Diminished", .halfDiminished, .halfDim7), ("Whole Tone", .leadingWholeTone, .aug)
    ]
    */
    
    let lowNoteThreshold: Int = 30 // Minimum MIDI note number to include non-root pitches
    
    // Define interpolation bounds for different parameters
    // Use the enum as the key
    var interpolationBounds: [ParametersForAudioGeneration: (fromLower: Float, fromUpper: Float, toLower: Float, toUpper: Float)] = [
        //.pitch: (-1.0, 0.4, 39.0, 120.0),
        .jawOpen: (0.0, 1.0, 0.0, 1.0),
        .mouthClose: (0.0, 1.0, 0.0, 1.0),
        .mouthFunnel: (0.0, 1.0, 0.0, 1.0)
    ]
    
    // Face Direction Limits
    static var upperLimit: Float = 0.06
    static var lowerLimit: Float = -0.5
    static var rightLimit: Float = -0.5
    static var leftLimit: Float = 0.30
}

enum ParametersForAudioGeneration: String, CaseIterable {
    case pitch
    case jawOpen
    case mouthClose
    case mouthFunnel
}
