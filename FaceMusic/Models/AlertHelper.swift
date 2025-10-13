//
//  AlertHelper.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/24/25.
//

import UIKit
import os.log
import os.signpost

// RYAN added these to test
private let alertLog = OSLog(subsystem: "com.RyanRoss.FaceMusic", category: "Alert")
private let poiLog = OSLog(subsystem: "com.RyanRoss.FaceMusic", category: .pointsOfInterest)

enum AlertHelper {
    

    public static func promptForPatchName(
        presenter: UIViewController,
        completion: @escaping (String?) -> Void
    ) {
        
        Log.line(actor: "🪟 AlertHelper", fn: "promptForPatchName", "")

        
        let sp = OSSignpostID(log: poiLog)
        os_signpost(.begin, log: poiLog, name: "BuildPrompt", signpostID: sp)

        let alert = UIAlertController(
            title: "Save Patch",
            message: "Enter a name for this patch.",
            preferredStyle: .alert
        )
        
        let existingNames = PatchManager.shared.listPatches()
            .compactMap { PatchManager.shared.getPatchData(forID: $0)?.name }
        var nameField: UITextField?

        alert.addTextField { tf in
            tf.placeholder = "Patch Name"
            nameField = tf
        }

        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            let name = nameField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            completion(name)
        }
        saveAction.isEnabled = false
        alert.addAction(saveAction)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        let updateSaveEnabled: () -> Void = {
            let name = nameField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let isValid = !name.isEmpty && !existingNames.contains(name)
            saveAction.isEnabled = isValid
            if isValid {
                alert.message = "Enter a name for this patch."
            } else {
                alert.message = name.isEmpty ? "Name cannot be empty." : "Patch name already exists."
            }
        }
        updateSaveEnabled()
        if let field = nameField {
            NotificationCenter.default.addObserver(forName: UITextField.textDidChangeNotification, object: field, queue: .main) { _ in
                updateSaveEnabled()
            }
        }
        
        // RYAN testing here
        os_signpost(.event, log: poiLog, name: "PresentPrompt")
        let presentingVC = presenter.presentedViewController ?? presenter
        presentingVC.present(alert, animated: true) {
            os_signpost(.end, log: poiLog, name: "BuildPrompt", signpostID: sp)
            alert.textFields?.first?.becomeFirstResponder()
        }

    }

    private static func showValidationAlert(
        presenter: UIViewController,
        message: String,
        onDismiss: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(title: "Invalid Name", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            onDismiss?()
        })
        let presentingVC = presenter.presentedViewController ?? presenter
        presentingVC.present(alert, animated: true, completion: nil)
    }
    
    static func showPatchOptionsMenu(
        presenter: UIViewController,
        sourceView: UIView,
        isDefault: Bool,
        onRename: (() -> Void)? = nil,
        onSaveAs: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        
        
        // RYAN - signpost logic
        let sp = OSSignpostID(log: poiLog)
        os_signpost(.begin, log: poiLog, name: "BuildActionSheet", signpostID: sp)
        
        
        let title = isDefault ? "Default Patch Options" : "Saved Patch Options"
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Save As...", style: .default) { _ in
            alert.dismiss(animated: true) {
                onSaveAs()
            }
        })
        
        if !isDefault {
            if let renameAction = onRename {
                alert.addAction(UIAlertAction(title: "Rename", style: .default) { _ in
                    alert.dismiss(animated: true) {
                        renameAction()
                    }
                })
            }
            
            if let deleteAction = onDelete {
                alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                    alert.dismiss(animated: true) {
                        deleteAction()
                    }
                })
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        // For iPad compatibility
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        
        // RYAN - Signpost
        os_signpost(.event, log: poiLog, name: "PresentActionSheet")

        presenter.present(alert, animated: true) {
            os_signpost(.end, log: poiLog, name: "BuildActionSheet", signpostID: sp)
        }

    }
}

