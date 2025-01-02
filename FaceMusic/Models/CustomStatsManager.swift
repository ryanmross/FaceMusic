import UIKit
import ARKit


class CustomStatsManager {
    
    private let statsContainerView: UIView
    private let toggleButton: UIButton
    private let statsLabel: UILabel
    private var isExpanded = false
    
    var statsContainerHeightConstraint: NSLayoutConstraint!
    
    init(sceneView: ARSCNView) {
        // Create stats container view
        statsContainerView = UIView()
        statsContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        statsContainerView.layer.cornerRadius = 8
        statsContainerView.clipsToBounds = true
        statsContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set the initial height constraint for statsContainerView
        statsContainerHeightConstraint = statsContainerView.heightAnchor.constraint(equalToConstant: 40)
        statsContainerHeightConstraint.isActive = true

        // Create stats label
        statsLabel = UILabel()
        statsLabel.numberOfLines = 0
        statsLabel.textColor = .white
        statsLabel.font = UIFont(name: "Courier", size: 9)
        statsLabel.text = "loading face tracking stats..."
        statsLabel.isHidden = true
        statsLabel.translatesAutoresizingMaskIntoConstraints = false

        // Create toggle button
        toggleButton = UIButton()
        toggleButton.setTitle("+ Face Tracking Data", for: .normal)
        toggleButton.titleLabel?.font = UIFont(name: "Courier", size: 9)
        toggleButton.contentHorizontalAlignment = .left
        toggleButton.setTitleColor(.white, for: .normal)
        toggleButton.addTarget(self, action: #selector(toggleStatsVisibility), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        

        // Add subviews to stats container
        statsContainerView.addSubview(toggleButton)
        statsContainerView.addSubview(statsLabel)

        // Add the stats container to the scene view
        sceneView.addSubview(statsContainerView)

        // Set up constraints
        NSLayoutConstraint.activate([
            statsContainerView.leadingAnchor.constraint(equalTo: sceneView.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            statsContainerView.trailingAnchor.constraint(equalTo: sceneView.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            statsContainerView.topAnchor.constraint(equalTo: sceneView.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            // Constraints for toggleButton
            toggleButton.topAnchor.constraint(equalTo: statsContainerView.topAnchor, constant: 5),
            toggleButton.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor, constant: 10),
            toggleButton.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor, constant: -10), // Allow button to expand horizontally
            toggleButton.heightAnchor.constraint(equalToConstant: 30),

            // Constraints for statsLabel
            statsLabel.topAnchor.constraint(equalTo: toggleButton.bottomAnchor, constant: 5),
            statsLabel.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor, constant: 10),
            statsLabel.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor, constant: -10),
            statsLabel.bottomAnchor.constraint(equalTo: statsContainerView.bottomAnchor, constant: -5)
        ])
    }

    
    @objc private func toggleStatsVisibility() {
        isExpanded.toggle()

        UIView.animate(withDuration: 0.3) {
            if self.isExpanded {
                self.toggleButton.setTitle("- Face Tracking Data", for: .normal)
                self.statsLabel.isHidden = false
                self.statsLabel.sizeToFit()
                self.statsLabel.frame.size.height = 100
                self.statsContainerHeightConstraint.constant = self.statsLabel.frame.origin.y + self.statsLabel.frame.height + 10
            } else {
                self.toggleButton.setTitle("+ Face Tracking Data", for: .normal)
                self.statsLabel.isHidden = true
                self.statsLabel.frame.size.height = 0
                self.statsContainerHeightConstraint.constant = self.toggleButton.frame.height + 10
            }
        }
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
            self.statsLabel.text = "\(statsText) \nhorizPosition: \(faceData.horizPosition) \nvertPosition:  \(faceData.vertPosition)"
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
