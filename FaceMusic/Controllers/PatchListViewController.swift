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
    
    var onPatchSelected: ((Int) -> Void)?
    
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
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "PatchCell")
        cell.textLabel?.text = "Patch \(id)"
        cell.detailTextLabel?.text = "Tap to load"
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let id = patchIDs[indexPath.row]
        dismiss(animated: true) {
            self.onPatchSelected?(id)
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let id = patchIDs[indexPath.row]
            patchManager.deletePatch(forID: id)
            patchIDs.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
}