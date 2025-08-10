//
//  PatchSelectorView.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/27/25.
//

import UIKit
import Combine
import SwiftUI

class PatchSelectorViewModel: ObservableObject {
    // Cache all default patches at the top level for reuse
    private static let allDefaultPatches: [PatchSettings] = VoiceConductorRegistry.all.flatMap { $0.defaultPatches }
    enum PatchType {
        case defaultOriginal
        case defaultEdited
        case saved
    }
    struct PatchBarItem: Identifiable {
        let id: Int
        let type: PatchType
        let patchID: Int
    }

    var onPatchSelected: ((PatchSettings) -> Void)?
    @Published var patchBarItems: [PatchBarItem] = []

    @Published var selectedPatchBarItemID: Int?

    private var currentEditedDefaultPatchID: Int?

    private func generatePatchBarItems() -> [PatchBarItem] {
        let savedPatchIDs = PatchManager.shared.listPatches()
        let savedPatches = savedPatchIDs.compactMap { PatchManager.shared.getPatchData(forID: $0) }
        let savedPatchMap = Dictionary(uniqueKeysWithValues: savedPatches.map { ($0.id, $0) })

        
        var items: [PatchBarItem] = []
        var id = 0

        let defaultPatches = PatchSelectorViewModel.allDefaultPatches
        for defaultPatch in defaultPatches {
            //print("🏛️ PatchSelectorViewModel loading default patch \(defaultPatch.id)")
            let patchID = defaultPatch.id
            let type: PatchType = savedPatchMap[patchID] != nil ? .defaultEdited : .defaultOriginal
            items.append(PatchBarItem(id: id, type: type, patchID: patchID))
            id += 1
        }
        
        

        for savedPatch in savedPatches where savedPatch.id >= 0 {
            //print("🏛️ PatchSelectorViewModel loading saved patch \(savedPatch.id)")
            items.append(PatchBarItem(id: id, type: .saved, patchID: savedPatch.id))
            id += 1
        }

        for (index, item) in items.enumerated() {
            print("🏛️ PatchSelectorViewModel generated patch bar item \(index): \(item) ")
        }
        return items
    }

    func patch(for item: PatchBarItem) -> PatchSettings? {
        switch item.type {
        case .saved, .defaultEdited:
            return PatchManager.shared.getPatchData(forID: item.patchID)
        case .defaultOriginal:
            return PatchSelectorViewModel.allDefaultPatches.first(where: { $0.id == item.patchID })
        }
    }


    func loadPatches() {
        self.patchBarItems = generatePatchBarItems()

        for (index, item) in patchBarItems.enumerated() {
            let patch = patch(for: item)
            print("🏛️ PatchSelectorViewModel - Loaded patchBarItem \(index+1)/(\(patchBarItems.count)): \(String(describing: patch?.name)). id: \(item.patchID).  type: \(item.type)")
        }

        // Select current patch if found, otherwise select the first
        if let currentID = PatchManager.shared.currentPatchID,
           let item = self.patchBarItems.first(where: { $0.patchID == currentID }) {
            selectPatch(item)
        } else if let first = self.patchBarItems.first {
            PatchManager.shared.currentPatchID = first.patchID
            selectPatch(first)
        }
    }

    func selectPatch(_ item: PatchBarItem) {
        // remember that item has item.id which is it's id in the patch bar, and patch.id which is it's PatchManager id
        print("🏛️ PatchSelectorViewModel.selectPatch - patchID: \(item.patchID)")
        
        // Refresh patchBarItems from latest data
        self.patchBarItems = generatePatchBarItems()

        // Retrieve the actual PatchSettings
        guard let patchSettings = patch(for: item) else { return }

        switch item.type {
        case .defaultOriginal, .defaultEdited:
            if patchSettings.id != currentEditedDefaultPatchID {
                if let oldID = currentEditedDefaultPatchID {
                    print("🏛️ PatchSelectorViewModel.selectPatch - Calling PatchManager.clearEditedDefaultPatch(forID:) for \(oldID).")
                    PatchManager.shared.clearEditedDefaultPatch(forID: oldID)
                }
                print("🏛️ PatchSelectorViewModel.selectPatch - setting currentEditedDefaultPatchID to \(patchSettings.id).")
                currentEditedDefaultPatchID = patchSettings.id
            }
            print("🏛️ PatchSelectorViewModel.selectPatch calling VoiceConductorManager.setActiveConductor(settings:) and PatchManager.currentPatchID set to \(patchSettings.id).")
            VoiceConductorManager.shared.setActiveConductor(settings: patchSettings)
            PatchManager.shared.currentPatchID = patchSettings.id
        case .saved:
            if let oldID = currentEditedDefaultPatchID {
                print("🏛️ PatchSelectorViewModel.selectPatch calling PatchManager.clearEditedDefaultPatch(forID:) and currentEditedDefaultPatchID set to nil.")
                PatchManager.shared.clearEditedDefaultPatch(forID: oldID)
                currentEditedDefaultPatchID = nil
            }
            print("🏛️ PatchSelectorViewModel.selectPatch calling PatchManager.save(settings:) and VoiceConductorManager.setActiveConductor(settings:)")
            VoiceConductorManager.shared.setActiveConductor(settings: patchSettings)
            PatchManager.shared.currentPatchID = patchSettings.id
        }
        self.selectedPatchBarItemID = item.id
        onPatchSelected?(patchSettings)
    }

    /// Call this to explicitly reset the current default patch back to its defaults
    func resetDefaultPatch() {
        if let oldID = currentEditedDefaultPatchID {
            print("🏛️ PatchSelectorViewModel.resetDefaultPatch - Clearing edited default patch for \(oldID)")
            PatchManager.shared.clearEditedDefaultPatch(forID: oldID)
            
            currentEditedDefaultPatchID = nil
        }
    }
}

class PatchSelectorView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onPatchSelected: ((PatchSettings) -> Void)?

    var viewModel: PatchSelectorViewModel? {
        didSet {
            viewModel?.$patchBarItems
                .receive(on: RunLoop.main)
                .sink { [weak self] items in
                    self?.updatePatches(items)
                }
                .store(in: &cancellables)
        }
    }
    private var cancellables = Set<AnyCancellable>()

    private var savedStartIndex: Int?
    private var savedPatchRange: Range<Int>?
    private let collectionView: UICollectionView

    // Store the current PatchBarItems for display
    private var patchBarItems: [PatchSelectorViewModel.PatchBarItem] = []

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12
        layout.sectionInsetReference = .fromSafeArea
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        super.init(frame: frame)
        
        DispatchQueue.main.async {
            let itemWidth: CGFloat = 64
            let sideInset = (self.bounds.width - itemWidth) / 2
            layout.sectionInset = UIEdgeInsets(top: 0, left: sideInset, bottom: 0, right: sideInset)
            self.collectionView.collectionViewLayout.invalidateLayout()
        }
         
        self.backgroundColor = .clear
        self.isOpaque = false

        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(PatchCell.self, forCellWithReuseIdentifier: "PatchCell")

        // Add long press gesture recognizer for deleting patches
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPressGesture)

        addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updatePatches(_ items: [PatchSelectorViewModel.PatchBarItem]) {
        self.patchBarItems = items
        savedStartIndex = items.firstIndex(where: { $0.type == .saved })
        if let start = savedStartIndex {
            savedPatchRange = start..<items.count
        } else {
            savedPatchRange = nil
        }
        // Remove any lingering saved background before reload
        if let savedBackground = collectionView.viewWithTag(999) {
            savedBackground.removeFromSuperview()
        }
        collectionView.reloadData()

        // Scroll the selected patch to the center after reload
        if let selectedID = viewModel?.selectedPatchBarItemID,
           let index = items.firstIndex(where: { $0.id == selectedID }) {
            let selectedIndexPath = IndexPath(item: index, section: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.collectionView.selectItem(at: selectedIndexPath, animated: false, scrollPosition: [])
                self.centerItem(at: selectedIndexPath, animated: false)
                self.collectionView.reloadItems(at: [selectedIndexPath])
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return patchBarItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PatchCell", for: indexPath) as? PatchCell else {
            return UICollectionViewCell()
        }
        let item = patchBarItems[indexPath.item]
        let patch = viewModel?.patch(for: item)
        if let patch = patch {
            cell.configure(with: patch)
        }
        if let selectedID = viewModel?.selectedPatchBarItemID {
            cell.setSelected(item.id == selectedID)
        } else {
            cell.setSelected(false)
        }
        cell.backgroundColor = .clear
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("👉 🏛️ PatchSelectorViewModel.collectionView didSelectItemAt indexPath: \(indexPath)")
        let item = patchBarItems[indexPath.item]
        let patch = viewModel?.patch(for: item)
        if let patch = patch {
            if let selectedID = PatchManager.shared.currentPatchID,
               let currentPatch = PatchManager.shared.getPatchData(forID: selectedID) {
                // Find the current PatchBarItem for the selectedID
                if let vm = viewModel, let currentItem = patchBarItems.first(where: { $0.patchID == selectedID }) {
                    switch currentItem.type {
                    case .saved:
                        // the patch we're switching from is a saved (non-default) patch
                        print("🏛️ PatchSelectorViewModel.didSelectItemAt saving currentPatch (we're saving a non-default patch)")
                        PatchManager.shared.save(settings: currentPatch)
                    case .defaultOriginal, .defaultEdited:
                        // the patch we're switching from is a default patch
                        // Reset current patch back to default
                        vm.resetDefaultPatch()
                    }
                }
            }
            print("🏛️ PatchSelectorViewModel.didSelectItemAt calling onPatchSelected?()")
            onPatchSelected?(patch)
            logPatches(patch, label: "🏛️ PatchSelectorViewModel.didSelectItemAt calling viewModel?.selectPatch()")
            viewModel?.selectPatch(item)
            viewModel?.selectedPatchBarItemID = item.id
        }

        // Reload cells to update selection
        collectionView.reloadData()

        // Center the selected item in the collection view
        centerItem(at: indexPath, animated: true)
    }

    private func centerItem(at indexPath: IndexPath, animated: Bool) {
        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else { return }

        let itemCenter = attributes.center.x
        let collectionCenter = collectionView.bounds.width / 2
        let desiredOffsetX = itemCenter - collectionCenter

        let minOffsetX: CGFloat = 0
        let maxOffsetX = max(0, collectionView.contentSize.width - collectionView.bounds.width)
        let clampedOffsetX = min(max(minOffsetX, desiredOffsetX), maxOffsetX)

        let newOffset = CGPoint(x: clampedOffsetX, y: 0)
        collectionView.setContentOffset(newOffset, animated: animated)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 64, height: 80)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if let layout = collectionViewLayout as? UICollectionViewFlowLayout {
            return layout.sectionInset
        }
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let savedRange = savedPatchRange, savedRange.contains(indexPath.item) {
            DispatchQueue.main.async {
                if let savedBackground = collectionView.viewWithTag(999) {
                    savedBackground.removeFromSuperview()
                }
                let firstCellFrame = collectionView.layoutAttributesForItem(at: IndexPath(item: savedRange.lowerBound, section: 0))?.frame ?? .zero
                let lastCellFrame = collectionView.layoutAttributesForItem(at: IndexPath(item: savedRange.upperBound - 1, section: 0))?.frame ?? .zero
                let backgroundFrame = firstCellFrame.union(lastCellFrame).insetBy(dx: -6, dy: -6)
                let bgView = UIView(frame: backgroundFrame)
                bgView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
                bgView.layer.cornerRadius = 8
                bgView.clipsToBounds = true
                bgView.tag = 999
                collectionView.insertSubview(bgView, at: 0)
            }
        }
    }
    
    @objc private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began else { return }

        let point = gestureRecognizer.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }

        print("👉 🏛️ PatchSelectorViewModel long press on \(indexPath.item)")
        let item = patchBarItems[indexPath.item]

        let canRenameAndDelete: Bool

        switch item.type {
        case .defaultOriginal, .defaultEdited:
            let title = "Default Patch Options"
            canRenameAndDelete = false
        case .saved:
            let title = "Saved Patch Options"
            canRenameAndDelete = true
        }

        if let viewController = self.window?.rootViewController {
            guard let cell = collectionView.cellForItem(at: indexPath) else { return }
            AlertHelper.showPatchOptionsMenu(
                presenter: viewController,
                sourceView: cell,
                isDefault: !canRenameAndDelete,
                onRename: {
                    AlertHelper.promptForPatchName(presenter: viewController) { newName in
                        guard let newName = newName,
                              var patch = self.viewModel?.patch(for: item) else { return }
                        patch.name = newName
                        PatchManager.shared.save(settings: patch)
                        DispatchQueue.main.async {
                            self.viewModel?.loadPatches()
                        }
                    }
                },
                onSaveAs: {
                    AlertHelper.promptForPatchName(presenter: viewController) { newName in
                        guard let newName = newName,
                              let currentID = PatchManager.shared.currentPatchID,
                              let patch = PatchManager.shared.getPatchData(forID: currentID) else { return }

                        var duplicated = patch
                        duplicated.id = 0
                        duplicated.name = newName
                        let newID = PatchManager.shared.save(settings: duplicated)
                        PatchManager.shared.currentPatchID = newID

                        DispatchQueue.main.async {
                            self.viewModel?.loadPatches()
                            if let newItem = self.patchBarItems.first(where: { $0.patchID == newID }),
                               let index = self.patchBarItems.firstIndex(where: { $0.patchID == newID }) {
                                print("🏛️ PatchSelectorViewModel: Duplicated patch, selecting new one... newID: \(newID), newItem: \(newItem), newIndex: \(index)")
                                self.viewModel?.selectPatch(newItem)
                                let newIndexPath = IndexPath(item: index, section: 0)
                                self.collectionView.selectItem(at: newIndexPath, animated: true, scrollPosition: [])
                                self.centerItem(at: newIndexPath, animated: true)
                            }
                        }
                    }
                },
                onDelete: {
                    PatchManager.shared.deletePatch(forID: item.patchID)
                    DispatchQueue.main.async {
                        let deletedPatchID = item.patchID
                        let isDeletingCurrentPatch = PatchManager.shared.currentPatchID == deletedPatchID

                        self.viewModel?.loadPatches()

                        if isDeletingCurrentPatch {
                            print("🏛️ PatchSelectorViewModel - Deleted current patch; selecting previous one if possible.")
                            if let deletedIndex = self.patchBarItems.firstIndex(where: { $0.patchID == deletedPatchID }) {
                                let fallbackIndex = max(0, deletedIndex - 1)
                                guard self.patchBarItems.indices.contains(fallbackIndex) else { return }
                                let fallbackItem = self.patchBarItems[fallbackIndex]
                                self.viewModel?.selectPatch(fallbackItem)
                            } else if let fallbackItem = self.patchBarItems.first {
                                self.viewModel?.selectPatch(fallbackItem)
                            }
                        }
                    }
                }
            )
        }
    }
}

class PatchCell: UICollectionViewCell {
    let imageView = UIImageView()
    let nameLabel = UILabel()
    private let selectionIndicatorView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        contentView.addSubview(nameLabel)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 24 // Half of width/height to make it circular
        imageView.layer.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        contentView.insertSubview(selectionIndicatorView, belowSubview: imageView)
        selectionIndicatorView.layer.borderColor = UIColor.white.cgColor
        selectionIndicatorView.layer.borderWidth = 4
        selectionIndicatorView.layer.cornerRadius = 26
        selectionIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        selectionIndicatorView.isHidden = true

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 48),
            imageView.heightAnchor.constraint(equalToConstant: 48),

            selectionIndicatorView.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            selectionIndicatorView.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            selectionIndicatorView.widthAnchor.constraint(equalToConstant: 56),
            selectionIndicatorView.heightAnchor.constraint(equalToConstant: 56),

            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 10)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with item: PatchSettings) {
        nameLabel.text = item.name

        if let cgImage = item.image.cgImage {
            imageView.image = item.image
            imageView.backgroundColor = .clear
        } else {
            imageView.image = nil
            imageView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        }

        // Removed backgroundColor setting here; handled in cellForItemAt
    }

    func setSelected(_ selected: Bool) {
        selectionIndicatorView.isHidden = !selected
    }
    
    
}

// SwiftUI bridge for PatchSelectorView
struct PatchSelectorViewRepresentable: UIViewRepresentable {
    let viewModel: PatchSelectorViewModel

    func makeUIView(context: Context) -> PatchSelectorView {
        let view = PatchSelectorView()
        view.viewModel = viewModel
        return view
    }

    func updateUIView(_ uiView: PatchSelectorView, context: Context) {
        // Nothing needed here yet
    }
}

    
