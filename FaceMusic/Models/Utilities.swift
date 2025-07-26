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
