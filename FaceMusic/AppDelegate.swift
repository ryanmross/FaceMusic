//
//  AppDelegate.swift
//  FaceMusic
//
//  Created by Ryan Ross on 6/11/24.
//

import UIKit
import ARKit
import AudioKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var conductor: VoiceConductor?



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
            // Initialize the VoiceConductor
            conductor = VoiceConductor()
            
            // Setup face tracker view controller with conductor
            setupFaceTrackerViewController()

            return true
        }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if !ARFaceTrackingConfiguration.isSupported {
            /*
             Shipping apps cannot require a face-tracking-compatible device, and thus must
             offer face tracking AR as a secondary feature. In a shipping app, use the
             `isSupported` property to determine whether to offer face tracking AR features.
             This sample code has no features other than a demo of ARKit face tracking, so
             it replaces the AR view (the initial storyboard in the view controller) with
             an alternate view controller containing a static error message.
             */
            
            // RYAN - I need an unsupportedDeviceMessage storyboard here
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            window?.rootViewController = storyboard.instantiateViewController(withIdentifier: "unsupportedDeviceMessage")
        }
        do {
            Settings.bufferLength = .huge
            Settings.enableLogging = true
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(Settings.bufferLength.duration)
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                            options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let err {
            print(err)
        }
        
        return true
    }
    
    func setupFaceTrackerViewController() {
            guard let window = window else { return }
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let faceTrackerVC = storyboard.instantiateViewController(withIdentifier: "FaceTrackerViewController") as? FaceTrackerViewController {
                // Inject the conductor into the FaceTrackerViewController
                faceTrackerVC.conductor = conductor
                window.rootViewController = faceTrackerVC
            }
        }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        conductor?.pauseAudio()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        conductor?.pauseAudio()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        conductor?.resumeAudio()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        conductor?.resumeAudio()
    }


}

