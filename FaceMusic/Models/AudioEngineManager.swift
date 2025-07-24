//
//  AudioEngineManager.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/23/25.
//

import AudioKit
import AVFoundation
import UIKit

var session: AVAudioSession {
    print("🔧 AVAudioSession initialized")
    return AVAudioSession.sharedInstance()
    
}

class AudioEngineManager {
    static let shared = AudioEngineManager()
    
    let engine = AudioEngine()
    private(set) var mixer: Mixer!
    private var addedFaderIDs = Set<ObjectIdentifier>()
    
    private init() {
    }
    
    func startEngine() {
        configureAVAudioSession()
        
        let desiredFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        
        mixer = Mixer()
        do {
            try mixer.avAudioNode.auAudioUnit.outputBusses[0].setFormat(desiredFormat)
        } catch {
            print("AudioEngineManager: ⚠️ Failed to set mixer output format: \(error)")
        }
        
        engine.output = mixer
        
        do {
            try engine.start()
            print("AudioEngineManager: AudioEngine started")
            //print(engine.avEngine)
            print("AudioEngineManager: 🔧 Mixer initialized with format: \(mixer.avAudioNode.outputFormat(forBus: 0))")
        } catch {
            Log("AudioEngineManager: AudioEngine start error: \(error)")
        }
        
        
        
        
        
    }
    
    private func configureAVAudioSession() {
        do {
            // detect device and do a rough and dirty buffer length change based on device age
            let model = UIDevice.current.modelIdentifier
            print("AudioEngineManager: Detected device: \(model)")
            
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
                        chosenBufferLength = .short  //RYAN: should make sure this is right
                    } else {
                        // Older iPhones
                        chosenBufferLength = .long
                    }
                }
            }
            
            Settings.bufferLength = chosenBufferLength
            
            print("AudioEngineManager: Selected buffer length: \(Settings.bufferLength)")
            
            Settings.sampleRate = 48_000
            Settings.audioFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2) ?? AVAudioFormat()

            
            
            
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(Settings.bufferLength.duration)
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                            options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setPreferredSampleRate(48000)
            try AVAudioSession.sharedInstance().setActive(true)
            
            print("AudioEngineManager: Hardware sample rate: \(AVAudioSession.sharedInstance().sampleRate)")
        } catch {
            print("AudioEngineManager: AVAudioSession configuration failed: \(error)")
        }
    }
    
    func stopEngine() {
        engine.stop()
    }
    
    func addToMixer(node: Node, caller: String = #function) {
        let nodeID = ObjectIdentifier(node)

        print("AudioEngineManager: 🎛 [Mixer] addInput called from \(caller). Node: \(node) [\(nodeID)]")

        /*
        print("AudioEngineManager: 🔬 [Mixer Debug] Current mixer connections:")
        for (index, input) in mixer.connections.enumerated() {
            print("AudioEngineManager: 🔗 [\(index)] \(input) [\(ObjectIdentifier(input))]")
        }
         */
        
        if addedFaderIDs.contains(nodeID) {
            print("AudioEngineManager: ⚠️ Node already connected: \(node)")
            return
        }

        mixer.addInput(node)
        addedFaderIDs.insert(nodeID)
    }

    func removeFromMixer(node: Node, caller: String = #function) {
        let nodeID = ObjectIdentifier(node)
        print("AudioEngineManager: 🧯 [Mixer] removeInput called from \(caller). Node: \(node).  Initial mixer state is:")
        logMixerState("removeFromMixer() - before removal")
        mixer.removeInput(node)
        addedFaderIDs.remove(nodeID)
        logMixerState("removeFromMixer() - after removal")
    }

    func removeAllInputsFromMixer(caller: String = #function) {
        print("AudioEngineManager: 🧯 [Mixer] removeAllInputsFromMixer called from \(caller). Initial mixer state is:")
        logMixerState("removeAllInputsFromMixer() - before removal")
        
        let connections = mixer.connections
        for node in connections {
            let nodeID = ObjectIdentifier(node)
            mixer.removeInput(node)
            addedFaderIDs.remove(nodeID)
        }

        logMixerState("removeAllInputsFromMixer() - after removal")
    }
    
    /// Logs the current mixer state for debugging.
    func logMixerState(_ context: String) {
        let connections = mixer.connections
        print("AudioEngineManager: 🔍 Mixer State (\(context)) — Total Inputs: \(connections.count)")
        for (index, input) in connections.enumerated() {
            print("AudioEngineManager: 🔗 [\(index)] \(input)")
        }
    }
    
}

