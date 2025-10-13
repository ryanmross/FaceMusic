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

// Optional protocol that conductors can adopt to provide per-field value converters
protocol ConductorValueMappingProviding {
    // Maps field keys to conversion closures from normalized [0,1] to domain-specific units
    var valueConverters: [String: (Float) -> Float] { get }
}

class VoiceSettingsViewController: UIViewController {
    
    
    var conductor: VoiceConductorProtocol?
    let appSettings = AppSettings()
    var patchSettings: PatchSettings!
    
    var closeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard patchSettings != nil else {
            print(" 💬 ⚠️ VoiceSettingsViewController.viewDidLoad(): patchSettings is nil.")
            return
        }
        
        print(" 💬 VoiceSettingsViewController.viewDidLoad() PatchSettings: \(self.patchSettings!)")
        
        let blurEffect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(blurView, at: 0)
        setupUI()
        configurePickersWithConductorSettings()
    }
    
    private func configurePickersWithConductorSettings() {
        
        // Remove existing custom views
        for subview in view.subviews where subview.tag == 101 {
            subview.removeFromSuperview()
        }
        
        // Add settings UI for active conductor
        let activeConductor = VoiceConductorManager.shared.activeConductor
        let customViews = activeConductor.makeSettingsUI(
            target: self,
            valueChangedAction: #selector(noopSliderChanged(_:)),
            touchUpAction: #selector(handleConductorSettingUpdate(_:))
        ) ?? []
        
        var previousView: UIView = view
        
        for customView in customViews {
            customView.tag = 101
            customView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(customView)
            NSLayoutConstraint.activate([
                customView.topAnchor.constraint(equalTo: previousView == view ? view.topAnchor : previousView.bottomAnchor, constant: previousView == view ? 80 : 20),
                customView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                customView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8)
            ])
            previousView = customView
        }
    }
    
    
    private func setupUI() {
        
        let activeConductor = VoiceConductorManager.shared.activeConductor
        
        let customViews = activeConductor.makeSettingsUI(
            target: self,
            valueChangedAction: #selector(noopSliderChanged(_:)),
            touchUpAction: #selector(handleConductorSettingUpdate(_:))
        ) ?? []
        
        var previousView: UIView = view
        for customView in customViews {
            customView.tag = 101
            view.addSubview(customView)
            NSLayoutConstraint.activate([
                customView.topAnchor.constraint(equalTo: previousView == view ? view.topAnchor : previousView.bottomAnchor, constant: previousView == view ? 80 : 20),
                customView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                customView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8)
            ])
            previousView = customView
        }
        
        // Create and configure the close button (X)
        closeButton = createCloseButton(target: self, action: #selector(closeSettings))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc private func handleConductorSettingUpdate(_ sender: UISlider) {
        
        print("handleConductorSettingUpdate called")
        let activeConductor = VoiceConductorManager.shared.activeConductor
        if let fieldKey = sender.accessibilityIdentifier {
            
            // Determine the value to save; ask the active conductor for a converter if available
            let normalizedValue = sender.value
            let valueToSave: Float
            if let provider = activeConductor as? ConductorValueMappingProviding,
               let converter = provider.valueConverters[fieldKey] {
                valueToSave = converter(normalizedValue)
            } else {
                valueToSave = normalizedValue
            }

            var updatedSettings: [String: AnyCodable] = patchSettings.conductorSpecificSettings ?? [:]
            updatedSettings[fieldKey] = AnyCodable(valueToSave)
            patchSettings.conductorSpecificSettings = updatedSettings
            PatchManager.shared.save(settings: patchSettings, forID: patchSettings.id)
            activeConductor.applyConductorSpecificSettings(from: patchSettings)
            
            //print("VoiceSettingsViewController.handleConductorSettingUpdate is calling activeConductor.applyConductorSpecificSettings(from: \(patchSettings)) with \(sender.value)")
        }
    }
    
    @objc private func noopSliderChanged(_ sender: UISlider) {
        // Intentionally left blank to avoid saving on continuous changes
    }
    
    @objc private func closeSettings() {
        // Dismiss the settings view using SwiftEntryKit's dismiss method
        SwiftEntryKit.dismiss()
    }
    
}

