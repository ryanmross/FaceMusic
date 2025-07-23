//
//  AudioEngineManager.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/23/25.
//


import AudioKit
import AVFoundation
import UIKit

class AudioEngineManager {
    static let shared = AudioEngineManager()

    let engine = AudioEngine()
    private(set) var mixer = Mixer()

    private init() {
        engine.output = mixer
    }

    func startEngine() {
        configureAVAudioSession()
        do {
            try engine.start()
            print("AudioEngine started")
        } catch {
            Log("AudioEngine start error: \(error)")
        }
    }

    private func configureAVAudioSession() {
        do {
            // detect device and do a rough and dirty buffer length change based on device age
            let model = UIDevice.current.modelIdentifier
            print("Detected device: \(model)")

            // Default to medium buffer
            var chosenBufferLength: Settings.BufferLength = .medium

            if model.hasPrefix("iPhone") {
                let parts = model
                    .replacingOccurrences(of: "iPhone", with: "")
                    .split(separator: ",")

                if let majorString = parts.first,
                   let major = Int(majorString) {

                    if major >= 16 {
                        // iPhone 16 and newer
                        chosenBufferLength = .short
                    } else if major >= 13 {
                        // iPhone 13–15
                        chosenBufferLength = .medium
                    } else {
                        // Older iPhones
                        chosenBufferLength = .long
                    }
                }
            }

            Settings.bufferLength = chosenBufferLength
            print("Selected buffer length: \(Settings.bufferLength)")
            
            
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(Settings.bufferLength.duration)
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                            options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setPreferredSampleRate(48_000)
            try AVAudioSession.sharedInstance().setActive(true)
            print("Hardware sample rate: \(AVAudioSession.sharedInstance().sampleRate)")
        } catch {
            print("AVAudioSession configuration failed: \(error)")
        }
    }

    func stopEngine() {
        engine.stop()
    }

    func attach(node: Node) {
        mixer.addInput(node)
    }

    func detach(node: Node) {
        mixer.removeInput(node)
    }
}

    var session: AVAudioSession {
        return AVAudioSession.sharedInstance()
    }
