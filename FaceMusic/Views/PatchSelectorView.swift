//
//  PatchSelectorView.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/27/25.
//

import UIKit
import Combine
import SwiftUI

struct PatchItem {
    let id: Int
    let name: String
    let image: UIImage
    let isDefault: Bool
    let conductorID: String
}

class PatchSelectorViewModel: ObservableObject {
    var onPatchSelected: ((PatchItem) -> Void)?
    @Published var patches: [PatchItem] = []
    @Published var selectedPatchID: Int?

    private var currentEditedDefaultPatchID: Int?

    func loadPatches() {
        print("🏛️ PatchSelectorViewModel.loadPatches() started.  Loading defaultPatches")
        let defaultPatches: [PatchItem] = VoiceConductorRegistry.all.flatMap { descriptor in
            descriptor.defaultPatches.map {
                let image = $0.imageName.flatMap { UIImage(named: $0) } ?? UIImage()
                return PatchItem(id: $0.id, name: $0.name ?? "Default", image: image, isDefault: true, conductorID: $0.conductorID)
            }
        }
        
        print("🏛️ PatchSelectorViewModel.loadPatches() loading savedPatches")
        
        let defaultPatchIDs = Set(defaultPatches.map { $0.id })
        let savedPatches = PatchManager.shared.listPatches().compactMap { patchID -> PatchItem? in
            guard !defaultPatchIDs.contains(patchID),
                  let patch = PatchManager.shared.getPatchData(forID: patchID) else { return nil }
            let image = patch.imageName.flatMap { UIImage(named: $0) } ?? UIImage()
            // For saved patches, conductorID is not available, so set to empty string
            return PatchItem(id: patch.id, name: patch.name ?? "Custom", image: image, isDefault: false, conductorID: "")
        }
        
        print("🏛️ PatchSelectorViewModel.loadPatches(): Loaded \(defaultPatches.count) default patches and \(savedPatches.count) saved patches into self.patches.  selectedPatchID: \(String(describing: selectedPatchID))")
        
        self.patches = defaultPatches + savedPatches

        if selectedPatchID == nil {
            if let currentID = PatchManager.shared.currentPatchID {
                selectedPatchID = currentID
                if let patch = (defaultPatches + savedPatches).first(where: { $0.id == selectedPatchID }) {
                    selectPatch(patch)
                }
            } else if let first = (defaultPatches + savedPatches).first {
                selectedPatchID = first.id
                selectPatch(first)
            }
        }
    }

    func selectPatch(_ patch: PatchItem) {
        selectedPatchID = patch.id
        if patch.isDefault {
            if patch.id != currentEditedDefaultPatchID {
                if let oldID = currentEditedDefaultPatchID {
                    PatchManager.shared.clearEditedDefaultPatch(forID: oldID)
                }
                currentEditedDefaultPatchID = patch.id
            }
            if let descriptor = VoiceConductorRegistry.descriptor(for: patch.conductorID) {
                if let settings = descriptor.defaultPatches.first(where: { $0.id == patch.id }) {
                    print("🏛️ PatchSelectorViewModel.selectPatch() 🎯 patch.isDefault = True.  Selected default patch: \(settings.name ?? "") (ID: \(settings.id)) with conductorID: \(settings.conductorID) ")
                    if let scaleMask = settings.scaleMask {
                        let scaleNotes = MusicBrain.pitchClasses(fromMask: scaleMask)
                        print("🎯 scaleMask scale notes: \(scaleNotes)")
                    } else {
                        print("🎯 scaleMask is nil")
                    }
                    logPatches(settings, label: "PatchSelectorViewModel.selectPatch() 📥🎯 Patch Settings that we're putting into VoiceConductorManager.shared.setActiveConductor")
                    //PatchManager.shared.save(settings: settings)
                    VoiceConductorManager.shared.setActiveConductor(settings: settings)
                    PatchManager.shared.currentPatchID = settings.id
                }
            }
        } else {
            print("🏛️ PatchSelectorViewModel.selectPatch() 🎯 patch.isDefault = False")
            if let oldID = currentEditedDefaultPatchID {
                print("🎯 calling PatchManager.shared.clearEditedDefaultPatch for oldID: \(oldID)")
                PatchManager.shared.clearEditedDefaultPatch(forID: oldID)
                currentEditedDefaultPatchID = nil
            }
            if let patch = PatchManager.shared.getPatchData(forID: patch.id) {
                print("🎯 Selected saved patch: \(patch.name ?? "") (ID: \(patch.id))")
                print("🎯 Patch Settings: \(patch)")
                PatchManager.shared.save(settings: patch)
                VoiceConductorManager.shared.setActiveConductor(settings: patch)
            }
        }
        onPatchSelected?(patch)
    }
}

class PatchSelectorView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onPatchSelected: ((PatchItem) -> Void)?

    var viewModel: PatchSelectorViewModel? {
        didSet {
            viewModel?.$patches
                .receive(on: RunLoop.main)
                .sink { [weak self] patches in
                    self?.updatePatches(patches)
                }
                .store(in: &cancellables)
        }
    }
    private var cancellables = Set<AnyCancellable>()

    private var patchItems: [PatchItem] = []
    private var savedStartIndex: Int?
    private var savedPatchRange: Range<Int>?
    private let collectionView: UICollectionView
    private var selectedIndexPath: IndexPath?

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

    func updatePatches(_ patches: [PatchItem]) {
        self.patchItems = patches
        savedStartIndex = patches.firstIndex(where: { !$0.isDefault })
        if let start = savedStartIndex {
            savedPatchRange = start..<patches.count
        } else {
            savedPatchRange = nil
        }
        if let selectedID = viewModel?.selectedPatchID,
           let index = patches.firstIndex(where: { $0.id == selectedID }) {
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
        return patchItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PatchCell", for: indexPath) as? PatchCell else {
            return UICollectionViewCell()
        }
        let item = patchItems[indexPath.item]
        cell.configure(with: item)
        cell.setSelected(indexPath == selectedIndexPath)
        cell.backgroundColor = .clear
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("🏛️ PatchSelectorViewModel.collectionView didSelectItemAt indexPath: \(indexPath)")

        let selectedItem = patchItems[indexPath.item]
        onPatchSelected?(selectedItem)
        viewModel?.selectPatch(selectedItem)

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
    private let imageView = UIImageView()
    private let nameLabel = UILabel()
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

    func configure(with item: PatchItem) {
        nameLabel.text = item.name

        if let cgImage = item.image.cgImage {
            imageView.image = item.image
            imageView.backgroundColor = .clear
        } else {
            imageView.image = nil
            imageView.backgroundColor = .black
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
