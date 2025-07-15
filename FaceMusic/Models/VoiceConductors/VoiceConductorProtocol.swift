//
//  VoiceConductorProtocol.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//

import Foundation

protocol VoiceConductorProtocol: AnyObject {
    /// A unique identifier for this voice conductor
    static var id: String { get }

    /// A display name for UI
    static var displayName: String { get }

    var lowestNote: Int { get set }
    var highestNote: Int { get set }
    //var scale: Scale { get set }
    var numOfVoices: Int { get set }
    var chordType: MusicBrain.ChordType { get set }
    
    /// Required initializer
    init()

    /// Apply settings from a patch
    func applySettings(_ settings: PatchSettings)

    /// Start the audio engine or playback
    func startEngine()

    /// Stop the audio engine or playback
    func stopEngine(immediate: Bool)

    /// Update the conductor with face data
    func updateWithFaceData(_ data: FaceData)

    /// Return audio stats string
    func returnAudioStats() -> String

    /// Return music stats string
    func returnMusicStats() -> String
}
