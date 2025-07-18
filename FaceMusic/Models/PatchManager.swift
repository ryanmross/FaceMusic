//
//  PatchManager.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//

import Foundation

/// Simple PatchSettings model to store user settings for each patch.
/// Make sure this matches your actual PatchSettings definition.
struct PatchSettings: Codable {
    
    var name: String?
    
//    var lockChromatic: Bool
//    var basePitch: Float
//    var pitchRange: Int
    
    var key: MusicBrain.NoteName
    var chordType: MusicBrain.ChordType
    
    var numVoices: Int
    //var vibrato: Bool
    //var alternateChords: [String]

    //var glissandoSpeed: Float
    var activeVoiceID: String
}

class PatchManager {
    
    static let shared = PatchManager()
    private let patchesKey = "SavedPatches"
    
    /// Dictionary [ID: PatchSettings]
    private var patches: [Int: PatchSettings] = [:]
    
    private init() {
        loadFromStorage()
    }
    
    // Save or update a patch by ID
    func save(settings: PatchSettings, forID id: Int) {
        patches[id] = settings
        saveToStorage()
    }
    
    // Load a patch by ID
    func load(forID id: Int) -> PatchSettings? {
        return patches[id]
    }
    
    // List all saved IDs
    func listPatches() -> [Int] {
        return Array(patches.keys).sorted()
    }
    
    // Delete a patch
    func deletePatch(forID id: Int) {
        patches.removeValue(forKey: id)
        saveToStorage()
    }
    
    // Load everything from UserDefaults
    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: patchesKey) else { return }
        if let decoded = try? JSONDecoder().decode([Int: PatchSettings].self, from: data) {
            patches = decoded
        }
    }
    
    // Save everything to UserDefaults
    private func saveToStorage() {
        if let encoded = try? JSONEncoder().encode(patches) {
            UserDefaults.standard.set(encoded, forKey: patchesKey)
        }
    }
    
    // Generate a new unique ID (increments highest existing ID)
    func generateNewPatchID() -> Int {
        return (patches.keys.max() ?? 0) + 1
    }
    
}

extension PatchSettings {
    static func `default`() -> PatchSettings {
        return PatchSettings(
            name: "Untitled Patch",
            key: .C,
            chordType: .major,
            numVoices: 1,
            activeVoiceID: "VocalTractConductor"
        )
    }
}
