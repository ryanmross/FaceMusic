//
//  SettingsViewController.swift
//  FaceMusic
//
//  Created by Ryan Ross on 1/1/25.
//


import UIKit

class SettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5) // Semi-transparent black background

        
        // Setup your settings UI components here
        let label = UILabel()
        label.text = "Settings"
        label.frame = CGRect(x: 20, y: 100, width: 200, height: 40)
        view.addSubview(label)
    }
}
