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
        if let settings = patchManager.getPatchData(forID: id) {
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

        if let settings = patchManager.getPatchData(forID: id) {
            print("👉 PatchListViewController.didSelectRowAt: user chose patch \(id): \(settings.name ?? "nil")")
            
            // Switch to the new conductor only if needed
            if VoiceConductorManager.shared.activeConductorID != settings.conductorID {
                print("PatchListViewController.didSelectRowAt: we need to switch to conductor \(settings.conductorID). Calling setActiveConductor...")
                VoiceConductorManager.shared.setActiveConductor(settings: settings)
            }

            patchManager.currentPatchID = id
            dismiss(animated: true) {
                self.onPatchSelected?(id, settings)
                NotificationCenter.default.post(name: NSNotification.Name("PatchDidChange"), object: nil)
            }
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
               let newSettings = self.patchManager.getPatchData(forID: newCurrentID) {
                self.onPatchSelected?(newCurrentID, newSettings)
            }

            completionHandler(true)
        }

        let renameAction = UIContextualAction(style: .normal, title: "Rename") { (_, _, completionHandler) in
            AlertHelper.promptForPatchName(presenter: self) { [weak self] newName in
                guard let self = self, let newName = newName else { return }
                self.patchManager.renamePatch(id: id, newName: newName)
                self.loadPatches()
                NotificationCenter.default.post(name: NSNotification.Name("PatchDidChange"), object: nil)
            }
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
