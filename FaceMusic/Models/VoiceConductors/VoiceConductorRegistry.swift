//
//  VoiceConductorRegistry.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//


struct VoiceConductorDescriptor {
    let id: String
    let displayName: String
    let imageName: String
    let makeInstance: () -> VoiceConductorProtocol
    let defaultPatches: [PatchSettings]
}

struct VoiceConductorRegistry {
    static let all: [VoiceConductorDescriptor] = [
        VoiceConductorDescriptor(
            id: VocalTractConductor.id,
            displayName: VocalTractConductor.displayName,
            imageName: "vocaltract_icon",
            makeInstance: { VocalTractConductor() },
            defaultPatches: VocalTractConductor.defaultPatches
        ),
        VoiceConductorDescriptor(
            id: OscillatorConductor.id,
            displayName: OscillatorConductor.displayName,
            imageName: "oscillator_icon",
            makeInstance: { OscillatorConductor() },
            defaultPatches: OscillatorConductor.defaultPatches
        ),
        VoiceConductorDescriptor(
            id: VoiceHarmonizerConductor.id,
            displayName: VoiceHarmonizerConductor.displayName,
            imageName: "harmonizer_icon",
            makeInstance: { VoiceHarmonizerConductor() },
            defaultPatches: VoiceHarmonizerConductor.defaultPatches
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

    static var defaultDescriptor: VoiceConductorDescriptor {
        return all.first!
    }

    static var defaultID: String {
        return defaultDescriptor.id
    }

    static func conductorIndex(of id: String) -> Int? {
        return all.firstIndex { $0.id == id }
    }
    
    
    static func descriptor(containingPatchID patchID: String) -> VoiceConductorDescriptor? {
        guard let patchIDInt = Int(patchID) else { return nil }
        return all.first { descriptor in
            descriptor.defaultPatches.contains { $0.id == patchIDInt }
        }
    }
}
