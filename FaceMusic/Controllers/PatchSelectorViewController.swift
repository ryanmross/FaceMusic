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
    struct PatchBarItem {
        let patchBarID: Int
        let isDefault: Bool
        let patchID: Int
    }

    var onPatchSelected: ((PatchSettings) -> Void)?
    @Published var patchBarItems: [PatchBarItem] = []

    private var currentEditedDefaultPatchID: Int?

    private func generatePatchBarItems() -> [PatchBarItem] {
        let defaultPatches = VoiceConductorRegistry.all.flatMap { $0.defaultPatches }
        let savedPatchIDs = PatchManager.shared.listPatches()
        let savedPatches = savedPatchIDs.compactMap { PatchManager.shared.getPatchData(forID: $0) }

        var items: [PatchBarItem] = []
        var patchBarID = 0
        for patch in defaultPatches {
            items.append(PatchBarItem(patchBarID: patchBarID, isDefault: true, patchID: patch.id))
            patchBarID += 1
        }
        for patch in savedPatches {
            items.append(PatchBarItem(patchBarID: patchBarID, isDefault: false, patchID: patch.id))
            patchBarID += 1
        }
        return items
    }

    func patch(for item: PatchBarItem) -> PatchSettings? {
        return item.isDefault
            ? VoiceConductorRegistry.all.flatMap { $0.defaultPatches }.first(where: { $0.id == item.patchID })
            : PatchManager.shared.getPatchData(forID: item.patchID)
    }

    func loadPatches() {
        self.patchBarItems = generatePatchBarItems()

        for (index, item) in patchBarItems.enumerated() {
            let patch = patch(for: item)
            print("🏛️ PatchSelectorViewModel - Loaded patchBarItem \(index+1)/(\(patchBarItems.count)): \(String(describing: patch?.name)). id: \(item.patchID).  isDefault: \(item.isDefault)")
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
        // Refresh patchBarItems from latest data
        self.patchBarItems = generatePatchBarItems()

        // Retrieve the actual PatchSettings
        guard let patchSettings = patch(for: item) else { return }

        if item.isDefault {
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
        } else {
            if let oldID = currentEditedDefaultPatchID {
                print("🏛️ PatchSelectorViewModel.selectPatch calling PatchManager.clearEditedDefaultPatch(forID:) and currentEditedDefaultPatchID set to nil.")
                PatchManager.shared.clearEditedDefaultPatch(forID: oldID)
                currentEditedDefaultPatchID = nil
            }
            print("🏛️ PatchSelectorViewModel.selectPatch calling PatchManager.save(settings:) and VoiceConductorManager.setActiveConductor(settings:)")
            VoiceConductorManager.shared.setActiveConductor(settings: patchSettings)
            PatchManager.shared.currentPatchID = patchSettings.id
        }
        onPatchSelected?(patchSettings)
    }

    /// Call this to explicitly clear or save edits to the current default patch, if needed.
    func finalizeCurrentPatchEdits() {
        if let oldID = currentEditedDefaultPatchID {
            print("🏛️ PatchSelectorViewModel.finalizeCurrentPatchEdits - Clearing edited default patch for \(oldID)")
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
    private var selectedIndexPath: IndexPath?

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
        savedStartIndex = items.firstIndex(where: { !$0.isDefault })
        if let start = savedStartIndex {
            savedPatchRange = start..<items.count
        } else {
            savedPatchRange = nil
        }
        if let selectedID = PatchManager.shared.currentPatchID,
           let index = items.firstIndex(where: { $0.patchID == selectedID }) {
            selectedIndexPath = IndexPath(item: index, section: 0)
        }
        collectionView.reloadData()

        // Scroll the selected patch to the center after reload
        
        if let selectedIndexPath = selectedIndexPath {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("🏛️ PatchSelectorViewModel.updatePatches() 🔄 updatePatches centering selected patch at indexPath: \(selectedIndexPath)")
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
        let patch = viewModel?.patch(for: item) ?? {
            if item.isDefault {
                return VoiceConductorRegistry.all.flatMap { $0.defaultPatches }.first(where: { $0.id == item.patchID })
            } else {
                return PatchManager.shared.getPatchData(forID: item.patchID)
            }
        }()
        if let patch = patch {
            cell.configure(with: patch)
        }
        cell.setSelected(indexPath == selectedIndexPath)
        cell.backgroundColor = .clear
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("👉 🏛️ PatchSelectorViewModel.collectionView didSelectItemAt indexPath: \(indexPath)")
        let item = patchBarItems[indexPath.item]
        let patch = viewModel?.patch(for: item) ?? {
            if item.isDefault {
                return VoiceConductorRegistry.all.flatMap { $0.defaultPatches }.first(where: { $0.id == item.patchID })
            } else {
                return PatchManager.shared.getPatchData(forID: item.patchID)
            }
        }()
        if let patch = patch {
            if let selectedID = PatchManager.shared.currentPatchID,
               let currentPatch = PatchManager.shared.getPatchData(forID: selectedID) {
                if !currentPatch.isDefault {
                    PatchManager.shared.save(settings: currentPatch)
                } else if let vm = viewModel, let currentItem = patchBarItems.first(where: { $0.patchID == selectedID }), currentItem.isDefault {
                    // Save or clear edits to the default patch, if needed
                    vm.finalizeCurrentPatchEdits()
                }
            }
            print("🏛️ PatchSelectorViewModel.didSelectItemAt calling onPatchSelected?()")
            onPatchSelected?(patch)
            logPatches(patch, label: "🏛️ PatchSelectorViewModel.didSelectItemAt calling viewModel?.selectPatch()")
            viewModel?.selectPatch(item)
        }

        let previouslySelected = selectedIndexPath
        selectedIndexPath = indexPath
        var indexPathsToReload = [indexPath]
        if let previous = previouslySelected, previous != indexPath {
            indexPathsToReload.append(previous)
        }
        collectionView.reloadItems(at: indexPathsToReload)

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
