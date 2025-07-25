//
//  AlertHelper.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/24/25.
//

import UIKit


enum AlertHelper {
    static func promptToSavePatch(
        presenter: UIViewController,
        saveHandler: @escaping (String?) -> Void,
        skipHandler: @escaping () -> Void
    ) {
        print("promptToSavePatch()")
        
        let alert = UIAlertController(
            title: "New Patch",
            message: "Do you want to save the current patch before creating a new one?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Save and Create New", style: .default) { _ in
            promptForPatchName(presenter: presenter, completion: saveHandler)
        })
        alert.addAction(UIAlertAction(title: "Create New Without Saving", style: .destructive) { _ in
            skipHandler()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        presenter.present(alert, animated: true)
    }

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
}
