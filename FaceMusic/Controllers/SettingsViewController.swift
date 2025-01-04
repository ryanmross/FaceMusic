// SettingsViewController.swift

import UIKit
import Tonic

class SettingsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource  {
    
    var conductor: VoiceConductor?  // The conductor to update

    // UI elements for key and scale
    var keyPicker: UIPickerView!
    var scaleSegmentedControl: UISegmentedControl!
    
    let keyOptions = ["Cb", "Gb", "Db", "Ab", "Eb", "Bb", "F", "C", "G", "D", "A", "E", "B", "F#", "C#"]
    let scales = ["Major", "Minor"]  // Example scales
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize the UI elements
        setupUI()
    }
    
    private func setupUI() {
        // Set up the key picker
        keyPicker = UIPickerView()
        keyPicker.frame = CGRect(x: 50, y: 100, width: 200, height: 150)
        keyPicker.delegate = self
        keyPicker.dataSource = self
        view.addSubview(keyPicker)
        
        // Set up the scale segmented control (Major/Minor)
        scaleSegmentedControl = UISegmentedControl(items: scales)
        scaleSegmentedControl.frame = CGRect(x: 50, y: 270, width: 200, height: 30)
        scaleSegmentedControl.selectedSegmentIndex = 0  // Default to Major
        scaleSegmentedControl.addTarget(self, action: #selector(scaleChanged), for: .valueChanged)
        view.addSubview(scaleSegmentedControl)
        
        // Add a button to apply the changes (optional)
        let applyButton = UIButton(type: .system)
        applyButton.frame = CGRect(x: 50, y: 320, width: 200, height: 40)
        applyButton.setTitle("Apply", for: .normal)
        applyButton.addTarget(self, action: #selector(applyChanges), for: .touchUpInside)
        view.addSubview(applyButton)
    }
    
    @objc private func scaleChanged() {
        // Handle scale change if needed
        // This could be updated when the segmented control is changed.
        print("Scale changed to: \(scales[scaleSegmentedControl.selectedSegmentIndex])")
    }

    @objc private func applyChanges() {
        // Get the selected key and scale
        let selectedKey = keyOptions[keyPicker.selectedRow(inComponent: 0)]
        let selectedScale = scales[scaleSegmentedControl.selectedSegmentIndex]
        
        
        
        var selectedNoteClass: NoteClass
        var newKey: Key
        
        switch selectedKey {
            case "Cb":
                selectedNoteClass = NoteClass.Cb
            case "Gb":
                selectedNoteClass = NoteClass.Gb
            case "Ab":
                selectedNoteClass = NoteClass.Ab
            case "Eb":
                selectedNoteClass = NoteClass.Eb
            case "Bb":
                selectedNoteClass = NoteClass.Bb
            case "F":
                selectedNoteClass = NoteClass.F
            case "C":
                selectedNoteClass = NoteClass.C
            case "G":
                selectedNoteClass = NoteClass.G
            case "D":
                selectedNoteClass = NoteClass.D
            case "A":
                selectedNoteClass = NoteClass.A
            case "E":
                selectedNoteClass = NoteClass.E
            case "B":
                selectedNoteClass = NoteClass.B
            case "F#":
                selectedNoteClass = NoteClass.Fs
            case "C#":
                selectedNoteClass = NoteClass.Cs
            default:
                selectedNoteClass = NoteClass.C
        }
        // RYAN - need this filled out
        
        switch selectedScale {
        case "Major":
            newKey = Key(root: selectedNoteClass, scale: .major)
        case "Minor":
            newKey = Key(root: selectedNoteClass, scale: .minor)
        default:
            newKey = Key(root: selectedNoteClass, scale: .major)
        }
        
        print("Changing key to \(newKey.root) \(newKey.scale.description)")
        // Update the conductor's key and scale
        if let conductor = conductor {
            conductor.refreshPitchSet(for: newKey)
        }
        
        // Optionally, dismiss the settings view or show feedback to the user
        self.dismiss(animated: true, completion: nil)
    }
    
    
    // MARK: - UIPickerViewDataSource Methods
       
       func numberOfComponents(in pickerView: UIPickerView) -> Int {
           return 1  // We only have one column (the keys)
       }

       func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
           return keyOptions.count  // The number of keys available
       }

       // MARK: - UIPickerViewDelegate Methods
       
       func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
           return keyOptions[row]  // Return the key for the given row
       }
}
