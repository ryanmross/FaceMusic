import UIKit
import ARKit


class CustomStatsManager {
    
    private var customStatsLabel: UILabel!
    private var sceneView: ARSCNView!
    
    init(sceneView: ARSCNView) {
        self.sceneView = sceneView
        createCustomStats()
    }

    func createCustomStats() {
        // Create and add a custom label
        customStatsLabel = UILabel()
        customStatsLabel.translatesAutoresizingMaskIntoConstraints = false
        customStatsLabel.textColor = .white
        customStatsLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        customStatsLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        customStatsLabel.text = "Custom Info: Loading..."
        customStatsLabel.numberOfLines = 0
        sceneView.addSubview(customStatsLabel)

        // Position the label at the top
        NSLayoutConstraint.activate([
           customStatsLabel.leadingAnchor.constraint(equalTo: sceneView.safeAreaLayoutGuide.leadingAnchor, constant: 10),
           customStatsLabel.trailingAnchor.constraint(lessThanOrEqualTo: sceneView.safeAreaLayoutGuide.trailingAnchor, constant: -10),
           customStatsLabel.topAnchor.constraint(equalTo: sceneView.safeAreaLayoutGuide.topAnchor, constant: 20),
//           customStatsLabel.heightAnchor.constraint(lessThanOrEqualToConstant: 100)
        ])
    }

    func updateFaceStats(with faceData: FaceData) {
        // Example stats array with data range
        let stats = [
            Stat(name: "Yaw", value: faceData.yaw, range: (-1.0, 1.0)),
            Stat(name: "Pitch", value: faceData.pitch, range: (-1.0, 1.0)),
            Stat(name: "Roll", value: faceData.roll, range: (-1.0, 1.0)),
            Stat(name: "Jaw Open", value: faceData.jawOpen, range: (0.0, 1.0)),
            Stat(name: "Mouth Funnel", value: faceData.mouthFunnel, range: (0.0, 1.0)),
            Stat(name: "Mouth Close", value: faceData.mouthClose, range: (0.0, 1.0))
        ]
        
        let maxNameLength = stats.map { $0.name.count }.max() ?? 0
        let maxBars = 20 // Number of '|' characters you want to display
        
        let statsText = stats.map { stat -> String in
            let normalizedValue = normalizeValue(stat.value, min: stat.range.min, max: stat.range.max)
            let progressBar = generateProgressBar(from: normalizedValue, totalBars: maxBars, minValue: stat.range.min, maxValue: stat.range.max)
            let paddedName = stat.name.padding(toLength: maxNameLength, withPad: " ", startingAt: 0)
            return "\(paddedName): [\(progressBar)] \(stat.value)"
        }.joined(separator: "\n")
        
        // Update the label with the new stats text
        DispatchQueue.main.async {
            self.customStatsLabel.text = "\(statsText) \nhorizPosition: \(faceData.horizPosition) \nvertPosition:  \(faceData.vertPosition)"
        }
    }

    private func normalizeValue(_ value: Float, min: Float, max: Float) -> Float {
        // Normalize the value based on its range (min to max) to be between 0 and 1
        return (value - min) / (max - min)
    }

    private func generateProgressBar(from value: Float, totalBars: Int, minValue: Float, maxValue: Float) -> String {
        // Ensure value is within the valid range
        let clampedValue = max(minValue, min(value, maxValue))
        let range = maxValue - minValue
        let numBars = max(0, min(totalBars, Int((clampedValue - minValue) / range * Float(totalBars)))) // Clamp numBars
        let bars = String(repeating: "|", count: numBars)
        let emptySpace = String(repeating: "-", count: totalBars - numBars) // Ensure count is non-negative
        return bars + emptySpace
    }
}

// MARK: - Stat Structure

struct Stat {
    var name: String
    var value: Float
    var range: (min: Float, max: Float)  // Range for each stat
}
