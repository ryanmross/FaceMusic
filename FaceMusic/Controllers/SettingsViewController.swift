import UIKit
import SwiftEntryKit

class SettingsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    var conductor: VoiceConductorProtocol?
    let appSettings = AppSettings()
    
    var keyPicker: UIPickerView!
    var chordTypePicker: UIPickerView!
    var voicesPicker: UIPickerView!
    var applyButton: UIButton!
    var closeButton: UIButton!
    
    var selectedNumOfVoices: Int = 1 // Store the selected number of voices
    let chordTypes = MusicBrain.ChordType.allCases
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configurePickersWithConductorSettings()
    }
    
    private func setupUI() {
        // Set up the key picker
        keyPicker = UIPickerView()
        keyPicker.delegate = self
        keyPicker.dataSource = self
        keyPicker.tag = 0
        keyPicker.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        let keyPickerWidth: CGFloat = 110
        keyPicker.frame = CGRect(x: 50, y: 100, width: keyPickerWidth, height: 150)
        
        // Set up the chord type picker
        chordTypePicker = UIPickerView()
        chordTypePicker.delegate = self
        chordTypePicker.dataSource = self
        chordTypePicker.tag = 1
        chordTypePicker.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        // Create a horizontal stack view for key and chord type pickers
        let stackView = UIStackView(arrangedSubviews: [keyPicker, chordTypePicker])
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        // Stack view constraints
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            stackView.heightAnchor.constraint(equalToConstant: 150),
            stackView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40)
        ])
        
        // Set constraints for key and chord type pickers
        keyPicker.translatesAutoresizingMaskIntoConstraints = false
        chordTypePicker.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            keyPicker.widthAnchor.constraint(equalToConstant: keyPickerWidth)
        ])
        
        // Set up the voices picker and label
        voicesPicker = UIPickerView()
        voicesPicker.delegate = self
        voicesPicker.dataSource = self
        voicesPicker.tag = 2
        voicesPicker.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        voicesPicker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(voicesPicker)
        
        let voicesLabel = UILabel()
        voicesLabel.text = "Number of Voices"
        voicesLabel.textColor = .white
        voicesLabel.textAlignment = .center
        voicesLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(voicesLabel)

        // Constraints for the label and voices picker
        NSLayoutConstraint.activate([
            voicesLabel.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 20),
            voicesLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            voicesLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            
            voicesPicker.topAnchor.constraint(equalTo: voicesLabel.bottomAnchor, constant: 10),
            voicesPicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            voicesPicker.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            voicesPicker.heightAnchor.constraint(equalToConstant: 150)
        ])
        
        // Create and configure the apply button
        applyButton = UIButton(type: .system)
        applyButton.setTitle("Apply", for: .normal)
        applyButton.addTarget(self, action: #selector(applyChanges), for: .touchUpInside)
        applyButton.backgroundColor = .systemBlue
        applyButton.tintColor = .white
        applyButton.layer.cornerRadius = 10
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(applyButton)
        
        // Apply button constraints
        NSLayoutConstraint.activate([
            applyButton.topAnchor.constraint(equalTo: voicesPicker.bottomAnchor, constant: 20),
            applyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            applyButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6),
            applyButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Create and configure the close button (X)
        closeButton = UIButton(type: .system)
        closeButton.setTitle("X", for: .normal)
        closeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        closeButton.layer.cornerRadius = 20
        closeButton.addTarget(self, action: #selector(closeSettings), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        // Close button constraints
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func configurePickersWithConductorSettings() {
        // Use the current key from MusicBrain
        let currentKey = MusicBrain.shared.currentKey

        if let keyIndex = MusicBrain.NoteName.allCases.firstIndex(of: currentKey) {
            keyPicker.selectRow(keyIndex, inComponent: 0, animated: false)
        }
        
        // Use the current chord type from MusicBrain
        let currentChordType = MusicBrain.shared.currentChordType
        if let chordIndex = chordTypes.firstIndex(of: currentChordType) {
            chordTypePicker.selectRow(chordIndex, inComponent: 0, animated: false)
        }

        // Number of voices from conductor if you want:
        if let conductor = conductor {
            selectedNumOfVoices = Int(conductor.numOfVoices)
            voicesPicker.selectRow(selectedNumOfVoices - 1, inComponent: 0, animated: false)
        }
    }
    
    // MARK: - UIPickerViewDataSource Methods
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView.tag == 0 { // Key picker
            return MusicBrain.NoteName.allCases.count
        } else if pickerView.tag == 1 { // Chord Type picker
            return chordTypes.count
        } else if pickerView.tag == 2 { // Number of Voices picker
            return 8 // Number of voices options (1-8)
        }
        return 0
    }

    // MARK: - UIPickerViewDelegate Methods
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView.tag == 0 { // Key picker
            return MusicBrain.NoteName.allCases[row].displayName
        } else if pickerView.tag == 1 { // Chord Type picker
            return chordTypes[row].rawValue
        } else if pickerView.tag == 2 { // Number of Voices picker
            return "\(row + 1)" // Return the numbers 1-8
        }
        return nil
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView.tag == 2 { // Number of Voices picker
            selectedNumOfVoices = row + 1 // Picker rows are 0-indexed
            print("Selected number of voices: \(selectedNumOfVoices)")
        }
    }
    
    @objc private func applyChanges() {
        let selectedKey = MusicBrain.NoteName.allCases[keyPicker.selectedRow(inComponent: 0)]
        let selectedChordType = chordTypes[chordTypePicker.selectedRow(inComponent: 0)]

        print("Changing key to \(selectedKey.displayName) with chord type: \(selectedChordType)")

        if let conductor = conductor {
            conductor.numOfVoices = Int(selectedNumOfVoices)
        }

        MusicBrain.shared.updateKeyAndChordType(key: selectedKey, chordType: selectedChordType)

        print("Selected chord type from picker: \(selectedChordType)")
        
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc private func closeSettings() {
        // Dismiss the settings view using SwiftEntryKit's dismiss method
        SwiftEntryKit.dismiss()
    }
}
