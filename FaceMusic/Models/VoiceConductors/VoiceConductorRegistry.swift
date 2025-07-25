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
    
    static func conductorIndex(of type: VoiceConductorProtocol.Type) -> Int? {
        return allTypes.firstIndex { $0 == type }
    }
    static var defaultType: VoiceConductorProtocol.Type {
        return allTypes.first ?? VocalTractConductor.self
    }
}
