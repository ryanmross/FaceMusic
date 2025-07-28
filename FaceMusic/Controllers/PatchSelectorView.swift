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
    let id: String
    let name: String
    let image: UIImage
    let isDefault: Bool
}

class PatchSelectorViewModel: ObservableObject {
    var onPatchSelected: ((PatchItem) -> Void)?
    @Published var patches: [PatchItem] = []
    @Published var selectedPatchID: String?

    func loadPatches() {
        let defaultPatches: [PatchItem] = VoiceConductorRegistry.all.flatMap { descriptor in
            descriptor.defaultPatches.map {
                let image = $0.imageName.flatMap { UIImage(named: $0) } ?? UIImage()
                return PatchItem(id: String($0.id), name: $0.name ?? "Default", image: image, isDefault: true)
            }
        }

        let savedPatches = PatchManager.shared.listPatches().compactMap { patchID -> PatchItem? in
            guard let patch = PatchManager.shared.getPatchData(forID: patchID) else { return nil }
            let image = patch.imageName.flatMap { UIImage(named: $0) } ?? UIImage()
            return PatchItem(id: String(patch.id), name: patch.name ?? "Custom", image: image, isDefault: false)
        }

        self.patches = defaultPatches + savedPatches

        if selectedPatchID == nil {
            if let currentID = PatchManager.shared.currentPatchID {
                selectedPatchID = String(currentID)
            } else if let first = (defaultPatches + savedPatches).first {
                selectedPatchID = first.id
            }
        }
    }

    func selectPatch(_ patch: PatchItem) {
        
        selectedPatchID = patch.id
        if patch.isDefault {
            if let descriptor = VoiceConductorRegistry.descriptor(containingPatchID: patch.id) {
                let settings = descriptor.defaultPatches.first { String($0.id) == patch.id }
                if let patch = settings {
                    PatchManager.shared.save(settings: patch)
                    VoiceConductorManager.shared.setActiveConductor(settings: patch)
                }
            }
        } else {
            if let patchID = Int(patch.id), let patch = PatchManager.shared.getPatchData(forID: patchID) {
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
            layout.sectionInset = UIEdgeInsets(top: 0, left: max(sideInset, 0), bottom: 0, right: max(sideInset, 0))
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
        if let selectedID = viewModel?.selectedPatchID,
           let index = patches.firstIndex(where: { $0.id == selectedID }) {
            selectedIndexPath = IndexPath(item: index, section: 0)
        }
        collectionView.reloadData()

        // Scroll the selected patch to the center after reload
        if let selectedIndexPath = selectedIndexPath {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.centerItem(at: selectedIndexPath, animated: false)
                // Explicitly reload selected cell to ensure ring is shown
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
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("👉 PatchSelectorView didSelectItemAt: \(indexPath), named \(patchItems[indexPath.item].name)")
        
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
        selectionIndicatorView.layer.borderWidth = 2
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
            selectionIndicatorView.widthAnchor.constraint(equalToConstant: 52),
            selectionIndicatorView.heightAnchor.constraint(equalToConstant: 52),

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
