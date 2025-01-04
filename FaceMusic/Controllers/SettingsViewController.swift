import UIKit
import Tonic

class SettingsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    var voiceConductor: VoiceConductor?
    
    // Picker View for choosing key
    let keyPickerView = UIPickerView()
    
    // Array of key options as strings
    let keyOptions = ["Cb", "Gb", "Db", "Ab", "Eb", "Bb", "F", "C", "G", "D", "A", "E", "B", "F#", "C#"]
    
    // Major/Minor radio buttons
    var majorButton: UIButton!
    var minorButton: UIButton!
    
    // Selected key and scale
    var selectedKey: Key = Key(root: .C, scale: .major) // Default is C Major
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5) // Semi-transparent black background
        
        // Set up the Picker View
        keyPickerView.delegate = self
        keyPickerView.dataSource = self
        keyPickerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyPickerView)
        
        // Set up constraints for Picker View
        NSLayoutConstraint.activate([
            keyPickerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            keyPickerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            keyPickerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5), // 50% width
            keyPickerView.heightAnchor.constraint(equalToConstant: 150) // Set height as needed
        ])
        
        
        // Set up Major/Minor radio buttons
        setUpMajorMinorButtons()
        
        // Set default selection for key picker
        if let index = keyOptions.firstIndex(of: "C") {
            keyPickerView.selectRow(index, inComponent: 0, animated: false)
        }
        
        // Setup label for the settings
        let label = UILabel()
        label.text = "Settings"
        label.frame = CGRect(x: 20, y: 40, width: 200, height: 40)
        label.textColor = .white
        view.addSubview(label)
    }
    
    // Set up Major/Minor radio buttons
    func setUpMajorMinorButtons() {
        // Major button
        majorButton = UIButton(type: .system)
        majorButton.setTitle("Major", for: .normal)
        majorButton.frame = CGRect(x: 20, y: 250, width: 100, height: 40)
        majorButton.addTarget(self, action: #selector(selectMajor), for: .touchUpInside)
        view.addSubview(majorButton)
        
        // Minor button
        minorButton = UIButton(type: .system)
        minorButton.setTitle("Minor", for: .normal)
        minorButton.frame = CGRect(x: 130, y: 250, width: 100, height: 40)
        minorButton.addTarget(self, action: #selector(selectMinor), for: .touchUpInside)
        view.addSubview(minorButton)
        
        // Default to Major
        selectMajor()
    }
    
    // Major button action
    @objc func selectMajor() {
        majorButton.isSelected = true
        minorButton.isSelected = false
        selectedKey = Key(root: selectedKey.root, scale: .major)
        updateVoiceConductor()
    }
    
    // Minor button action
    @objc func selectMinor() {
        minorButton.isSelected = true
        majorButton.isSelected = false
        selectedKey = Key(root: selectedKey.root, scale: .minor)
        updateVoiceConductor()
    }
    
    // Update the VoiceConductor with the selected key and scale
    func updateVoiceConductor() {
        voiceConductor?.key = selectedKey
        voiceConductor?.refreshPitchSet(for: selectedKey)
    }
    
    // MARK: - UIPickerView DataSource & Delegate
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return keyOptions.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return keyOptions[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedKeyString = keyOptions[row]
        
        // Map the string to a Key and update the selectedKey
        selectedKey = getKeyFromString(selectedKeyString)
        
        updateVoiceConductor()
    }
    
    // Convert string to corresponding Key
    func getKeyFromString(_ keyString: String) -> Key {
        switch keyString {
        case "Cb":
            return Key(root: .Cb)
        case "Gb":
            return Key(root: .Gb)
        case "Db":
            return Key(root: .Db)
        case "Ab":
            return Key(root: .Ab)
        case "Eb":
            return Key(root: .Eb)
        case "Bb":
            return Key(root: .Bb)
        case "F":
            return Key(root: .F)
        case "C":
            return Key(root: .C)
        case "G":
            return Key(root: .G)
        case "D":
            return Key(root: .D)
        case "A":
            return Key(root: .A)
        case "E":
            return Key(root: .E)
        case "B":
            return Key(root: .B)
        case "F#":
            return Key(root: .F)
        case "C#":
            return Key(root: .C)
        default:
            return Key(root: .C) // Default key
        }
    }
}
