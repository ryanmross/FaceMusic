import UIKit

class FaceStatsManager: StatsWindowManager {
    

    private var faceData: FaceData?
    
    override func toggleStatsVisibility() {
        super.toggleStatsVisibility()
        
        
    }

    
    func updateFaceStats(with data: FaceData) {
        self.faceData = data
        let statsText = generateStatsText()
        DispatchQueue.main.async {
            self.statsLabel.text = statsText
        }
    }

    private func generateStatsText() -> String {
        guard let data = faceData else { return "No face data available." }
        
        let stats = [
            Stat(name: "Yaw", value: data.yaw, range: (-1.0, 1.0)),
            Stat(name: "Pitch", value: data.pitch, range: (-1.0, 1.0)),
            Stat(name: "Roll", value: data.roll, range: (-1.0, 1.0)),
            Stat(name: "Jaw Open", value: data.jawOpen, range: (0.0, 1.0)),
            Stat(name: "Mouth Funnel", value: data.mouthFunnel, range: (0.0, 1.0)),
            Stat(name: "Mouth Close", value: data.mouthClose, range: (0.0, 1.0))
        ]
        
        return stats.map { stat in
            let normalizedValue = normalizeValue(stat.value, min: stat.range.min, max: stat.range.max)
            let progressBar = generateProgressBar(from: normalizedValue)
            return "\(stat.name): [\(progressBar)] \(stat.value)"
        }.joined(separator: "\n")
    }
    
    private func normalizeValue(_ value: Float, min: Float, max: Float) -> Float {
        return (value - min) / (max - min)
    }
    
    private func generateProgressBar(from value: Float) -> String {
        let numBars = max(0, min(20, Int(value * 20)))  // Ensure numBars is between 0 and 20
        let bars = String(repeating: "|", count: numBars)
        let emptySpace = String(repeating: "-", count: 20 - numBars)
        return bars + emptySpace
    }
}


struct Stat {
    var name: String
    var value: Float
    var range: (min: Float, max: Float)
}
