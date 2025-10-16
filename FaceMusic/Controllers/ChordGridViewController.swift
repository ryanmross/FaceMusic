//
//  ChordGridViewController.swift
//  FaceMusic
//
//  Created by Ryan Ross on 10/15/25.
//

import UIKit
import SwiftUI

final class ChordGridViewModel: ObservableObject {
    @Published var items: [ChordItem] = []

    struct ChordItem: Identifiable {
        let id = UUID()
        let key: MusicBrain.NoteName
        let type: MusicBrain.ChordType
        var label: String { "\(key.displayName)\(type.shortDisplayName)" }
    }

    init() {
        generateGrid()
    }

    func refresh() {
        generateGrid()
    }

    func generateGrid() {
        let settings = AppSettings()

        // Determine grid dimensions
        let rowCount = max(1, settings.chordGridRows)

        // Try to determine desired column count; fall back to all 12 if no explicit setting exists
        let columnCount: Int = {
            //if let value = (settings as AnyObject).value(forKey: "chordGridCols") as? Int { return max(1, value) }
            return 12
        }()

        // Determine center key from current patch if available; default to C
        let defaultKey: MusicBrain.NoteName = .C
        let centerKey: MusicBrain.NoteName = {
            guard let id = PatchManager.shared.currentPatchID,
                  let patch = PatchManager.shared.getPatchData(forID: id) else {
                return defaultKey
            }
            return patch.key
        }()

        // Build columns by key using circle of fifths centered on the current patch key
        let keysInFifths = MusicBrain.circleOfFifthsWindow(center: centerKey, count: columnCount)

        // Limit chord types to the number of rows requested (top-to-bottom per column)
        let chordTypesInRows = Array(MusicBrain.ChordType.allCases.prefix(rowCount))

        var output: [ChordItem] = []
        for key in keysInFifths {
            for type in chordTypesInRows {
                output.append(ChordItem(key: key, type: type))
            }
        }

        self.items = output
    }
}

final class ChordGridView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private enum UIConstants {
        static let itemSize = CGSize(width: 64, height: 64)
        static let imageSide: CGFloat = 48
        static let spacing: CGFloat = 12
    }

    private let collectionView: UICollectionView
    private var items: [ChordGridViewModel.ChordItem] = []
    private var currentKeyIndex: Int? = nil
    private var selectedIndex: Int?
    var onChordSelected: ((ChordGridViewModel.ChordItem) -> Void)?

    init(viewModel: ChordGridViewModel) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = UIConstants.spacing
        layout.minimumInteritemSpacing = 0
        layout.sectionInsetReference = .fromSafeArea

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        // Removed: collectionView.backgroundColor = UIColor.green.withAlphaComponent(0.15)
        super.init(frame: .zero)
        self.backgroundColor = .clear
        // Removed: self.backgroundColor = UIColor.red.withAlphaComponent(0.15)

        DispatchQueue.main.async {
            let sideInset = (self.bounds.width - UIConstants.itemSize.width) / 2
            (self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset = UIEdgeInsets(top: 0, left: sideInset, bottom: 0, right: sideInset)
            self.collectionView.collectionViewLayout.invalidateLayout()
        }

        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(ChordCell.self, forCellWithReuseIdentifier: ChordCell.reuseID)

        addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        self.items = viewModel.items
        
        // Attempt to center on current key after initial data load
        DispatchQueue.main.async { [weak self] in
            self?.scrollToCenterOfCurrentKey(animated: false)
        }
        
        collectionView.reloadData()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handlePatchChange), name: .patchDidChange, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .patchDidChange, object: nil)
    }

    // MARK: Center Current Key
    func scrollToCenterOfCurrentKey(animated: Bool = true) {
        // Determine the current key from PatchManager if available; default to C
        let currentKey: MusicBrain.NoteName = {
            guard let id = PatchManager.shared.currentPatchID,
                  let patch = PatchManager.shared.getPatchData(forID: id) else {
                return .C
            }
            return patch.key
        }()

        // Find the first item matching this key
        guard let index = items.firstIndex(where: { $0.key == currentKey }) else { return }

        self.currentKeyIndex = index

        // Ensure scrolling occurs on the next runloop and on main thread
        DispatchQueue.main.async {
            let indexPath = IndexPath(item: index, section: 0)
            self.collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
            self.updateHighlightRing()
        }
    }

    private func updateHighlightRing() {
        let indexToHighlight = selectedIndex ?? currentKeyIndex
        for cell in collectionView.visibleCells {
            guard let indexPath = collectionView.indexPath(for: cell), let chordCell = cell as? ChordCell else { continue }
            let isHighlighted = (indexPath.item == indexToHighlight)
            chordCell.setHighlightedRing(isHighlighted)
        }
    }
    
    @objc private func handlePatchChange() {
        // Refresh items and center on the current key
        // We don't have direct access to the viewModel here, so recompute items if needed is not available.
        // Since ChordGridViewRepresentable.updateUIView refreshes items when SwiftUI updates, here we'll just recenter and update highlight.
        self.scrollToCenterOfCurrentKey(animated: true)
        self.updateHighlightRing()
    }

    func updateItems(_ newItems: [ChordGridViewModel.ChordItem]) {
        self.items = newItems
        self.selectedIndex = nil
        self.collectionView.reloadData()
        // Recompute current key index based on PatchManager
        let currentKey: MusicBrain.NoteName = {
            guard let id = PatchManager.shared.currentPatchID,
                  let patch = PatchManager.shared.getPatchData(forID: id) else {
                return .C
            }
            return patch.key
        }()
        self.currentKeyIndex = self.items.firstIndex(where: { $0.key == currentKey })
        // Ensure highlight updates on next runloop
        DispatchQueue.main.async { [weak self] in
            self?.updateHighlightRing()
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChordCell.reuseID, for: indexPath) as? ChordCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: items[indexPath.item].label)
        let indexToHighlight = selectedIndex ?? currentKeyIndex
        let isHighlighted = (indexPath.item == indexToHighlight)
        cell.setHighlightedRing(isHighlighted)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndex = indexPath.item
        updateHighlightRing()
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        let item = items[indexPath.item]
        onChordSelected?(item)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return UIConstants.itemSize
    }
}

private enum ChordCellConstants { static let imageSide: CGFloat = 48 }

final class ChordCell: UICollectionViewCell {
    static let reuseID = "ChordCell"

    private var circleView = UIView()
    private var selectionIndicatorView = UIView()
    private var label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        // Removed: self.backgroundColor = UIColor.blue.withAlphaComponent(0.15)
        // Removed: contentView.backgroundColor = UIColor.cyan.withAlphaComponent(0.15)
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear

        let parts = makeCircularLabeledButton(metrics: .standard,
                                              font: .systemFont(ofSize: 14, weight: .semibold),
                                              textColor: .black,
                                              innerColor: UIColor.white.withAlphaComponent(0.4))
        self.circleView = parts.circleView
        self.selectionIndicatorView = parts.selectionIndicatorView

        contentView.addSubview(parts.container)
        NSLayoutConstraint.activate(constrainCentered(parts.container, in: contentView))

        self.label = parts.label
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with text: String) {
        label.text = text
    }
    
    func setHighlightedRing(_ highlighted: Bool) {
        applySelectionIndicator(selectionIndicatorView, selected: highlighted)
    }
}

struct ChordGridViewRepresentable: UIViewRepresentable {
    let viewModel: ChordGridViewModel

    func makeUIView(context: Context) -> ChordGridView {
        return ChordGridView(viewModel: viewModel)
    }

    func updateUIView(_ uiView: ChordGridView, context: Context) {
        viewModel.refresh()
        uiView.updateItems(viewModel.items)
    }
}
