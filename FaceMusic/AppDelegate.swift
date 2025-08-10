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



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Prewarm on launch so the first presentation doesn't glitch audio
        DispatchQueue.main.async { [weak self] in
            Prewarm.prewarmAllIfNeeded(in: self?.window)
        }
        AudioEngineManager.shared.startEngine()



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
        
        return true
    }
    

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }


}

// MARK: - One-shot UI/Haptics/Keyboard prewarmer
private enum Prewarm {
    private static var didPrewarm = false

    static func prewarmAllIfNeeded(in window: UIWindow?) {
        guard !didPrewarm else { return }
        didPrewarm = true

        guard let window = window else { return }
        
        print("!!! AppDelegate prewarming UI/Haptics/Keyboard")

        func doPrewarm(on view: UIView) {
            prewarmKeyboard(on: view)
            prewarmUIEffects(on: view)
            prewarmHaptics()
            prewarmActionSheet(in: window)
        }

        if let rootView = window.rootViewController?.view {
            doPrewarm(on: rootView)
        } else {
            // Root view not attached yet — attach a hidden host view just for prewarming
            let host = UIView(frame: .zero)
            host.isHidden = true
            window.addSubview(host)
            doPrewarm(on: host)
            DispatchQueue.main.async { host.removeFromSuperview() }
        }
    }

    // Trigger keyboard subsystem warmup without showing it
    private static func prewarmKeyboard(on view: UIView) {
        print("!!! AppDelegate prewarming keyboard")
        let tf = UITextField(frame: .zero)
        tf.isHidden = true
        view.addSubview(tf)
        DispatchQueue.main.async {
            _ = tf.becomeFirstResponder()
            DispatchQueue.main.async {
                tf.resignFirstResponder()
                tf.removeFromSuperview()
            }
        }
    }

    // Warm up blur/material effects rendering path
    private static func prewarmUIEffects(on view: UIView) {
        
        print("!!! AppDelegate prewarming UI effects")
        let blur = UIBlurEffect(style: .systemChromeMaterial)
        let v = UIVisualEffectView(effect: blur)
        v.frame = CGRect(x: -1, y: -1, width: 1, height: 1)
        v.isUserInteractionEnabled = false
        view.addSubview(v)
        DispatchQueue.main.async { v.removeFromSuperview() }
    }

    // Build the UIAlertController(actionSheet) view hierarchy once without presenting
    private static func prewarmActionSheet(in window: UIWindow?) {
        print("!!! AppDelegate prewarming action sheet")
        let alert = UIAlertController(title: "Warmup", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "A", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "B", style: .cancel, handler: nil))

        // Tiny host view to satisfy popover requirements on iPad without ever presenting
        let host = UIView(frame: CGRect(x: -1, y: -1, width: 1, height: 1))
        host.isHidden = true
        if let window = window {
            window.addSubview(host)
        }

        if let pop = alert.popoverPresentationController {
            pop.sourceView = host
            pop.sourceRect = host.bounds
        }

        // Force the view hierarchy to load and layout once
        _ = alert.view
        alert.view.setNeedsLayout()
        alert.view.layoutIfNeeded()

        DispatchQueue.main.async { host.removeFromSuperview() }
    }

    // Warm up haptic generators
    private static func prewarmHaptics() {
        print("!!! AppDelegate prewarming haptics")
        let impact = UIImpactFeedbackGenerator(style: .medium)
        let selection = UISelectionFeedbackGenerator()
        impact.prepare()
        selection.prepare()
    }
}

extension UIDevice {
    var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}
