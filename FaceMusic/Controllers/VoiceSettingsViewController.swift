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
import AnyCodable

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

        let activeConductor = VoiceConductorManager.shared.activeConductor
        
        let customViews = activeConductor.makeSettingsUI(
            target: self,
            valueChangedAction: #selector(handleConductorSettingUpdate(_:)),
            touchUpAction: #selector(handleConductorSettingUpdate(_:))
        ) ?? []
        
        var previousView: UIView = voiceSoundContainer
        for customView in customViews {
            view.addSubview(customView)
            NSLayoutConstraint.activate([
                customView.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 20),
                customView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                customView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8)
            ])
            previousView = customView
        }

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
    
    @objc private func handleConductorSettingUpdate(_ sender: UISlider) {
        let activeConductor = VoiceConductorManager.shared.activeConductor
        if let fieldKey = sender.accessibilityIdentifier {
                        
            
            var updatedSettings: [String: AnyCodable] = patchSettings.conductorSpecificSettings ?? [:]
            updatedSettings[fieldKey] = AnyCodable(sender.value)
            patchSettings.conductorSpecificSettings = updatedSettings
            PatchManager.shared.save(settings: patchSettings, forID: patchSettings.id)
            activeConductor.applyConductorSpecificSettings(from: patchSettings)
            
            //print("VoiceSettingsViewController.handleConductorSettingUpdate is calling activeConductor.applyConductorSpecificSettings(from: \(patchSettings)) with \(sender.value)")
        }
    }
    
    
    @objc private func closeSettings() {
        // Dismiss the settings view using SwiftEntryKit's dismiss method
        SwiftEntryKit.dismiss()
    }
    
}
