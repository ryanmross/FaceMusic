//
//  VoiceConductorRegistry.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//


struct VoiceConductorRegistry {
    static let allTypes: [VoiceConductorProtocol.Type] = [
        VocalTractConductor.self,
        AutoHarmonyConductor.self,
        // GranularConductor.self
    ]
    
    static func displayNames() -> [String] {
        return allTypes.map { $0.displayName }
    }

    static func voiceConductorIDs() -> [String] {
        return allTypes.map { $0.id }
    }

    static func type(for id: String) -> VoiceConductorProtocol.Type? {
        return allTypes.first { $0.id == id }
    }

    static func type(forDisplayName name: String) -> VoiceConductorProtocol.Type? {
        return allTypes.first { $0.displayName == name }
    }

    static var defaultID: String {
        return defaultType.id
    }
    
    static func conductorIndex(of type: VoiceConductorProtocol.Type) -> Int? {
        return allTypes.firstIndex { $0 == type }
    }
    static var defaultType: VoiceConductorProtocol.Type {
        return allTypes.first ?? VocalTractConductor.self
    }
}
