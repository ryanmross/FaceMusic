import UIKit

class StatsWindowManager {
    private var statsContainerView: UIView
    
    var toggleButton: UIButton
    
    var isExpanded = false
    
    var statsLabel: UILabel
    var statsContainerHeightConstraint: NSLayoutConstraint!
    
    var buttonTitle: String!
    
    init(stackView: UIStackView, title: String) {
        self.statsContainerView = UIView()
        self.statsLabel = UILabel()
        self.toggleButton = UIButton()
        
        // Set the title for the toggle button
        self.buttonTitle = title
        
        
        
        setupStatsWindow(stackView: stackView)
        
    }
    
    private func setupStatsWindow(stackView: UIStackView) {
        statsContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        statsContainerView.layer.cornerRadius = 8
        statsContainerView.clipsToBounds = true
        statsContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set the initial height constraint for statsContainerView
        statsContainerHeightConstraint = statsContainerView.heightAnchor.constraint(equalToConstant: 40)
        statsContainerHeightConstraint.isActive = true

        toggleButton = UIButton()
        toggleButton.titleLabel?.font = UIFont(name: "Courier", size: 9)
        toggleButton.contentHorizontalAlignment = .left
        
        toggleButton.setTitle("+ \(self.buttonTitle ?? "+")", for: .normal)
        toggleButton.setTitleColor(.white, for: .normal)
        toggleButton.addTarget(self, action: #selector(toggleStatsVisibility), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        
        statsLabel.numberOfLines = 0
        statsLabel.lineBreakMode = .byWordWrapping // Ensure text wraps correctly
        statsLabel.textAlignment = .left
        statsLabel.sizeToFit() // Update the label size after text changes
        statsLabel.textColor = .white
        statsLabel.font = UIFont(name: "Courier", size: 9)
        statsLabel.isHidden = true
        statsLabel.translatesAutoresizingMaskIntoConstraints = false

        statsContainerView.addSubview(toggleButton)
        statsContainerView.addSubview(statsLabel)
        
        // Add stats window to the stack view
        stackView.addArrangedSubview(statsContainerView)
        
        
        NSLayoutConstraint.activate([

            // Constraints for toggleButton
            toggleButton.topAnchor.constraint(equalTo: statsContainerView.topAnchor, constant: 5),
            toggleButton.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor, constant: 10),
            toggleButton.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor, constant: -10),
            toggleButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Constraints for statsLabel
            statsLabel.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor, constant: 10),
            statsLabel.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor, constant: -10),
            statsLabel.bottomAnchor.constraint(equalTo: statsContainerView.bottomAnchor, constant: -5)
             
        ])
         
    }
    
    @objc func toggleStatsVisibility() {
        isExpanded.toggle()

        UIView.animate(withDuration: 0.3) {
            if self.isExpanded {
                self.toggleButton.setTitle("- \(self.buttonTitle ?? "")", for: .normal)
                self.statsLabel.isHidden = false
                self.statsLabel.sizeToFit()
                self.statsLabel.frame.size.height = 100
                self.statsContainerHeightConstraint.constant = self.statsLabel.frame.origin.y + self.statsLabel.frame.height + 10
            } else {
                self.toggleButton.setTitle("+ \(self.buttonTitle ?? "")", for: .normal)
                self.statsLabel.isHidden = true
                self.statsLabel.frame.size.height = 0
                self.statsContainerHeightConstraint.constant = self.toggleButton.frame.height + 10
            }
        }
    }
    
    func updateStats(text: String) {
        statsLabel.text = text
        statsLabel.sizeToFit()
    }
}
