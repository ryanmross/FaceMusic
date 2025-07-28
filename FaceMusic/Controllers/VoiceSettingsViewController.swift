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
        
        print("VoiceSettingsViewController.viewDidLoad()")
        
        guard let initialSettings = patchSettings,
              let refreshedSettings = PatchManager.shared.getPatchData(forID: initialSettings.id) else {
            print("⚠️ VoiceSettingsViewController.viewDidLoad(): Failed to load patch settings.")
            return
        }
        
        self.patchSettings = refreshedSettings
        
        print("VoiceSettingsViewController.viewDidLoad() PatchSettings: \(self.patchSettings!)")
        
        let blurEffect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)
        setupUI()
        configurePickersWithConductorSettings()
    }
    
    private func configurePickersWithConductorSettings() {
        let activeID = self.patchSettings.conductorID
        if let index = VoiceConductorRegistry.conductorIndex(of: activeID) {
            voiceSoundPicker?.selectRow(index, inComponent: 0, animated: false)
        }
        
        // Remove existing custom views
        for subview in view.subviews where subview.tag == 101 {
            subview.removeFromSuperview()
        }
        
        // Add settings UI for active conductor
        let activeConductor = VoiceConductorManager.shared.activeConductor
        let customViews = activeConductor.makeSettingsUI(
            target: self,
            valueChangedAction: #selector(handleConductorSettingUpdate(_:)),
            touchUpAction: #selector(handleConductorSettingUpdate(_:))
        ) ?? []
        
        var previousView: UIView = voiceSoundPicker.superview!
        for customView in customViews {
            customView.tag = 101
            view.addSubview(customView)
            NSLayoutConstraint.activate([
                customView.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 20),
                customView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                customView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8)
            ])
            previousView = customView
        }
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
            customView.tag = 101
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
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView.tag == 99 {
            
            print("👉 VoiceSettingsViewController.pickerView didSelectRow \(row)")
            
            let selectedID = VoiceConductorRegistry.voiceConductorIDs()[row]
            guard let descriptor = VoiceConductorRegistry.descriptor(for: selectedID) else { return }
            
            if descriptor.id != VoiceConductorManager.shared.activeConductorID {
                let selectedConductor = descriptor.makeInstance()
                
                print("VoiceSettingsViewController.pickerView didSelectRow switching conductors to \(selectedID)")
                
                self.patchSettings.conductorID = selectedID
                PatchManager.shared.save(settings: patchSettings, forID: patchSettings.id)
                VoiceConductorManager.shared.setActiveConductor(settings: patchSettings)
                self.conductor = selectedConductor
                
                // Remove existing custom views
                for subview in view.subviews where subview.tag == 101 {
                    subview.removeFromSuperview()
                }
                
                // Re-add updated settings UI
                let customViews = selectedConductor.makeSettingsUI(
                    target: self,
                    valueChangedAction: #selector(handleConductorSettingUpdate(_:)),
                    touchUpAction: #selector(handleConductorSettingUpdate(_:))
                )
                
                var previousView: UIView = voiceSoundPicker.superview!
                for customView in customViews {
                    customView.tag = 101
                    view.addSubview(customView)
                    NSLayoutConstraint.activate([
                        customView.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 20),
                        customView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                        customView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8)
                    ])
                    previousView = customView
                }
            }
        }
    }
}
