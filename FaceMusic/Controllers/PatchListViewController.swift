//
//  PatchListViewController.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//

//
//  PatchListViewController.swift
//  FaceMusic
//

import UIKit

class PatchListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private let patchManager = PatchManager.shared
    
    
    private var patchIDs: [Int] = []
    
    private let tableView = UITableView()
    
    var onPatchSelected: ((Int, PatchSettings?) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Patches"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        loadPatches()
    }
    
    private func loadPatches() {
        patchIDs = patchManager.listPatches()
        tableView.reloadData()
    }
    
    @objc private func doneTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return patchIDs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let id = patchIDs[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "PatchCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "PatchCell")
        if let settings = patchManager.load(forID: id) {
            cell.textLabel?.text = settings.name
        } else {
            cell.textLabel?.text = "Patch \(id)"
        }
        cell.detailTextLabel?.text = "Tap to load"
        if id == patchManager.currentPatchID {
            //print("current cell: \(id), patchManager.currentPatchID: \(patchManager.currentPatchID)")
            cell.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        } else {
            cell.backgroundColor = .clear
        }
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let id = patchIDs[indexPath.row]
        
        let settings = patchManager.load(forID: id)
        print("loaded patch \(id): \(settings?.name ?? "nil")")
        patchManager.currentPatchID = id
        dismiss(animated: true) {
            self.onPatchSelected?(id, settings)
        }
    }
    
    // Support swipe actions: Delete and Rename
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let id = patchIDs[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (_, _, completionHandler) in
            self.patchManager.deletePatch(forID: id)
            self.loadPatches()

            // Optionally notify that a new current patch is selected
            if let newCurrentID = self.patchManager.currentPatchID,
               let newSettings = self.patchManager.load(forID: newCurrentID) {
                self.onPatchSelected?(newCurrentID, newSettings)
            }

            completionHandler(true)
        }

        let renameAction = UIContextualAction(style: .normal, title: "Rename") { (_, _, completionHandler) in
            let alert = UIAlertController(title: "Rename Patch", message: "Enter a new name.", preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "Patch Name"
                if let settings = self.patchManager.load(forID: id) {
                    textField.text = settings.name
                }
            }
            alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
                let newName = alert.textFields?.first?.text ?? "Untitled Patch"
                self.patchManager.renamePatch(id: id, newName: newName)
                self.loadPatches()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true)
            completionHandler(true)
        }

        renameAction.backgroundColor = .systemBlue

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, renameAction])
        return configuration
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPatches()
    }
}
