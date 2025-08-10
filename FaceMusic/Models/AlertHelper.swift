//
//  AlertHelper.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/24/25.
//

import UIKit
import os.log

private let alertLog = OSLog(subsystem: "com.RyanRoss.FaceMusic", category: "Alert")

enum AlertHelper {
    
    

    public static func promptForPatchName(
        presenter: UIViewController,
        completion: @escaping (String?) -> Void
    ) {
        print("promptForPatchName()")

        let alert = UIAlertController(
            title: "Save Patch",
            message: "Enter a name for this patch.",
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = "Patch Name" }

        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let existingNames = PatchManager.shared.listPatches()
                .compactMap { PatchManager.shared.getPatchData(forID: $0)?.name }

            if name.isEmpty {
                showValidationAlert(presenter: presenter, message: "Patch name cannot be empty.")
            } else if existingNames.contains(name) {
                showValidationAlert(presenter: presenter, message: "Patch name already exists.")
            } else {
                completion(name)
                return
            }

            // Re-show prompt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                promptForPatchName(presenter: presenter, completion: completion)
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        presenter.present(alert, animated: true)
    }

    private static func showValidationAlert(presenter: UIViewController, message: String) {
        let alert = UIAlertController(title: "Invalid Name", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        presenter.present(alert, animated: true)
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
        let sp = OSSignpostID(log: alertLog)
        os_signpost(.begin, log: alertLog, name: "BuildActionSheet", signpostID: sp)
        
        
        let title = isDefault ? "Default Patch Options" : "Saved Patch Options"
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Save As...", style: .default) { _ in
            onSaveAs()
        })
        
        if !isDefault {
            if let renameAction = onRename {
                alert.addAction(UIAlertAction(title: "Rename", style: .default) { _ in
                    renameAction()
                })
            }
            
            if let deleteAction = onDelete {
                alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                    deleteAction()
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
        os_signpost(.event, log: alertLog, name: "PresentActionSheet")

        presenter.present(alert, animated: true) {
            os_signpost(.end, log: alertLog, name: "BuildActionSheet", signpostID: sp)
        }

    }
}
