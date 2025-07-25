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
    var voiceSoundPicker: UIPickerView!

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView.tag == 99 {
            return VoiceConductorRegistry.displayNames().count
        }
        return 0
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView.tag == 99 {
            return VoiceConductorRegistry.displayNames()[row]
        }
        return nil
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
        let (voiceSoundContainer, voiceSoundPickerInstance) = createLabeledPicker(title: "Voice Sound", tag: 99, delegate: self)
        self.voiceSoundPicker = voiceSoundPickerInstance
        view.addSubview(voiceSoundContainer)
        NSLayoutConstraint.activate([
            voiceSoundContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            voiceSoundContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            voiceSoundContainer.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8)
        ])

        // --- Vibrato Container ---
        let (vibratoContainer, vibratoSlider, vibratoValueLabelInstance) = createLabeledSlider(
            title: "Vibrato",
            minLabel: "None",
            maxLabel: "Max",
            minValue: 0,
            maxValue: 100,
            initialValue: patchSettings.vibratoAmount,
            target: self,
            valueChangedAction: #selector(vibratoSliderChanged(_:)),
            touchUpAction: #selector(vibratoSliderChanged(_:))
        )
        self.vibratoValueLabel = vibratoValueLabelInstance

        view.addSubview(vibratoContainer)
        NSLayoutConstraint.activate([
            vibratoContainer.topAnchor.constraint(equalTo: voiceSoundContainer.bottomAnchor, constant: 20),
            vibratoContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            vibratoContainer.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8)
        ])

        // Create and configure the close button (X)
        closeButton = createCloseButton(target: self, action: #selector(closeSettings))
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
