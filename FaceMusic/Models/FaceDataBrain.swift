import ARKit

enum VertDirection {
    case up
    case down
    case none
    
    func toString() -> String {
            switch self {
            case .none:
                return "None"
            case .up:
                return "Up"
            case .down:
                return "Down"
            }
        }
}

enum HorizDirection {
    case left
    case right
    case none
    
    func toString() -> String {
            switch self {
            case .none:
                return "None"
            case .left:
                return "Left"
            case .right:
                return "Right"
            }
        }
}

struct FaceData {
    var yaw: Float
    var pitch: Float
    var roll: Float
    var jawOpen: Float
    var mouthFunnel: Float
    var mouthClose: Float
    var vertPosition: VertDirection
    var horizPosition: HorizDirection
}

class FaceDataBrain {
    func processFaceData(_ faceAnchor: ARFaceAnchor) -> FaceData {
        // Extract yaw, pitch, roll
        let (yaw, pitch, roll) = faceAnchor.transform.extractYawPitchRoll()
        
        // Extract jaw, mouth funnel, and mouth close blend shapes
        let jawOpen = Float(faceAnchor.blendShapes[.jawOpen]?.doubleValue ?? 0.0)
        let mouthFunnel = Float(faceAnchor.blendShapes[.mouthFunnel]?.doubleValue ?? 0.0)
        let mouthClose = Float(faceAnchor.blendShapes[.mouthClose]?.doubleValue ?? 0.0)
        
        // Interpret vertical and horizontal directions
        let upperLimit: Float = 0.06
        let lowerLimit: Float = -0.4
        let rightLimit: Float = -0.30
        let leftLimit: Float = 0.30
        
        var vertPosition: VertDirection = .none
        var horizPosition: HorizDirection = .none
        
        if pitch >= upperLimit {
            vertPosition = .up
        } else if pitch <= lowerLimit {
            vertPosition = .down
        }
        
        if yaw <= rightLimit {
            horizPosition = .right
        } else if yaw >= leftLimit {
            horizPosition = .left
        }
        
        return FaceData(
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            jawOpen: jawOpen,
            mouthFunnel: mouthFunnel,
            mouthClose: mouthClose,
            vertPosition: vertPosition,
            horizPosition: horizPosition
        )
    }
}
