//
//  VoiceConductorProtocol.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//

import Foundation
import AudioKit

enum AudioState {
    case stopped
    case waitingForFaceData
    case playing
}

protocol VoiceConductorProtocol: AnyObject {
    /// A unique identifier for this voice conductor
    static var id: String { get }

    /// A display name for UI
    static var displayName: String { get }

    var lowestNote: Int { get set }
    var highestNote: Int { get set }

    var numOfVoices: Int { get set }
    var chordType: MusicBrain.ChordType { get set }
    
    var glissandoSpeed: Float { get set }
    
    /// The conductor's audio output node
    var outputNode: Node { get }

    /// Optional: Current audio state
    var audioState: AudioState { get set }
    
    /// Required initializer
    init()

    /// Apply settings from a patch
    func applySettings(_ settings: PatchSettings)
    
    func exportCurrentSettings() -> PatchSettings


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


}
