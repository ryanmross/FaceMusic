import UIKit
import Tonic
import SwiftEntryKit

class SettingsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    var conductor: VoiceConductor?
    let appSettings = AppSettings()
    
    var keyPicker: UIPickerView!
    var scalePicker: UIPickerView!
    var applyButton: UIButton!  // Add an apply button
    var closeButton: UIButton!  // Add the close button (X)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configurePickersWithConductorSettings()  // Call this after UI setup
    }
    
    private func setupUI() {
        // Set up the key picker
        keyPicker = UIPickerView()
        keyPicker.frame = CGRect(x: 50, y: 100, width: 150, height: 150)
        keyPicker.delegate = self
        keyPicker.dataSource = self
        keyPicker.tag = 0  // Set tag for identifying the picker
        keyPicker.backgroundColor = UIColor(white: 0.0, alpha: 0.5) // 50% transparent black
        
        // Set up the scale picker
        scalePicker = UIPickerView()
        scalePicker.frame = CGRect(x: 220, y: 100, width: 150, height: 150)
        scalePicker.delegate = self
        scalePicker.dataSource = self
        scalePicker.tag = 1  // Set tag for identifying the picker
        scalePicker.backgroundColor = UIColor(white: 0.0, alpha: 0.5) // 50% transparent black

        // Create a horizontal stack view to layout the pickers side by side
        let stackView = UIStackView(arrangedSubviews: [keyPicker, scalePicker])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 10

        // Add the stack view to the view
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        // Constraints for the stack view
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50), // Move up slightly
            stackView.heightAnchor.constraint(equalToConstant: 150),
            stackView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9)  // Occupy 90% of the width
        ])
         
        
        // Create and configure applyButton
        applyButton = UIButton(type: .system)
        applyButton.setTitle("Apply", for: .normal)
        applyButton.addTarget(self, action: #selector(applyChanges), for: .touchUpInside)
        applyButton.backgroundColor = .systemBlue
        applyButton.tintColor = .white
        applyButton.layer.cornerRadius = 10
        
        // Add the apply button below the stack view
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(applyButton)
        
        // Constraints for the apply button
        
        NSLayoutConstraint.activate([
            applyButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 20),  // Position it below the stack view
            applyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            applyButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6),
            applyButton.heightAnchor.constraint(equalToConstant: 44)
        ])
         
        
        // Create and configure closeButton (X)
        closeButton = UIButton(type: .system)
        closeButton.setTitle("X", for: .normal)
        closeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)  // Make the X large and bold
        closeButton.setTitleColor(.white, for: .normal)  // White X color
        closeButton.backgroundColor = UIColor(white: 0.0, alpha: 0.5)  // 50% transparent black background
        closeButton.layer.cornerRadius = 20  // Make it round
        
        closeButton.addTarget(self, action: #selector(closeSettings), for: .touchUpInside)
        
        // Add the close button to the view
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        // Constraints for the close button (top-right corner)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
         
    }
    
    private func configurePickersWithConductorSettings() {
       // Ensure the conductor exists
       guard let conductor = conductor else { return }

       // Get the conductor's current key and scale
       let currentKey = conductor.key.root
       let currentScale = conductor.key.scale

       // Find the indices of the current key and scale in the pickers
       if let keyIndex = appSettings.keyOptions.firstIndex(where: { $0.value == currentKey }) {
           keyPicker.selectRow(keyIndex, inComponent: 0, animated: false)
       }
       
       if let scaleIndex = appSettings.scales.firstIndex(where: { $0.value == currentScale }) {
           scalePicker.selectRow(scaleIndex, inComponent: 0, animated: false)
       }
   }
   
    
    // MARK: - UIPickerViewDataSource Methods
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == keyPicker {
            return appSettings.keyOptions.count
        } else if pickerView == scalePicker {
            return appSettings.scales.count
        }
        return 0
    }
    
    // MARK: - UIPickerViewDelegate Methods
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == keyPicker {
            return appSettings.keyOptions[row].key // Display the key (e.g., "C", "D", etc.)
        } else if pickerView == scalePicker {
            return appSettings.scales[row].key // Display the scale name (e.g., "Major", "Minor", etc.)
        }
        return nil
    }
    
    @objc private func applyChanges() {
        // Get selected key and scale from the picker views
        let selectedKey = appSettings.keyOptions[keyPicker.selectedRow(inComponent: 0)].value
        let selectedScale = appSettings.scales[scalePicker.selectedRow(inComponent: 0)].value
        
        let newKey = Key(root: selectedKey, scale: selectedScale)
        
        print("Changing key to \(newKey.root) \(newKey.scale.description)")
        
        if let conductor = conductor {
            conductor.key = newKey
        }
        
        // Optionally, dismiss the settings view
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc private func closeSettings() {
        // Dismiss the settings view using SwiftEntryKit's dismiss method
        SwiftEntryKit.dismiss()
    }
}
