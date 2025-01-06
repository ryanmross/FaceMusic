
import Foundation
import Tonic


class AppSettings {

    // MARK: - Settings

    var defaultKey: Key = Key.C
    
    // Define keys as an array of tuples (key, value)
    let keyOptions: [(key: String, value: NoteClass)] = [
       ("Cb", .Cb), ("Gb", .Gb), ("Db", .Db), ("Ab", .Ab), ("Eb", .Eb),
       ("Bb", .Bb), ("F", .F), ("C", .C), ("G", .G), ("D", .D),
       ("A", .A), ("E", .E), ("B", .B), ("F#", .Fs), ("C#", .Cs)
    ]

    // Define scales as an array of tuples (key, value)
    let scales: [(key: String, value: Scale)] = [
       ("Major", .major), ("Minor", .minor), ("Diminished", .wholeDiminished)
    ]
    
    
    // Define interpolation bounds for different parameters
    // Use the enum as the key
    var interpolationBounds: [ParametersForAudioGeneration: (fromLower: Float, fromUpper: Float, toLower: Float, toUpper: Float)] = [
        .pitch: (-1.0, 0.4, 35.0, 100.0),
        .jawOpen: (0.0, 1.0, 1.0, 0.0),
        .mouthClose: (0.0, 1.0, 0.0, 1.0),
        .mouthFunnel: (0.0, 1.0, 0.0, 1.0)
    ]
}

enum ParametersForAudioGeneration: String, CaseIterable {
    case pitch
    case jawOpen
    case mouthClose
    case mouthFunnel
}
