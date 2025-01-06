import UIKit

class StatsWindowManager {
    private var statsContainerView: UIView
    var toggleButton: UIButton
    var isExpanded = false
    var statsLabel: UILabel
    var statsContainerHeightConstraint: NSLayoutConstraint!
    var buttonTitle: String

    init(stackView: UIStackView, title: String = "Stats") {
        self.statsContainerView = UIView()
        self.statsLabel = UILabel()
        self.toggleButton = UIButton()
        self.buttonTitle = title
        setupStatsWindow(stackView: stackView)
    }

    private func setupStatsWindow(stackView: UIStackView) {
        statsContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        statsContainerView.layer.cornerRadius = 8
        statsContainerView.clipsToBounds = true
        statsContainerView.translatesAutoresizingMaskIntoConstraints = false

        statsLabel.numberOfLines = 0
        statsLabel.lineBreakMode = .byWordWrapping
        statsLabel.textAlignment = .left
        statsLabel.textColor = .white
        statsLabel.font = UIFont(name: "Courier", size: 9)
        statsLabel.isHidden = true
        statsLabel.translatesAutoresizingMaskIntoConstraints = false

        toggleButton.titleLabel?.font = UIFont(name: "Courier", size: 9)
        toggleButton.contentHorizontalAlignment = .left
        toggleButton.setTitle("+ \(buttonTitle)", for: .normal)
        toggleButton.setTitleColor(.white, for: .normal)
        toggleButton.addTarget(self, action: #selector(toggleStatsVisibility), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false

        statsContainerView.addSubview(toggleButton)
        statsContainerView.addSubview(statsLabel)
        stackView.addArrangedSubview(statsContainerView)

        statsContainerHeightConstraint = statsContainerView.heightAnchor.constraint(equalToConstant: 40)
        statsContainerHeightConstraint.isActive = true

        NSLayoutConstraint.activate([
            // Toggle button constraints
            
            toggleButton.topAnchor.constraint(equalTo: statsContainerView.topAnchor, constant: 5),
            toggleButton.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor, constant: 10),
            toggleButton.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor, constant: -10),
            toggleButton.heightAnchor.constraint(equalToConstant: 30),

            // Stats label constraints
            
            statsLabel.topAnchor.constraint(equalTo: toggleButton.bottomAnchor, constant: 5),
            statsLabel.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor, constant: 10),
            statsLabel.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor, constant: -10),
            //statsLabel.bottomAnchor.constraint(equalTo: statsContainerView.bottomAnchor, constant: -10),
            // removed last one because it was causing some weird warnings
             
        ])
 
    }

    @objc func toggleStatsVisibility() {
        isExpanded.toggle()

        UIView.animate(withDuration: 0.3) {
            if self.isExpanded {
                self.toggleButton.setTitle("- \(self.buttonTitle)", for: .normal)
                self.statsLabel.isHidden = false
                self.statsContainerHeightConstraint.constant = self.statsLabel.intrinsicContentSize.height + 50 // Adjust padding as needed
            } else {
                self.toggleButton.setTitle("+ \(self.buttonTitle)", for: .normal)
                self.statsLabel.isHidden = true
                self.statsContainerHeightConstraint.constant = 40
            }
            self.statsContainerView.layoutIfNeeded()
        }
    }

    func updateStats(with data: String?) {
        guard let data = data, !data.isEmpty else { return }

        DispatchQueue.main.async {
            self.statsLabel.text = data
            if self.isExpanded {
                self.statsContainerHeightConstraint.constant = self.statsLabel.intrinsicContentSize.height + 50
            }
        }
    }
}
