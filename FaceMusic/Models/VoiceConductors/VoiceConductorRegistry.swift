//
//  VoiceConductorRegistry.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//


struct VoiceConductorDescriptor {
    let id: String
    let displayName: String
    let makeInstance: () -> VoiceConductorProtocol
}

struct VoiceConductorRegistry {
    static let all: [VoiceConductorDescriptor] = [
        VoiceConductorDescriptor(
            id: VocalTractConductor.id,
            displayName: VocalTractConductor.displayName,
            makeInstance: { VocalTractConductor() }
        ),
        VoiceConductorDescriptor(
            id: OscillatorConductor.id,
            displayName: OscillatorConductor.displayName,
            makeInstance: { OscillatorConductor() }
        ),
        VoiceConductorDescriptor(
            id: VoiceHarmonizerConductor.id,
            displayName: VoiceHarmonizerConductor.displayName,
            makeInstance: { VoiceHarmonizerConductor() }
        )
        // Add additional conductors here
    ]

    static func displayNames() -> [String] {
        return all.map { $0.displayName }
    }

    static func voiceConductorIDs() -> [String] {
        return all.map { $0.id }
    }

    static func descriptor(for id: String) -> VoiceConductorDescriptor? {
        return all.first { $0.id == id }
    }

    static func descriptor(forDisplayName name: String) -> VoiceConductorDescriptor? {
        return all.first { $0.displayName == name }
    }

    static var defaultID: String {
        return defaultDescriptor.id
    }

    static var defaultDescriptor: VoiceConductorDescriptor {
        return all.first!
    }

    static func conductorIndex(of id: String) -> Int? {
        return all.firstIndex { $0.id == id }
    }
}
