//
//  VoiceSettingsViewController.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/17/25.
//

import UIKit
import SwiftEntryKit
import AudioKitEX
import AudioKitUI

class VoiceSettingsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 0
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 0
    }
    
    
    var conductor: VoiceConductorProtocol?
    let appSettings = AppSettings()
    var patchSettings: PatchSettings!
    
    var applyButton: UIButton!
    var closeButton: UIButton!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let refreshedSettings = PatchManager.shared.load(forID: patchSettings.id) {
            patchSettings = refreshedSettings
            print("PatchSettings: \(patchSettings)")
        }
        setupUI()
        configurePickersWithConductorSettings()
    }
    
    
    private func setupUI() {
        view.backgroundColor = .black

        // Sound Label
        let soundLabel = UILabel()
        soundLabel.text = "Sound:"
        soundLabel.textColor = .white
        soundLabel.textAlignment = .center
        soundLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(soundLabel)

        // Blank Picker
        let soundPicker = UIPickerView()
        soundPicker.delegate = self
        soundPicker.dataSource = self
        soundPicker.tag = 5
        soundPicker.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        soundPicker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(soundPicker)

        // Create and configure the apply button
        applyButton = UIButton(type: .system)
        applyButton.setTitle("Apply", for: .normal)
        applyButton.addTarget(self, action: #selector(applyChanges), for: .touchUpInside)
        applyButton.backgroundColor = .systemBlue
        applyButton.tintColor = .white
        applyButton.layer.cornerRadius = 10
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(applyButton)

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

        // Layout constraints
        NSLayoutConstraint.activate([
            soundLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            soundLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            soundPicker.topAnchor.constraint(equalTo: soundLabel.bottomAnchor, constant: 10),
            soundPicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            soundPicker.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            soundPicker.heightAnchor.constraint(equalToConstant: 150),

            applyButton.topAnchor.constraint(equalTo: soundPicker.bottomAnchor, constant: 20),
            applyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            applyButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6),
            applyButton.heightAnchor.constraint(equalToConstant: 44),

            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
     
     
    private func configurePickersWithConductorSettings() {
        
        /*
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
            lowestNotePicker.selectRow(conductor.lowestNote, inComponent: 0, animated: false)
            highestNotePicker.selectRow(conductor.highestNote, inComponent: 0, animated: false)
        }
         */
    }
    
    
    
    @objc private func applyChanges() {
        
        /*
        let selectedKey = MusicBrain.NoteName.allCases[keyPicker.selectedRow(inComponent: 0)]
        let selectedChordType = chordTypes[chordTypePicker.selectedRow(inComponent: 0)]

        print("Changing key to \(selectedKey.displayName) with chord type: \(selectedChordType)")

        let lowestNote = lowestNotePicker.selectedRow(inComponent: 0)
        let highestNote = highestNotePicker.selectedRow(inComponent: 0)

        print("Note range set to \(lowestNote) - \(highestNote)")

        patchSettings.lowestNote = lowestNote
        patchSettings.highestNote = highestNote
        patchSettings.numOfVoices = selectedNumOfVoices
        patchSettings.glissandoSpeed = glissandoSlider.value
        
        print("Glissando Speed set to \(patchSettings.glissandoSpeed)")
        
        patchSettings.key = selectedKey
        patchSettings.chordType = selectedChordType

        // Save the updated settings
        PatchManager.shared.save(settings: patchSettings, forID: patchSettings.id)
        
        // Apply to the conductor in one call
        conductor?.applySettings(patchSettings)

        MusicBrain.shared.updateKeyAndChordType(key: selectedKey, chordType: selectedChordType)

        print("Selected chord type from picker: \(selectedChordType)")
        
        */
        
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc private func closeSettings() {
        // Dismiss the settings view using SwiftEntryKit's dismiss method
        SwiftEntryKit.dismiss()
    }
    
}
