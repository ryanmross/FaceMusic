/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Convenience extensions for system types.
*/

import ARKit
import SceneKit


extension SCNMatrix4 {
    /**
     Create a 4x4 matrix from CGAffineTransform, which represents a 3x3 matrix
     but stores only the 6 elements needed for 2D affine transformations.
     
     [ a  b  0 ]     [ a  b  0  0 ]
     [ c  d  0 ]  -> [ c  d  0  0 ]
     [ tx ty 1 ]     [ 0  0  1  0 ]
     .               [ tx ty 0  1 ]
             
     Used for transforming texture coordinates in the shader modifier.
     (Needs to be SCNMatrix4, not SIMD float4x4, for passing to shader modifier via KVC.)
     */
    init(_ affineTransform: CGAffineTransform) {
        self.init()
        m11 = Float(affineTransform.a)
        m12 = Float(affineTransform.b)
        m21 = Float(affineTransform.c)
        m22 = Float(affineTransform.d)
        m41 = Float(affineTransform.tx)
        m42 = Float(affineTransform.ty)
        m33 = 1
        m44 = 1
    }
}



extension SCNReferenceNode {
    convenience init(named resourceName: String, loadImmediately: Bool = true) {
        let url = Bundle.main.url(forResource: resourceName, withExtension: "scn", subdirectory: "Models.scnassets")!
        self.init(url: url)!
        if loadImmediately {
            self.load()
        }
    }
}

extension SCNMaterial {
    static func materialWithColor(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        return material
    }
}

extension UUID {
    /**
    Pseudo-randomly return one of the 14 fixed standard colors, based on this UUID.
    */
    func toRandomColor() -> UIColor {
        let colors: [UIColor] = [.red, .green, .blue, .yellow, .magenta, .cyan, .purple,
                                 .orange, .brown, .lightGray, .gray, .darkGray, .black, .white]
        let randomNumber = abs(self.hashValue % colors.count)
        return colors[randomNumber]
    }
}

extension FloatingPoint {
  /// Allows mapping between reverse ranges, which are illegal to construct (e.g. `10..<0`).
  func interpolated(
    fromLowerBound: Self,
    fromUpperBound: Self,
    toLowerBound: Self,
    toUpperBound: Self) -> Self
  {
    let positionInRange = (self - fromLowerBound) / (fromUpperBound - fromLowerBound)
    return (positionInRange * (toUpperBound - toLowerBound)) + toLowerBound
  }

  func interpolated(from: ClosedRange<Self>, to: ClosedRange<Self>) -> Self {
    interpolated(
      fromLowerBound: from.lowerBound,
      fromUpperBound: from.upperBound,
      toLowerBound: to.lowerBound,
      toUpperBound: to.upperBound)
  }
}


func printTimestamp() {
    let now = Date()
    let timestamp = now.timeIntervalSince1970
    let milliseconds = Int(timestamp * 1000)
    print(milliseconds)
}


extension matrix_float4x4 {
    func extractYawPitchRoll() -> (yaw: Float, pitch: Float, roll: Float) {
        let roll = atan2(self[1][0], self[0][0])
        let pitch = atan2(self[2][1], self[2][2])
        let yaw = atan2(-self[2][0], sqrt(self[2][1] * self[2][1] + self[2][2] * self[2][2]))
        return (yaw, pitch, roll)
    }
}

func shiftArray<T>(_ array: [T], by positions: Int) -> [T] {
    let count = array.count
    guard count > 0 else {
        return array // If the array is empty, return as is
    }

    // Normalize the shift to handle large shifts or negative values
    let normalizedPositions = ((positions % count) + count) % count
    
    // Slice the array and shift
    let firstPart = array.suffix(from: normalizedPositions)
    let secondPart = array.prefix(normalizedPositions)

    return Array(firstPart) + Array(secondPart)
}


func midiNoteToFrequency(_ midiNote: Int) -> Float {
    return Float(440.0 * pow(2.0, (Float(midiNote) - 69.0) / 12.0))
}


func FloatValue(from any: Any) -> Float? {
    if let f = any as? Float { return f }
    if let d = any as? Double { return Float(d) }
    if let i = any as? Int { return Float(i) }
    return nil
}


// MARK: - Patch Logging
/// Print a readable summary of one or more PatchSettings objects.
func logPatches(_ patchInput: Any, label: String = "📦 Patch Summary") {
    
    let patches: [PatchSettings]

    if let dict = patchInput as? [Int: PatchSettings] {
        patches = dict.values.sorted { $0.id < $1.id }
    } else if let array = patchInput as? [PatchSettings] {
        patches = array.sorted { $0.id < $1.id }
    } else if let single = patchInput as? PatchSettings {
        patches = [single]
    } else {
        print("⚠️ logPatches: Unsupported input type")
        return
    }

    print("\(label):")

    let columnWidths: [String: Int] = [
        "ID": 5,
        "Name": 16,
        "Conductor": 16,
        "Key": 4,
        "Chord": 7,
        "Voices": 7,
        "Gliss": 6,
        "Pitch": 5,          // was 9
        "Range": 7,
        "ScaleMask": 10,
        "Image": 11,
        "Version": 4,        // was 7
        "Settings": 30       // was 15
    ]

    func pad(_ text: String, to column: String) -> String {
        let width = columnWidths[column] ?? text.count
        return text.padding(toLength: width, withPad: " ", startingAt: 0)
    }

    let headers = [
        pad("ID", to: "ID"),
        pad("Name", to: "Name"),
        pad("Conductor", to: "Conductor"),
        pad("Key", to: "Key"),
        pad("Chord", to: "Chord"),
        pad("Voices", to: "Voices"),
        pad("Gliss", to: "Gliss"),
        pad("Pitch", to: "Pitch"),
        pad("Range", to: "Range"),
        pad("ScaleMask", to: "ScaleMask"),
        pad("Image", to: "Image"),
        pad("Vers", to: "Version"),
        pad("Settings", to: "Settings")
    ].joined(separator: " | ")

    print(headers)
    print(String(repeating: "-", count: headers.count))

    for patch in patches {
        let row = [
            pad("\(patch.id)", to: "ID"),
            pad(patch.name ?? "Unnamed", to: "Name"),
            pad(patch.conductorID, to: "Conductor"),
            pad(patch.key.displayName, to: "Key"),
            pad(patch.chordType.rawValue, to: "Chord"),
            pad("\(patch.numOfVoices)", to: "Voices"),
            pad(String(format: "%.1f", patch.glissandoSpeed), to: "Gliss"),
            pad("\(patch.voicePitchLevel)", to: "Pitch"),
            pad("\(patch.noteRangeSize)", to: "Range"),
            pad(patch.scaleMask.map { MusicBrain.pitchClasses(fromMask: $0).map(String.init).joined(separator: ",") } ?? "nil", to: "ScaleMask"),
            pad(patch.imageName ?? "nil", to: "Image"),
            pad("\(patch.version)", to: "Version"),
            pad(patch.conductorSpecificSettings.map { $0.map { "\($0.key)=\($0.value)" }.joined(separator: ",") } ?? "nil", to: "Settings")
        ].joined(separator: " | ")

        print(row)
    }
}
