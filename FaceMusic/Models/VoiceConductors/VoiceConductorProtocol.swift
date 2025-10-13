//
//  VoiceConductorProtocol.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//

import Foundation
import AudioKit
import UIKit

enum AudioState {
    case stopped
    case waitingForFaceData
    case playing
}

protocol VoiceConductorProtocol: AnyObject {
    /// A unique string ID for storing and identifying this conductor (used in PatchSettings)
    static var id: String { get }
    
    static var version: Int { get }

    /// A human-readable name for UI menus and labels
    static var displayName: String { get }

    
    /// The default patches specific to this conductor
    static var defaultPatches: [PatchSettings] { get }
    
    var voicePitchLevel: VoicePitchLevel { get set }
    var noteRangeSize: NoteRangeSize { get set }

    var numOfVoices: Int { get set }
    var chordType: MusicBrain.ChordType { get set }
    
    var scaleMask: UInt16? { get set }
    
    var glissandoSpeed: Float { get set }
    
    /// The conductor's audio output node
    var outputNode: Node { get }

    /// Optional: Current audio state
    var audioState: AudioState { get set }
    
    /// Required initializer
    init()

    /// Apply settings from a patch
    func applySettings(_ settings: PatchSettings)

    /// Export current full patch settings
    func exportCurrentSettings() -> PatchSettings

    /// Apply only the conductor-specific fields from patch
    func applyConductorSpecificSettings(from patch: PatchSettings)

    /// Export only the conductor-specific fields to a patch
    func exportConductorSpecificSettings() -> [String: Any]?
    
    /// Generate UI views for conductor-specific settings
    func makeSettingsUI(target: Any?, valueChangedAction: Selector, touchUpAction: Selector) -> [UIView]
    
    /// Connect the conductor's nodes to the shared mixer
    func connectToMixer()

    /// Disconnect the conductor's nodes from the shared mixer
    func disconnectFromMixer()

    /// Update the conductor with face data
    func updateWithFaceData(_ data: FaceData)
    
    /// Update the voice count
    func updateVoiceCount()

    /// Return audio stats string
    func returnAudioStats() -> String

    /// Return music stats string
    func returnMusicStats() -> String

    /// Stop all active voices
    func stopAllVoices()

}

