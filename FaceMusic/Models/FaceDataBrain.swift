import os.log
import ARKit
import CoreML

enum VertDirection {
    case up
    case down
    case none
}

enum HorizDirection {
    case left
    case right
    case none
}

struct FaceData {
    // Orientation used for pitch/UX
    var yaw: Float
    var pitch: Float
    var roll: Float

    // Sound generation parameters (to feed the synth/VT filter)
    var jawOpen: Float          // 0..1
    var tonguePosition: Float   // 0..1
    var tongueDiameter: Float   // 0..1
    var lipOpen: Float          // 0..1

    // Interpreted directions for UI
    var vertPosition: VertDirection
    var horizPosition: HorizDirection
}

// NOTE: yaw/pitch/roll are kept for UI/UX logic but are intentionally EXCLUDED
// from the vowel classifier inputs to avoid confounding pose with vowel shape.
class FaceDataBrain {
    // MARK: - Vowel classifier runtime (internal)
    private var mlModel: MLModel? = nil
    private var featureOrder: [String] = [
        // Must match train_vowel_mlp.py when run with --features pucker_only
        "jawOpen","jawForward",
        "mouthSmile_Avg","mouthStretch_Avg",
        "mouthUpperUp_Avg","mouthLowerDown_Avg",
        "mouthPress_Avg","mouthDimple_Avg",
        "mouthClose","tongueOut",
        "mouthPucker"
    ]
    private var mean: [Double] = Array(repeating: 0, count: 11)
    private var std:  [Double] = Array(repeating: 1, count: 11)
    private var window: Int = 9  // default; will try to infer from model input shape
    private var ring: [[Double]] = [] // sliding window of feature vectors (most-recent last)

    // Unified source of truth for vowel labels and presets
    enum Vowel: String, CaseIterable {
        // Canonical IDs (IPA-ish where applicable)
        case i      = "i"   // beet (IY)
        case ih     = "ɪ"   // bit (IH)
        case eh     = "ɛ"   // bet (EH)
        case ae     = "æ"   // bat (AE)
        case aa     = "ɑ"   // spa (AA)
        case ao     = "ɔ"   // caught (AO)
        case uh     = "ʌ"   // cup (UH)
        case schwa  = "ə"   // a (article) — not produced by model, but available
        case ux     = "ʊ"   // book — not produced by model
        case u      = "u"   // boot (UW)
        case rr     = "RR"  // rhotic 'r'
        case none   = "NONE"

        // Map Core ML class labels -> canonical Vowel
        // These keys must match the model's probability dictionary keys exactly
        static let fromModelLabel: [String: Vowel] = [
            "IY": .i,
            "IH": .ih,
            "EH": .eh,
            "AE": .ae,
            "AA": .aa,
            "AO": .ao,
            "UH": .uh,
            "UW": .u,
            "RR": .rr,
            "NONE": .none
        ]

        // If you need to present a friendly symbol/string for UI
        var display: String {
            switch self {
            case .rr:   return "ɹ"     // friendly glyph for 'r'
            default:    return rawValue
            }
        }

        // Preset mapping from vowel -> vocal tract parameters (tp, td, lo)
        var preset: (Float, Float, Float) {
            switch self {
            case .i:     return (1.20, 0.07, 1.00)
            case .ih:    return (1.85, 0.06, 1.00)
            case .eh:    return (1.95, 0.24, 1.00)
            case .ae:    return (1.15, 0.59, 1.00)
            case .aa:    return (1.42, 0.72, 1.00)
            case .ao:    return (1.42, 0.80, 1.00)
            case .uh:    return (1.81, 0.74, 1.00)
            case .schwa: return (1.81, 0.71, 1.00)
            case .ux:    return (1.88, 0.75, 0.57)
            case .u:     return (1.95, 0.75, 0.49)
            case .rr:    return (0.71, 0.12, 0.64)
            case .none:  return (1.81, 0.71, 1.00)
            }
        }

        // The ordered list of model output class labels, for reference if needed
        static let modelClassOrder: [String] = ["AA","AE","AO","EH","IH","IY","RR","UH","UW","NONE"]
    }


    /// Loads the default vowel classifier model and normalization statistics from the app bundle.
    /// Model is searched for in `Models/VowelClassifier/` as either `.mlpackage` or `.mlmodelc`.
    /// Normalization stats are loaded from `norm_stats.json` within the same subfolder.
    init() {
        let bundle = Bundle.main
        let modelFolder = "Models/VowelClassifier"

        // Resolve model URL: prefer subdirectory, then fall back to bundle root
        let modelURL: URL? =
            bundle.url(forResource: "VowelMLP", withExtension: "mlpackage", subdirectory: modelFolder) ??
            bundle.url(forResource: "VowelMLP", withExtension: "mlmodelc", subdirectory: modelFolder) ??
            bundle.url(forResource: "VowelMLP", withExtension: "mlpackage") ??
            bundle.url(forResource: "VowelMLP", withExtension: "mlmodelc")

        // Resolve normalization stats URL: prefer subdirectory, then fall back to bundle root
        let normURL: URL? =
            bundle.url(forResource: "norm_stats", withExtension: "json", subdirectory: modelFolder) ??
            bundle.url(forResource: "norm_stats", withExtension: "json")

        self.loadModelIfNeeded(modelURL: modelURL, normURL: normURL)

        if self.mlModel != nil {
            print("🤯 FaceDataBrain: Loaded vowel classifier model. modelURL=\(String(describing: modelURL)), normURL=\(String(describing: normURL))")
        } else {
            print("🤯 FaceDataBrain: Failed to load vowel classifier model. modelURL=\(String(describing: modelURL)), normURL=\(String(describing: normURL))")
        }
    }



    func processFaceData(_ faceAnchor: ARFaceAnchor) -> FaceData {
        // Extract yaw, pitch, roll
        let (yaw, pitch, roll) = faceAnchor.transform.extractYawPitchRoll()

        // --- Raw blendshapes (internal) ---
        // Core for features expected by training (pucker_only)
        let jawOpen = faceAnchor.bs(.jawOpen)
        let jawForward = faceAnchor.bs(.jawForward)
        let mouthSmile_L = faceAnchor.bs(.mouthSmileLeft)
        let mouthSmile_R = faceAnchor.bs(.mouthSmileRight)
        let mouthStretch_L = faceAnchor.bs(.mouthStretchLeft)
        let mouthStretch_R = faceAnchor.bs(.mouthStretchRight)
        let mouthUpperUp_L = faceAnchor.bs(.mouthUpperUpLeft)
        let mouthUpperUp_R = faceAnchor.bs(.mouthUpperUpRight)
        let mouthLowerDown_L = faceAnchor.bs(.mouthLowerDownLeft)
        let mouthLowerDown_R = faceAnchor.bs(.mouthLowerDownRight)
        let mouthPress_L = faceAnchor.bs(.mouthPressLeft)
        let mouthPress_R = faceAnchor.bs(.mouthPressRight)
        let mouthDimple_L = faceAnchor.bs(.mouthDimpleLeft)
        let mouthDimple_R = faceAnchor.bs(.mouthDimpleRight)
        let mouthClose = faceAnchor.bs(.mouthClose)
        let tongueOut = faceAnchor.bs(.tongueOut)
        let mouthFunnel = faceAnchor.bs(.mouthFunnel)

        // Build feature vector in training order
        let mouthSmile_Avg   = 0.5 * Double(mouthSmile_L + mouthSmile_R)
        let mouthStretch_Avg = 0.5 * Double(mouthStretch_L + mouthStretch_R)
        let mouthUpperUp_Avg = 0.5 * Double(mouthUpperUp_L + mouthUpperUp_R)
        let mouthLowerDown_Avg = 0.5 * Double(mouthLowerDown_L + mouthLowerDown_R)
        let mouthPress_Avg   = 0.5 * Double(mouthPress_L + mouthPress_R)
        let mouthDimple_Avg  = 0.5 * Double(mouthDimple_L + mouthDimple_R)
        var x: [Double] = [
            Double(jawOpen),
            Double(jawForward),
            mouthSmile_Avg,
            mouthStretch_Avg,
            mouthUpperUp_Avg,
            mouthLowerDown_Avg,
            mouthPress_Avg,
            mouthDimple_Avg,
            Double(mouthClose),
            Double(tongueOut),
            Double(mouthFunnel)
        ]

        // Normalize with saved mean/std if available
        if mean.count == x.count && std.count == x.count {
            for i in 0..<x.count {
                if std[i] != 0 { x[i] = (x[i] - mean[i]) / std[i] }
            }
        }

        // --- Update ring buffer for TCN ---
        ring.append(x); if ring.count > window { ring.removeFirst() }

        // Predict vowel distribution if model is ready (requires full window)
        let probs = predictVowelProbs()
        //print("🤯 Predicting vowel — probs: \(probs)")
        // Log the top predicted vowel and its confidence
        if !probs.isEmpty {
            if let (bestLabel, bestProb) = probs.max(by: { $0.value < $1.value }) {
                let display = Vowel(rawValue: bestLabel)?.display ?? bestLabel
                print("🤯 Predicted vowel: \(display) (\(String(format: "%.2f", bestProb)))")
            } else {
                print("🤯 No vowel prediction available")
            }
        }

        // Map probs -> vocal tract parameters (soft blend of presets, ignore NONE)
        let (tp, td, lo, jawFromBlend) = blendVocalTractParams(from: probs, jawOpen: jawOpen)
        
        //print("🤯 blendVocalTractParams results: tp: \(tp), td: \(td), lo: \(lo)")
        
        // Interpret vertical and horizontal directions
        let upperLimit: Float = 0.06
        let lowerLimit: Float = -0.4
        let rightLimit: Float = -0.30
        let leftLimit: Float = 0.30
        var vertPosition: VertDirection = .none
        var horizPosition: HorizDirection = .none
        if pitch >= upperLimit { vertPosition = .up }
        else if pitch <= lowerLimit { vertPosition = .down }
        if yaw <= rightLimit { horizPosition = .right }
        else if yaw >= leftLimit { horizPosition = .left }

        
        //print("🤯 FaceData returned: yaw: \(yaw), pitch: \(pitch), roll: \(roll), jawOpen: \(jawOpen), tonguePosition: \(tp), tongueDiameter: \(td), lipOpen: \(lo), vertPosition: \(vertPosition), horizPosition: \(horizPosition)")
        
        return FaceData(
            yaw: yaw, pitch: pitch, roll: roll,
            jawOpen: jawFromBlend,
            tonguePosition: tp, tongueDiameter: td, lipOpen: lo,
            vertPosition: vertPosition, horizPosition: horizPosition
        )
    }

    // MARK: - Classifier I/O
    func loadModelIfNeeded(modelURL: URL?, normURL: URL?) {
        if mlModel == nil, let url = modelURL {
            mlModel = try? MLModel(contentsOf: url)
            if let m = mlModel,
               let desc = m.modelDescription.inputDescriptionsByName["seq"],
               let shape = desc.multiArrayConstraint?.shape,
               shape.count == 3 {
                // Expected shape is [1, T, F]
                let maybeT = shape[1].intValue
                if maybeT > 0 { self.window = maybeT }
            }
        }
        if let nurl = normURL,
           let data = try? Data(contentsOf: nurl),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any] {
            if let meanArr = json["mean"] as? [Double], let stdArr = json["std"] as? [Double] {
                self.mean = meanArr; self.std = stdArr
            }
            if let fo = json["feature_order"] as? [String] { self.featureOrder = fo }
        }
    }

    private func predictVowelProbs() -> [String: Double] {
        guard let model = mlModel, ring.count >= window else { return [:] }


        // pack as MLMultiArray of shape (1, T, F) as Float32 (matches model)
        let T = window, F = featureOrder.count
        guard let arr = try? MLMultiArray(shape: [1, NSNumber(value: T), NSNumber(value: F)], dataType: .float32) else { return [:] }

        // Fill (1,T,F) in time-major order
        for t in 0..<T {
            let row = ring[ring.count - T + t]
            for f in 0..<F {
                let idx = t*F + f
                arr[idx] = NSNumber(value: Float32(row[f]))
            }
        }

        // Build inputs for model name "seq"
        let provider = try? MLDictionaryFeatureProvider(dictionary: ["seq": MLFeatureValue(multiArray: arr)])

        // Run prediction with error visibility
        do {
            if let input = provider {
                let out = try model.prediction(from: input)

                // Try several common probability keys from Core ML conversions
                let candidateKeys = ["classLabelProbs", "classLabel_probs", "classProbability"]
                var found: [String: Double]? = nil
                for key in candidateKeys {
                    if let fv = out.featureValue(for: key) {
                        if let dict = fv.dictionaryValue as? [String: Double] {
                            found = dict
                            break
                        } else if let dictAny = fv.dictionaryValue as? [AnyHashable: NSNumber] {
                            var tmp: [String: Double] = [:]
                            for (k, v) in dictAny {
                                if let s = k as? String { tmp[s] = v.doubleValue }
                            }
                            found = tmp
                            break
                        }
                    }
                }
                if let probsDict = found {
                    // Convert model labels -> canonical vowel keys using Vowel.fromModelLabel
                    var canonical: [String: Double] = [:]
                    for (label, p) in probsDict {
                        if let v = Vowel.fromModelLabel[label] {
                            canonical[v.rawValue] = p
                        }
                    }
                    return canonical
                } else {
                    print("🤯 Model output missing probability dictionary. Available features: \(out.featureNames)")
                }
            } else {
                print("🤯 Failed to build MLDictionaryFeatureProvider for key 'seq'")
            }
        } catch {
            print("🤯 Model prediction threw error: \(error)")
        }
        return [:]
    }

    private func blendVocalTractParams(from probs: [String: Double], jawOpen: Float) -> (Float, Float, Float, Float) {
        // Accumulate weighted sums for tonguePosition (tp), tongueDiameter (td), and lipOpen (lo)

        var weightSum: Double = 0
        var tpSum: Double = 0
        var tdSum: Double = 0
        var loSum: Double = 0

        for (label, probability) in probs {
            guard probability > 0 else { continue }
            // Incoming keys are canonical vowel rawValues (from predictVowelProbs mapping)
            guard let vowel = Vowel(rawValue: label), vowel != .none else { continue }
            let (tp, td, lo) = vowel.preset
            tpSum += Double(tp) * probability
            tdSum += Double(td) * probability
            loSum += Double(lo) * probability
            weightSum += probability
        }

        // If we have no usable probability mass, fall back to a simple, deterministic heuristic
        guard weightSum > 1e-6 else {
            print("🤯 Using fallbackVocalTractParams (no matching labels or zero mass). probs: \(probs)")
            let fallback = fallbackVocalTractParams()
            return (fallback.0, fallback.1, fallback.2, jawOpen)
        }

        // Hook: jawOpen pass-through (no-op for now)
        // You can adjust tp/td/lo based on jawOpen here in the future, e.g.:
        // let adjustedLO = Float(min(1.0, max(0.0, Double(loSum / weightSum))))
        // let mix: Double = 0.0 // set between 0 and 1 to blend jawOpen into lip openness
        // let loBlended = Float((1 - mix) * Double(adjustedLO) + mix * Double(jawOpen))
        
        return (
            Float(tpSum / weightSum),
            Float(tdSum / weightSum),
            Float(loSum / weightSum),
            jawOpen
        )
    }

    // MARK: - Fallbacks & Utilities
    private func fallbackVocalTractParams() -> (Float, Float, Float) {
        // When the classifier provides no signal, derive lip openness from the last frame's jawOpen
        // and use neutral mid-values for tongue parameters.
        let last = ring.last ?? Array(repeating: 0.0, count: featureOrder.count)
        let jawOpenNorm = last.first ?? 0.0 // featureOrder[0] is jawOpen in our training layout
        let clampedLO = clamp01(jawOpenNorm)
        return (1.81, 0.71, Float(clampedLO))
    }

    @inline(__always)
    private func clamp01(_ x: Double) -> Double { min(1.0, max(0.0, x)) }
}


extension ARFaceAnchor {
    fileprivate func bs(_ loc: ARFaceAnchor.BlendShapeLocation) -> Float {
        return Float(self.blendShapes[loc]?.doubleValue ?? 0.0)
    }
}
