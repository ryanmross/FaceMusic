//
//  PatchManager.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//

import Foundation
import AnyCodable
import UIKit

/// Simple PatchSettings model to store user settings for each patch.
struct PatchSettings: Codable {
    var id: Int
    var name: String?
    
    var key: MusicBrain.NoteName
    var chordType: MusicBrain.ChordType
    
    var numOfVoices: Int
    var glissandoSpeed: Float
    
    var voicePitchLevel: VoicePitchLevel
    var noteRangeSize: NoteRangeSize
    
    var scaleMask: UInt16? // nil -> derive from chordType; non-nil -> custom scale membership
    
    var version: Int
    var conductorID: String
    
    var imageName: String? // optional because this comes from the voice conductor and so for user saved patches it will be empty and default to the conductor's image

    
    
    var conductorSpecificSettings: [String: AnyCodable]?
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
            if let stored = UserDefaults.standard.object(forKey: "currentPatchID") as? Int {
                print("📥 PatchManager.currentPatchID get. 💾 Loaded (\(stored)) from UserDefaults.currentPatchID")
                return stored
            }
            return nil
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id, forKey: "currentPatchID")
                print("📥 PatchManager.currentPatchID set. 💾 Saved (\(id)) to UserDefaults.currentPatchID ")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentPatchID")
                print("📥 PatchManager.currentPatchID set. 🧹 Removed currentPatchID from UserDefaults")
            }
        }
    }
    
    /// Dictionary [ID: PatchSettings]
    private var patches: [Int: PatchSettings] = [:]
    
    private init() {
        print("📥 PatchManager.init. Calling loadFromStorage()")
        loadFromStorage() // loading from storage on app start
        
        // removed this as currentPatchID does this in the getter
//        if let storedID = UserDefaults.standard.object(forKey: "currentPatchID") as? Int {
//            currentPatchID = storedID
//            print("📥 PatchManager.init. Restored currentPatchID from UserDefaults: \(storedID)")
//
//        } else {
//            print("⚠️ PatchManager.init. No currentPatchID found in UserDefaults — may be first launch or unset.")
//        }
    }
    
    /// Save or update a patch, optionally specifying an ID. If no ID is given and the settings' ID is 0, a new ID is generated.
    func save(settings: PatchSettings, forID: Int? = nil) {
        print("💾 PatchManager.save(settings:), id: \(settings.id)")
        
        var settingsToSave = settings
        let patchID = forID ?? (settingsToSave.id != 0 ? settingsToSave.id : generateNewPatchID())
        settingsToSave.id = patchID
        patches[patchID] = settingsToSave
        saveToStorage()
        //currentPatchID = patchID
    }
    
    // Migrate a patch to fix old/invalid VoiceConductor IDs, etc.
//    private func migratePatch(_ patch: inout PatchSettings) {
//        let validIDs = VoiceConductorRegistry.voiceConductorIDs
//        if !validIDs().contains(patch.conductorID) {
//            print("⚠️ Invalid VoiceConductor ID '\(patch.conductorID)' found. Resetting to default.")
//            patch.conductorID = VoiceConductorRegistry.defaultID
//        }
//    }

    // Load a patch by ID
    func getPatchData(forID id: Int) -> PatchSettings? {
        print("📥 PatchManager.getPatchData(\(id)) called.")
        if let patch = patches[id] {
            //migratePatch(&patch)
            return patch
        }
        return nil
    }
    
    // List all saved IDs
    func listPatches() -> [Int] {
        print("📥 PatchManager: listPatches() called.  \(patches.keys.count) saved patches.")
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
                _ = getPatchData(forID: nextID)
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
    
    func clearEditedDefaultPatch(forID id: Int) {
        patches.removeValue(forKey: id)
        print("🧹 PatchManager.clearEditedDefaultPatch.  Cleared patch ID \(id) from patches variable (we are not saving the default patch)")
    }


    
    // Load everything from UserDefaults
    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: patchesKey) else {
            print("📭 PatchManager.loadFromStorage().  No saved patch data found in UserDefaults for key: \(patchesKey)")
            return
        }
        if let decoded = try? JSONDecoder().decode([Int: PatchSettings].self, from: data) {
            patches = decoded
            
            logPatches(patches, label: "📥 PatchManager.loadFromStorage(). Loaded saved patch data from UserDefaults and put into PatchManager.patch variable")
        }
    }
    
    // Save everything to UserDefaults
    private func saveToStorage() {
        if let encoded = try? JSONEncoder().encode(patches) {
            logPatches(patches, label: "💾 PatchManager: saveToStorage")
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
            voicePitchLevel: .medium,
            noteRangeSize: .medium,
            scaleMask: nil,
            version: 1,
            conductorID: "VocalTractConductor"
        )
    }

    var displayName: String {
        name ?? (id < 0 ? "Default" : "Custom")
    }

    var image: UIImage {
        imageName.flatMap { UIImage(named: $0) } ?? UIImage()
    }

    var isDefault: Bool {
        id < 0
    }
}
