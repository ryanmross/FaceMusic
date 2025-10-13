//
//  PatchSelectorView.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/27/25.
//

import UIKit
import Combine
import SwiftUI

// MARK: - Patch Selector (ViewModel + View + Cell + SwiftUI bridge)

// MARK: ViewModel
final class PatchSelectorViewModel: ObservableObject {
    // MARK: Types
    enum PatchType { case defaultOriginal, defaultEdited, saved }
    struct PatchBarItem: Identifiable { let id: Int; let type: PatchType; let patchID: Int }

    // MARK: Public API
    var onPatchSelected: ((PatchSettings) -> Void)?
    @Published var patchBarItems: [PatchBarItem] = []
    @Published var selectedPatchBarItemID: Int?

    // MARK: State
    private static let allDefaultPatches: [PatchSettings] = VoiceConductorRegistry.all.flatMap { $0.defaultPatches }
    private var currentEditedDefaultPatchID: Int?

    // MARK: Loading
    func loadPatches() {
        patchBarItems = generatePatchBarItems()

        for (index, item) in patchBarItems.enumerated() {
            let patch = patch(for: item)
            
            Log.line(actor: "🏛️ PatchSelectorViewModel", fn: "loadPatches", "Loaded patchBarItem \(index+1)/(\(patchBarItems.count)): \(String(describing: patch?.name)). id: \(item.patchID).  type: \(item.type)")
        }

        // Select current patch if found, otherwise select the first
        if let currentID = PatchManager.shared.currentPatchID,
           let item = patchBarItems.first(where: { $0.patchID == currentID }) {
            selectPatch(item)
        } else if let first = patchBarItems.first {
            PatchManager.shared.currentPatchID = first.patchID
            selectPatch(first)
        }
    }

    // MARK: Selection
    func selectPatch(_ item: PatchBarItem) {
        Log.line(actor: "🏛️ PatchSelectorViewModel", fn: "selectPatch", "patchID: \(item.patchID)")

        // Refresh from latest data so badges/types stay in sync
        patchBarItems = generatePatchBarItems()

        guard let patchSettings = patch(for: item) else { return }

        switch item.type {
        case .defaultOriginal, .defaultEdited:
            if patchSettings.id != currentEditedDefaultPatchID {
                if let oldID = currentEditedDefaultPatchID {
                    
                    Log.line(actor: "🏛️ PatchSelectorViewModel", fn: "selectPatch", "Calling PatchManager.clearEditedDefaultPatch(forID:) for \(oldID).")
                    PatchManager.shared.clearEditedDefaultPatch(forID: oldID)
                }
                Log.line(actor: "🏛️ PatchSelectorViewModel", fn: "selectPatch", "setting currentEditedDefaultPatchID to \(patchSettings.id).")

                currentEditedDefaultPatchID = patchSettings.id
            }
            
            Log.line(actor: "🏛️ PatchSelectorViewModel", fn: "selectPatch", "calling VoiceConductorManager.setActiveConductor(settings:) and PatchManager.currentPatchID set to \(patchSettings.id).")

            VoiceConductorManager.shared.setActiveConductor(settings: patchSettings)
            PatchManager.shared.currentPatchID = patchSettings.id

        case .saved:
            if let oldID = currentEditedDefaultPatchID {
                
                Log.line(actor: "🏛️ PatchSelectorViewModel", fn: "selectPatch", "calling PatchManager.clearEditedDefaultPatch(forID:) and currentEditedDefaultPatchID set to nil.")

                PatchManager.shared.clearEditedDefaultPatch(forID: oldID)
                currentEditedDefaultPatchID = nil
            }
            
            Log.line(actor: "🏛️ PatchSelectorViewModel", fn: "selectPatch", "calling PatchManager.save(settings:) and VoiceConductorManager.setActiveConductor(settings:)")

            VoiceConductorManager.shared.setActiveConductor(settings: patchSettings)
            PatchManager.shared.currentPatchID = patchSettings.id
        }

        selectedPatchBarItemID = item.id
        onPatchSelected?(patchSettings)
    }

    /// Call this to explicitly reset the current default patch back to its defaults
    func resetDefaultPatch() {
        if let oldID = currentEditedDefaultPatchID {
            
            Log.line(actor: "🏛️ PatchSelectorViewModel", fn: "resetDefaultPatch", "Clearing edited default patch for \(oldID)")

            PatchManager.shared.clearEditedDefaultPatch(forID: oldID)
            currentEditedDefaultPatchID = nil
        }
    }

    // MARK: Helpers
    func patch(for item: PatchBarItem) -> PatchSettings? {
        switch item.type {
        case .saved, .defaultEdited:
            return PatchManager.shared.getPatchData(forID: item.patchID)
        case .defaultOriginal:
            return Self.allDefaultPatches.first(where: { $0.id == item.patchID })
        }
    }

    private func generatePatchBarItems() -> [PatchBarItem] {
        
        // ask PatchManager for the saved patches, combine with allDefaultPatches and return an array of PatchBarItems with the patch info in it
        
        let savedPatchIDs = PatchManager.shared.listPatches()
        let savedPatches = savedPatchIDs.compactMap { PatchManager.shared.getPatchData(forID: $0) }
        let savedPatchMap = Dictionary(uniqueKeysWithValues: savedPatches.map { ($0.id, $0) })

        var items: [PatchBarItem] = []
        var id = 0

        // Defaults
        for defaultPatch in Self.allDefaultPatches {
            let patchID = defaultPatch.id
            let type: PatchType = savedPatchMap[patchID] != nil ? .defaultEdited : .defaultOriginal
            items.append(PatchBarItem(id: id, type: type, patchID: patchID))
            id += 1
        }

        // Saved (non-default)
        for savedPatch in savedPatches where savedPatch.id >= 0 {
            items.append(PatchBarItem(id: id, type: .saved, patchID: savedPatch.id))
            id += 1
        }

        for (index, item) in items.enumerated() {
            Log.line(actor: "🏛️ PatchSelectorViewModel", fn: "generatePatchBarItems", "generated patch bar item \(index): \(item.patchID)")

        }
        return items
    }
}

// MARK: View
final class PatchSelectorView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    // MARK: Constants
    private enum UIConstants {
        static let itemSize = CGSize(width: 64, height: 80)
        static let imageSide: CGFloat = 48
        static let indicatorSide: CGFloat = 56
        static let minPressDuration: TimeInterval = 0.45
        static let spacing: CGFloat = 12
        static let menuCooldown: TimeInterval = 0.6
        static let savedBGTag = 999
    }

    // MARK: API
    var onPatchSelected: ((PatchSettings) -> Void)?

    var viewModel: PatchSelectorViewModel? {
        didSet {
            cancellables.removeAll() // avoid duplicate reloads
            viewModel?.$patchBarItems
                .receive(on: RunLoop.main)
                .sink { [weak self] items in self?.updatePatches(items) }
                .store(in: &cancellables)
        }
    }

    // MARK: State
    private var cancellables = Set<AnyCancellable>()
    private var lastMenuPresentedAt: Date = .distantPast
    private var savedStartIndex: Int?
    private var savedPatchRange: Range<Int>?

    private let collectionView: UICollectionView
    private var patchBarItems: [PatchSelectorViewModel.PatchBarItem] = []

    // MARK: Init
    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = UIConstants.spacing
        layout.sectionInsetReference = .fromSafeArea
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        super.init(frame: frame)

        // Resolve dynamic side inset once we have bounds
        DispatchQueue.main.async {
            let sideInset = (self.bounds.width - UIConstants.itemSize.width) / 2
            layout.sectionInset = UIEdgeInsets(top: 0, left: sideInset, bottom: 0, right: sideInset)
            self.collectionView.collectionViewLayout.invalidateLayout()
        }

        backgroundColor = .clear
        isOpaque = false

        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(PatchCell.self, forCellWithReuseIdentifier: PatchCell.reuseID)

        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = UIConstants.minPressDuration
        longPressGesture.cancelsTouchesInView = true
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

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Updates
    func updatePatches(_ items: [PatchSelectorViewModel.PatchBarItem]) {
        patchBarItems = items
        savedStartIndex = items.firstIndex(where: { $0.type == .saved })
        savedPatchRange = savedStartIndex.map { $0..<items.count }

        // Remove any lingering saved background before reload
        collectionView.viewWithTag(UIConstants.savedBGTag)?.removeFromSuperview()
        collectionView.reloadData()

        // Keep selection centered
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

    // MARK: UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { patchBarItems.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PatchCell.reuseID, for: indexPath) as? PatchCell else {
            return UICollectionViewCell()
        }
        let item = patchBarItems[indexPath.item]
        if let patch = viewModel?.patch(for: item) { cell.configure(with: patch) }
        let isSelected = (viewModel?.selectedPatchBarItemID == item.id)
        cell.setSelected(isSelected)
        cell.backgroundColor = .clear
        return cell
    }

    // MARK: UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        Log.line(actor: "👉 🏛️ PatchSelectorViewModel", fn: "didSelectItemAt", "indexPath: \(indexPath)")

        let item = patchBarItems[indexPath.item]

        if let selectedID = PatchManager.shared.currentPatchID,
           let currentPatch = PatchManager.shared.getPatchData(forID: selectedID),
           let vm = viewModel,
           let currentItem = patchBarItems.first(where: { $0.patchID == selectedID }) {
            switch currentItem.type {
            case .saved:
                
                Log.line(actor: "🏛️ PatchSelectorViewModel", fn: "didSelectItemAt", "saving currentPatch (we're saving a non-default patch)")

                PatchManager.shared.save(settings: currentPatch)
            case .defaultOriginal, .defaultEdited:
                vm.resetDefaultPatch()
            }
        }

        if let patch = viewModel?.patch(for: item) {
            
            Log.line(actor: "🏛️ PatchSelectorViewModel", fn: "didSelectItemAt", "calling onPatchSelected?()")

            onPatchSelected?(patch)
            logPatches(patch, label: "🏛️ PatchSelectorViewModel.didSelectItemAt calling viewModel?.selectPatch()")
            viewModel?.selectPatch(item)
            viewModel?.selectedPatchBarItemID = item.id
        }

        collectionView.reloadData()
        centerItem(at: indexPath, animated: true)
    }

    // MARK: Layout helpers
    private func centerItem(at indexPath: IndexPath, animated: Bool) {
        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else { return }
        let itemCenter = attributes.center.x
        let collectionCenter = collectionView.bounds.width / 2
        let desiredOffsetX = itemCenter - collectionCenter
        let minOffsetX: CGFloat = 0
        let maxOffsetX = max(0, collectionView.contentSize.width - collectionView.bounds.width)
        let clampedOffsetX = min(max(minOffsetX, desiredOffsetX), maxOffsetX)
        collectionView.setContentOffset(CGPoint(x: clampedOffsetX, y: 0), animated: animated)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        UIConstants.itemSize
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        (collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset ?? .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let savedRange = savedPatchRange, savedRange.contains(indexPath.item) else { return }
        DispatchQueue.main.async {
            collectionView.viewWithTag(UIConstants.savedBGTag)?.removeFromSuperview()
            let firstFrame = collectionView.layoutAttributesForItem(at: IndexPath(item: savedRange.lowerBound, section: 0))?.frame ?? .zero
            let lastFrame = collectionView.layoutAttributesForItem(at: IndexPath(item: savedRange.upperBound - 1, section: 0))?.frame ?? .zero
            let backgroundFrame = firstFrame.union(lastFrame).insetBy(dx: -6, dy: -6)
            let bgView = UIView(frame: backgroundFrame)
            bgView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
            bgView.layer.cornerRadius = 8
            bgView.clipsToBounds = true
            bgView.tag = UIConstants.savedBGTag
            collectionView.insertSubview(bgView, at: 0)
        }
    }

    // MARK: Gestures
    @objc private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began else { return }
        guard !collectionView.isDragging, !collectionView.isDecelerating else { return }

        // Debounce rapid repeats
        let now = Date()
        guard now.timeIntervalSince(lastMenuPresentedAt) > UIConstants.menuCooldown else { return }
        lastMenuPresentedAt = now

        let point = gestureRecognizer.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }

        
        Log.line(actor: "👉 🏛️ PatchSelectorViewModel", fn: "handleLongPress", "long press on \(indexPath.item)")

        let item = patchBarItems[indexPath.item]
        let canRenameAndDelete = (item.type == .saved)

        guard let presenterVC = (self.nearestViewController()?.topMostPresentedController()) ?? self.window?.rootViewController,
              let cell = collectionView.cellForItem(at: indexPath) else { return }

        DispatchQueue.main.async {
            AlertHelper.showPatchOptionsMenu(
                presenter: presenterVC,
                sourceView: cell,
                isDefault: !canRenameAndDelete,
                onRename: {
                    AlertHelper.promptForPatchName(presenter: presenterVC) { newName in
                        guard let newName = newName, var patch = self.viewModel?.patch(for: item) else { return }
                        patch.name = newName
                        PatchManager.shared.save(settings: patch)
                        DispatchQueue.main.async { self.viewModel?.loadPatches() }
                    }
                },
                onSaveAs: {
                    AlertHelper.promptForPatchName(presenter: presenterVC) { newName in
                        guard let newName = newName,
                              let newID = PatchManager.shared.duplicatePatch(from: item.patchID, as: newName) else { return }

                        PatchManager.shared.currentPatchID = newID

                        DispatchQueue.main.async {
                            self.viewModel?.loadPatches()
                            if let newItem = self.patchBarItems.first(where: { $0.patchID == newID }),
                               let index = self.patchBarItems.firstIndex(where: { $0.patchID == newID }) {
                                
                                Log.line(actor: "🏛️ PatchSelectorViewModel", fn: "handleLongPress", "Duplicated long-pressed patch via PatchManager, selecting new one... newID: \(newID), newItem: \(newItem), newIndex: \(index)")

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
                            
                            Log.line(actor: "🏛️ PatchSelectorViewModel", fn: "handleLongPress", "Deleted current patch; selecting previous one if possible.")
                            
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

// MARK: Cell
final class PatchCell: UICollectionViewCell {
    static let reuseID = "PatchCell"

    // MARK: Subviews
    private let imageView = UIImageView()
    private let nameLabel = UILabel()
    private let selectionIndicatorView = UIView()

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(imageView)
        contentView.addSubview(nameLabel)
        contentView.insertSubview(selectionIndicatorView, belowSubview: imageView)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 24
        imageView.layer.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        selectionIndicatorView.layer.borderColor = UIColor.white.cgColor
        selectionIndicatorView.layer.borderWidth = 4
        selectionIndicatorView.layer.cornerRadius = 26
        selectionIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        selectionIndicatorView.isHidden = true

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 10)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2

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
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Configuration
    func configure(with item: PatchSettings) {
        nameLabel.text = item.name
        if item.image.cgImage != nil {
            imageView.image = item.image
            imageView.backgroundColor = .clear
        } else {
            imageView.image = nil
            imageView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        }
    }

    func setSelected(_ selected: Bool) { selectionIndicatorView.isHidden = !selected }
}

// MARK: SwiftUI bridge
struct PatchSelectorViewRepresentable: UIViewRepresentable {
    let viewModel: PatchSelectorViewModel
    func makeUIView(context: Context) -> PatchSelectorView { let v = PatchSelectorView(); v.viewModel = viewModel; return v }
    func updateUIView(_ uiView: PatchSelectorView, context: Context) { }
}

// MARK: - Helpers (UIView/UIViewController)
extension UIView {
    /// Walk the responder chain to find the nearest owning view controller
    func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder { if let vc = r as? UIViewController { return vc }; responder = r.next }
        return nil
    }
}

extension UIViewController {
    /// Returns the top-most presented view controller starting from self
    func topMostPresentedController() -> UIViewController {
        var top = self
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}


    
