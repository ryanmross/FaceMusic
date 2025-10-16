//
//  SceneDelegate.swift
//  FaceMusic
//
//  Created by Ryan Ross on 10/13/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        
        
        // LOG OUR SAVED PATCHES
        logUserDefaultsPatches()

        
        Log.line(actor: "🎓 SceneDelegate", fn: "scene.willConnectTo", "starting scene willConnectTo")


        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = LoadingViewController()
        self.window = window
        window.makeKeyAndVisible()
        
        
        // Prewarm UI and audio on the main queue, then transition to the main app UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            Prewarm.prewarmAllIfNeeded(in: self.window)
            Prewarm.prewarmTextEntryAlertIfNeeded(in: self.window) {
                // Use new action sheet prewarm method that presents and dismisses to warm up properly
                Prewarm.prewarmActionSheetIfNeeded(on: self.window?.rootViewController)
                AudioEngineManager.shared.startEngine()
                // After prewarming, transition to FaceTrackerViewController
                
                Log.line(actor: "🎓 AppDelegate", fn: "scene.willConnectTo", "finished prewarming, transitioning to FaceTrackerViewController")

                
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let faceTrackerVC = storyboard.instantiateViewController(withIdentifier: "FaceTrackerViewController")
                if let window = self.window {
                    UIView.transition(with: window,
                                      duration: 0.3,
                                      options: .transitionCrossDissolve,
                                      animations: {
                                          window.rootViewController = faceTrackerVC
                                      },
                                      completion: nil)
                } else {
                    self.window?.rootViewController = faceTrackerVC
                }
            }
        }
    }
    
    
    /// Logs the stored patches from UserDefaults.
    /// - Parameter key: The UserDefaults key under which patches are stored. Defaults to "patchesKey".
    private func logUserDefaultsPatches(key: String = "SavedPatches") {
        let keyToUse = key

        if let value = UserDefaults.standard.object(forKey: keyToUse) {
            if let data = value as? Data {
                // Try to decode JSON for readability; if it fails, log raw data length/base64
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
                   let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    Log.line(actor: "SceneDelegate", fn: "init", "UserDefaults[\(keyToUse)] (JSON):\n\(prettyString)")
                } else if let utf8String = String(data: data, encoding: .utf8) {
                    Log.line(actor: "SceneDelegate", fn: "init", "UserDefaults[\(keyToUse)] (utf8): \(utf8String)")
                } else {
                    Log.line(actor: "SceneDelegate", fn: "init", "UserDefaults[\(keyToUse)] Data (\(data.count) bytes, base64): \(data.base64EncodedString())")
                }
            } else {
                Log.line(actor: "SceneDelegate", fn: "init", "UserDefaults[\(keyToUse)] = \(value)")
            }
        } else {
            Log.line(actor: "SceneDelegate", fn: "init", "No value found in UserDefaults for key '\(keyToUse)'")
        }
    }

    // Optional: Implement scene lifecycle methods if needed
}




// MARK: - One-shot UI/Haptics/Keyboard prewarmer
private enum Prewarm {
    private static var didPrewarm = false
    private static var didPrewarmTextAlert = false
    private static var coverWindow: UIWindow?
    private static var prewarmHostWindow: UIWindow?
    
    private static let textWarmupDelay: TimeInterval = 0.7

    private static func makeWindow(matching mainWindow: UIWindow, level: UIWindow.Level, alpha: CGFloat = 1.0, backgroundColor: UIColor = .clear) -> (UIWindow, UIViewController) {
        let w = UIWindow(frame: mainWindow.bounds)
        if #available(iOS 13.0, *), let scene = mainWindow.windowScene {
            w.windowScene = scene
        }
        w.windowLevel = level
        w.alpha = alpha
        let vc = UIViewController()
        vc.view.backgroundColor = backgroundColor
        w.rootViewController = vc
        w.isHidden = false
        return (w, vc)
    }

    private static func addSnapshot(of mainWindow: UIWindow, to container: UIView) {
        if let snapshot = mainWindow.snapshotView(afterScreenUpdates: false) {
            snapshot.frame = container.bounds
            snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(snapshot)
        } else {
            container.backgroundColor = mainWindow.rootViewController?.view.backgroundColor ?? .black
        }
    }

    private static func destroyWindow(_ window: inout UIWindow?) {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }

    static func prewarmAllIfNeeded(in window: UIWindow?) {
        guard !didPrewarm else { return }
        didPrewarm = true

        guard let window = window else { return }
        
        Log.line(actor: "🎓 AppDelegate", fn: "prewarmAllIfNeeded", "prewarming UI/Haptics/Keyboard")
        
        func doPrewarm(on view: UIView) {
            prewarmKeyboard(on: view)
            prewarmUIEffects(on: view)
            prewarmHaptics()
            // Removed old prewarmActionSheet call to avoid double prewarming,
            // replaced by prewarmActionSheetIfNeeded in main launch sequence
            // prewarmActionSheet(in: window)
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
        Log.line(actor: "🎓 AppDelegate", fn: "prewarmKeyboard", "prewarming Keyboard")

        let tf = UITextField(frame: .zero)
        tf.isHidden = true
        // Reduce heavyweight text services and avoid showing the system keyboard
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        if #available(iOS 11.0, *) {
            tf.smartDashesType = .no
            tf.smartQuotesType = .no
            tf.smartInsertDeleteType = .no
        }
        tf.textContentType = .none
        tf.inputView = UIView(frame: .zero)
        view.addSubview(tf)
        DispatchQueue.main.async {
            _ = tf.becomeFirstResponder()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tf.resignFirstResponder()
                tf.removeFromSuperview()
            }
        }
    }

    // Warm up blur/material effects rendering path
    private static func prewarmUIEffects(on view: UIView) {
        
        Log.line(actor: "🎓 AppDelegate", fn: "prewarmUIEffects", "prewarming UI Effects")
        let blur = UIBlurEffect(style: .systemChromeMaterial)
        let v = UIVisualEffectView(effect: blur)
        v.frame = CGRect(x: -1, y: -1, width: 1, height: 1)
        v.isUserInteractionEnabled = false
        view.addSubview(v)
        DispatchQueue.main.async { v.removeFromSuperview() }
    }

    // Warm up haptic generators
    private static func prewarmHaptics() {
        Log.line(actor: "🎓 AppDelegate", fn: "prewarmHaptics", "prewarming haptics")

        let impact = UIImpactFeedbackGenerator(style: .medium)
        let selection = UISelectionFeedbackGenerator()
        impact.prepare()
        selection.prepare()
    }

    static func prewarmTextEntryAlertIfNeeded(in mainWindow: UIWindow?, completion: (() -> Void)? = nil) {
        guard !didPrewarmTextAlert else { completion?(); return }
        didPrewarmTextAlert = true
        Log.line(actor: "🎓 AppDelegate", fn: "prewarmTextEntryAlertIfNeeded", "FULL prewarm (real keyboard) using host + cover windows")


        guard let mainWindow = mainWindow else {
            // Fallback: Force UIKit internals to initialize.
            let alert = UIAlertController(title: "\u{200B}", message: nil, preferredStyle: .alert)
            alert.addTextField { _ in }
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            alert.loadViewIfNeeded()
            alert.view.setNeedsLayout()
            alert.view.layoutIfNeeded()
            completion?()
            return
        }

        // High-level cover window fully hides any visual changes (including keyboard).
        let (cWindow, cVC) = makeWindow(matching: mainWindow, level: UIWindow.Level(rawValue: 10_000), alpha: 1.0, backgroundColor: .clear)
        addSnapshot(of: mainWindow, to: cVC.view)
        coverWindow = cWindow

        // Dedicated host window for presenting the alert so main UI layout is unaffected.
        let (hWindow, hVC) = makeWindow(matching: mainWindow, level: .normal, alpha: 1.0, backgroundColor: .clear)
        prewarmHostWindow = hWindow

        // Build the alert with default text services (no disabling) to warm heavy paths.
        let alert = UIAlertController(title: "\u{200B}", message: nil, preferredStyle: .alert)
        alert.addTextField { _ in }
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        alert.loadViewIfNeeded()

        hVC.present(alert, animated: false) {
            // Bring up the real keyboard and full text services after one run loop to ensure a valid session.
            DispatchQueue.main.async {
                alert.textFields?.first?.becomeFirstResponder()
            }

            // Give the system time to spin up keyboard, predictive bar, dictation, etc.
            DispatchQueue.main.asyncAfter(deadline: .now() + textWarmupDelay) {
                if let tf = alert.textFields?.first, tf.isFirstResponder {
                    tf.resignFirstResponder()
                }
                alert.dismiss(animated: false) {
                    // Clean up both windows and call completion.
                    destroyWindow(&prewarmHostWindow)
                    destroyWindow(&coverWindow)
                    completion?()
                }
            }
        }
    }
    
    /// Presents and immediately dismisses an action sheet to warm up the action sheet UI subsystem.
    /// This avoids visible UI since the loading screen is still covering the window.
    static func prewarmActionSheetIfNeeded(on viewController: UIViewController?) {
        guard let vc = viewController else { return }
        let alert = UIAlertController(title: "Warmup", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "A", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "B", style: .cancel, handler: nil))
        vc.present(alert, animated: false) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                alert.dismiss(animated: false, completion: nil)
            }
        }
    }
    
    
    

    
    
    
}
