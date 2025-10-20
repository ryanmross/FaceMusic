import Foundation
import UIKit

// Heuristic device capability probe for voice limits
private struct DeviceCapability {
    static func suggestedMaxVoices() -> Int {
        let ramGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0 * 1024.0)
        let cores = ProcessInfo.processInfo.activeProcessorCount
        
        var suggested: Int
        switch ramGB {
        case 8...:         suggested = 8
        case 6..<8:        suggested = 7
        case 4..<6:        suggested = 6
        default:           suggested = 4
        }
        
        if cores <= 2 {
            suggested = min(suggested, 6)
        } else if cores <= 4 {
            suggested = min(suggested, 8)
        }
        
        // If the device is already thermally constrained, keep extra headroom.
        /*
        let therm = ProcessInfo.processInfo.thermalState
        if therm == .serious || therm == .critical {
            suggested = max(4, suggested - 2)
        }
         */
        
        // Clamp suggested to between 4 and 8
        suggested = max(4, min(suggested, 8))
        
        // Log once at launch for visibility
        let ramStr = String(format: "%.1f", ramGB)
        print("AppSettings: suggested max voices = \(suggested) (RAM=\(ramStr)GB cores=\(cores))")
        return suggested
    }
}

class AppSettings {

    // MARK: - Settings
  
    // Derived at launch based on device RAM/cores/thermal state
    //let maxNumOfVoices: Int = 128
    let maxNumOfVoices: Int = DeviceCapability.suggestedMaxVoices()
    
    let lowNoteThreshold: Int = 30 // Minimum MIDI note number to include non-root pitches

    // Chord grid layout configuration
    let chordGridRows: Int = 2    
    let chordGridCols: Int = 7
    
    // Define interpolation bounds for different parameters
    // Use the enum as the key
    var interpolationBounds: [ParametersForAudioGeneration: (fromLower: Float, fromUpper: Float, toLower: Float, toUpper: Float)] = [
        //.pitch: (-1.0, 0.4, 39.0, 120.0),
        .jawOpen: (0.0, 1.0, 0.0, 1.0),
        .mouthClose: (0.0, 1.0, 0.0, 1.0),
        .mouthFunnel: (0.0, 1.0, 0.0, 1.0)
    ]
    
}

enum ParametersForAudioGeneration: String, CaseIterable {
    case pitch
    case jawOpen
    case mouthClose
    case mouthFunnel
}


