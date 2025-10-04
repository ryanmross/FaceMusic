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
        // TEMPORARY WHILE WE WORK ON THE APP
        //deleteAllPatches()
        
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
    @discardableResult
    func save(settings: PatchSettings, forID: Int? = nil) -> Int {
        print("💾 PatchManager.save(settings:), id: \(settings.id)")
        
        var settingsToSave = settings
        let patchID = forID ?? (settingsToSave.id != 0 ? settingsToSave.id : generateNewPatchID())
        settingsToSave.id = patchID
        patches[patchID] = settingsToSave
        saveToStorage()
        //currentPatchID = patchID
        return patchID
    }
    
    /// Duplicate an existing patch (default or saved) and save it under a new ID with a new name.
/// - Parameters:
///   - sourceID: The ID of the patch to duplicate. Can be a default (negative) or saved (positive) ID.
///   - newName: The name to assign to the duplicated patch.
/// - Returns: The newly assigned patch ID, or nil if the source patch could not be found.
    @discardableResult
    func duplicatePatch(from sourceID: Int, as newName: String) -> Int? {
        print("💾 PatchManager.duplicatePatch(from: \(sourceID), as: \(newName)) called.")
        guard var base = getPatchData(forID: sourceID) else {
            print("⚠️ PatchManager.duplicatePatch - Source patch not found for ID: \(sourceID)")
            return nil
        }
        // Force a new ID and assign the requested name
        base.id = 0
        base.name = newName
        let newID = save(settings: base)
        print("💾 PatchManager.duplicatePatch - Duplicated patch from \(sourceID) to new ID: \(newID)")
        return newID
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
        //print("📥 PatchManager.getPatchData(\(id)) called.")
        if let patch = patches[id] {
            print("📥 PatchManager.getPatchData(\(id)) found in saved patches. \(String(describing: patch.name))")
            return patch
        }
        // If not saved and this is a default patch ID, return the default definition from the registry
        if id < 0, let defaultPatch = defaultPatch(forID: id) {
            print("📥 PatchManager.getPatchData(\(id)) returning default patch from registry.")
            return defaultPatch
        }
        print("📥 PatchManager.getPatchData(\(id)) not found.")
        return nil
    }
    
    /// Lookup a default patch definition by ID from the VoiceConductorRegistry
    private func defaultPatch(forID id: Int) -> PatchSettings? {
        let defaults = VoiceConductorRegistry.all.flatMap { $0.defaultPatches }
        return defaults.first(where: { $0.id == id })
    }
    
    // List all saved IDs
    func listPatches() -> [Int] {
        print("📥 PatchManager: listPatches() called.  \(patches.keys.count) saved patches.")
        return Array(patches.keys).sorted()
    }
    
    /// Sorted list of saved (custom) patch IDs
    private func savedPatchIDsSorted() -> [Int] {
        patches.keys.filter { $0 > 0 }.sorted()
    }
    
    // Delete a patch
    func deletePatch(forID id: Int) {
        let wasCurrent = (currentPatchID == id)
        let savedIDsBefore = savedPatchIDsSorted()
        let deletedIndex = savedIDsBefore.firstIndex(of: id)

        // Perform deletion and persist
        patches.removeValue(forKey: id)
        saveToStorage()

        // If nothing left at all, clear current selection
        guard !patches.isEmpty else { currentPatchID = nil; return }

        // Only adjust selection if we deleted the currently selected custom patch
        guard wasCurrent, id > 0 else { return }

        let savedIDsAfter = savedPatchIDsSorted()
        guard !savedIDsAfter.isEmpty else { currentPatchID = nil; return }

        // Prefer the item that slid into the deleted index; otherwise the new last
        if let idx = deletedIndex {
            currentPatchID = (idx < savedIDsAfter.count) ? savedIDsAfter[idx] : savedIDsAfter.last
            return
        }

        // Fallback: closest by value (next greater, otherwise last smaller)
        currentPatchID = savedIDsAfter.first(where: { $0 > id }) ?? savedIDsAfter.last
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
        saveToStorage()
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
    
    // Generate a new unique ID (increments highest existing positive ID)
    func generateNewPatchID() -> Int {
        let newID = (patches.keys.filter { $0 > 0 }.max() ?? 0) + 1
        print("💾 PatchManager.generatedNewPatchID(): Generating new ID: \(newID)")
        return newID
    }
    
    /// ⚠️ TEMPORARY: Deletes all saved patches on app launch.
    private func deleteAllPatches() {
        print("⚠️ TEMPORARY: Deleting all saved patches on init.")
        patches.removeAll()
        saveToStorage()
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

    
