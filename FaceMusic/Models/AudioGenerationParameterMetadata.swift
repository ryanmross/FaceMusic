//
//  ParameterMetadata.swift
//  FaceMusic
//
//  Created by Ryan Ross on 1/5/25.
//


import Foundation

struct AudioGenerationParameterMetadata {
    var fromLower: Float
    var fromUpper: Float
    var toLower: Float
    var toUpper: Float
}

enum AudioGenerationParameter: String, CaseIterable {
    case pitch
    case jawOpen
    case lipOpen
    case tonguePosition
    case tongueDiameter

    // THIS IS WHERE WE CAN TWEAK THE INTERPOLATION OF FACE DATA
    var metadata: AudioGenerationParameterMetadata {
        switch self {
        case .pitch:
            // Map device pitch (radians-ish / normalized) to musical range; tune as desired
            return AudioGenerationParameterMetadata(fromLower: -1.0, fromUpper: 0.4, toLower: 30.0, toUpper: 70.0)
        case .jawOpen:
            // Raw AR blendshape / model-derived aperture 0..1
            return AudioGenerationParameterMetadata(fromLower: 0.0, fromUpper: 1.0, toLower: 0.0, toUpper: 1.0)
        case .lipOpen:
            // From FaceDataBrain’s VT mapping (0..1)
            return AudioGenerationParameterMetadata(fromLower: 0.0, fromUpper: 1.0, toLower: 0.0, toUpper: 1.0)
        case .tonguePosition:
            return AudioGenerationParameterMetadata(fromLower: 0.0, fromUpper: 1.0, toLower: 0.0, toUpper: 1.0)
        case .tongueDiameter:
            return AudioGenerationParameterMetadata(fromLower: 0.0, fromUpper: 1.0, toLower: 0.0, toUpper: 1.0)
        }
    }

    // Dynamically map to FaceData key paths (aligned with the slim FaceData used by the synth)
    var keyPath: KeyPath<FaceData, Float> {
        switch self {
        case .pitch: return \.pitch
        case .jawOpen: return \.jawOpen
        case .lipOpen: return \.lipOpen
        case .tonguePosition: return \.tonguePosition
        case .tongueDiameter: return \.tongueDiameter
        }
    }
}
