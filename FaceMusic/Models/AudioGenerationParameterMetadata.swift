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
    case mouthClose
    case mouthFunnel

    // THIS IS WHERE WE CAN TWEAK THE INTERPOLATION OF FACE DATA
    var metadata: AudioGenerationParameterMetadata {
        switch self {
        case .pitch:
            return AudioGenerationParameterMetadata(fromLower: -1.0, fromUpper: 0.4, toLower: 30.0, toUpper: 70.0)
        case .jawOpen:
            return AudioGenerationParameterMetadata(fromLower: 0.0, fromUpper: 1.0, toLower: 0.0, toUpper: 1.0)
        case .mouthClose:
            return AudioGenerationParameterMetadata(fromLower: 0.0, fromUpper: 1.0, toLower: 1.0, toUpper: 0.0)
        case .mouthFunnel:
            return AudioGenerationParameterMetadata(fromLower: 0.0, fromUpper: 1.0, toLower: 0.0, toUpper: 1.0)
        }
    }

    // Dynamically map to FaceData key paths
    var keyPath: KeyPath<FaceData, Float> {
        switch self {
        case .pitch: return \.pitch
        case .jawOpen: return \.jawOpen
        case .mouthClose: return \.mouthClose
        case .mouthFunnel: return \.mouthFunnel
        }
    }
}
