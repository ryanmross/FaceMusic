//
//  PatchManager.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//

import Foundation

/// Simple PatchSettings model to store user settings for each patch.
struct PatchSettings: Codable {
    var id: Int
    var name: String?
    
//    var lockChromatic: Bool
    
    var key: MusicBrain.NoteName
    var chordType: MusicBrain.ChordType
    
    var numOfVoices: Int
    //var vibrato: Bool
    //var alternateChords: [String]

    var glissandoSpeed: Float
    
    var lowestNote: Int
    var highestNote: Int
    
    var scaleMask: UInt16? // nil -> derive from chordType; non-nil -> custom scale membership
    
    var activeVoiceID: String
}

class PatchManager {
    
    static let shared = PatchManager()
    private let patchesKey = "SavedPatches"
    
    var defaultPatchSettings: PatchSettings {
        return PatchSettings.default()
    }
    
    // Computed property for current patch ID, stored in UserDefaults
    var currentPatchID: Int? {
        get {
            let val = UserDefaults.standard.object(forKey: "CurrentPatchID")
            if let intVal = val as? Int {
                return intVal
            }
            return nil
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "CurrentPatchID")
        }
    }
    
    /// Dictionary [ID: PatchSettings]
    private var patches: [Int: PatchSettings] = [:]
    
    private init() {
        loadFromStorage()
    }
    
    // Save or update a patch by ID
    func save(settings: PatchSettings, forID id: Int) {
        patches[id] = settings
        saveToStorage()
        currentPatchID = id
    }
    
    // Load a patch by ID
    func load(forID id: Int) -> PatchSettings? {
        print("PatchManager load \(id)")
        if let patch = patches[id] {
            return patch
        }
        return nil
    }
    
    // List all saved IDs
    func listPatches() -> [Int] {
        print("PatchManager listPatches.  currentPatchID is: \(currentPatchID as Any)")
        return Array(patches.keys).sorted()
    }
    
    // Delete a patch
    func deletePatch(forID id: Int) {
        patches.removeValue(forKey: id)
        saveToStorage()
        if patches.isEmpty {
            currentPatchID = nil
        } else {
            if let nextID = patches.keys.sorted().first {
                currentPatchID = nextID
                _ = load(forID: nextID)
            }
        }
    }
    
    /// Rename a patch by its ID
    func renamePatch(id: Int, newName: String) {
        guard var settings = patches[id] else { return }
        settings.name = newName
        patches[id] = settings
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
            id: 0,
            name: "Untitled Patch",
            key: .C,
            chordType: .major,
            numOfVoices: 1,
            glissandoSpeed: 50,
            lowestNote: 30,
            highestNote: 100,
            scaleMask: nil,
            activeVoiceID: "VocalTractConductor"
        )
    }
}

