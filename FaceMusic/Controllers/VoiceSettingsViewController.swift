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
    
    var closeButton: UIButton!
    var vibratoValueLabel: UILabel!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        if let refreshedSettings = PatchManager.shared.getPatchData(forID: patchSettings.id) {
            patchSettings = refreshedSettings
            print("PatchSettings: \(patchSettings)")
        }
        let blurEffect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)
        setupUI()
        configurePickersWithConductorSettings()
    }
    
    
    private func setupUI() {
        // --- Vibrato Container ---
        let vibratoLabel = createTitleLabel("Vibrato")

        let vibratoSlider = UISlider()
        vibratoSlider.minimumValue = 0
        vibratoSlider.maximumValue = 100
        vibratoSlider.value = patchSettings.vibratoAmount
        vibratoSlider.translatesAutoresizingMaskIntoConstraints = false
        vibratoSlider.addTarget(self, action: #selector(vibratoSliderChanged(_:)), for: .valueChanged)

        vibratoValueLabel = UILabel.settingsLabel(text: "\(Int(patchSettings.vibratoAmount))", fontSize: 13, bold: false)

        let vibratoStack = createSettingsStack(with: [vibratoLabel, vibratoSlider, vibratoValueLabel])
        let vibratoContainer = createSettingsContainer(with: vibratoStack)

        view.addSubview(vibratoContainer)
        NSLayoutConstraint.activate([
            vibratoContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            vibratoContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            vibratoContainer.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8)
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
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc private func vibratoSliderChanged(_ sender: UISlider) {
        patchSettings.vibratoAmount = sender.value
        PatchManager.shared.save(settings: patchSettings, forID: patchSettings.id)
        conductor?.applySettings(patchSettings)
        vibratoValueLabel.text = "\(Int(sender.value))"
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
    
    
    
    @objc private func closeSettings() {
        // Dismiss the settings view using SwiftEntryKit's dismiss method
        SwiftEntryKit.dismiss()
    }
    
}
