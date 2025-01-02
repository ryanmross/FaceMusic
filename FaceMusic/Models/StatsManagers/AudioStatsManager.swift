import UIKit

class AudioStatsManager: StatsWindowManager {
    
    
    override func toggleStatsVisibility() {
        super.toggleStatsVisibility()
        
    }
    
    func updateAudioStats(with data: String?) {
        guard let data = data, !data.isEmpty else { return }
        
        DispatchQueue.main.async {
            self.statsLabel.text = data
        }
    }
}
