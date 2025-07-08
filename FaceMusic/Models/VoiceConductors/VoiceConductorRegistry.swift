//
//  VoiceConductorRegistry.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//


struct VoiceConductorRegistry {
    static let allTypes: [VoiceConductorProtocol.Type] = [
        VocalTractConductor.self,
        // SynthPadConductor.self,
        // GranularConductor.self
    ]
}