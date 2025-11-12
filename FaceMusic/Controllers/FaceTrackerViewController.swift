//
//  FaceTrackerViewController.swift
//  FaceMusic
//
//  Created by Ryan Ross on 6/11/24.
//

import UIKit
import SceneKit
import ARKit
import SwiftEntryKit
import SwiftUI
import Combine

class FaceTrackerViewController: UIViewController {

    // MARK: - Properties

    @IBOutlet weak var sceneView: ARSCNView!

    private let viewModel = FaceTrackerViewModel()
    private var cancellables = Set<AnyCancellable>()

    // UI Components
    private var patchSelectorHostingController: UIHostingController<PatchSelectorViewRepresentable>?
    private var chordGridHostingController: UIViewController?
    private var bottomOverlayStackView: UIStackView!
    private var statsStackView: UIStackView!

    // Stats Managers
    private var faceStatsManager: FaceStatsManager!
    private var audioStatsManager: StatsWindowManager!
    private var musicStatsManager: StatsWindowManager!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        Log.line(actor: "😮 FaceTrackerViewController", fn: "viewDidLoad", "ARVC viewDidLoad bounds: \(sceneView.bounds), scale: \(sceneView.contentScaleFactor)")

        setupARScene()
        setupStats()
        setupButtons()
        setupBottomOverlay()
        setupPatchSelector()
        setupViewModel()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Log.line(actor: "😮 FaceTrackerViewController", fn: "viewDidAppear", "FaceTrackerVC didAppear bounds: \(sceneView.bounds) scale: \(sceneView.contentScaleFactor)")

        viewModel.startARSessionIfNeeded(session: sceneView.session)
        viewModel.patchSelectorViewModel.scrollToCenterOfSelectedPatch(animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        Log.line(actor: "😮 FaceTrackerViewController", fn: "viewWillDisappear", "Removing all inputs mixer")
        viewModel.pauseSession(session: sceneView.session)
        viewModel.cleanup()
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    // MARK: - Setup

    private func setupARScene() {
        sceneView.delegate = viewModel.faceTracker
        sceneView.session.delegate = viewModel.faceTracker
        sceneView.automaticallyUpdatesLighting = true
        sceneView.preferredFramesPerSecond = 24 // Lower frame rate to prioritize audio
        sceneView.showsStatistics = false
    }

    private func setupStats() {
        guard viewModel.showStats else { return }

        statsStackView = UIStackView()
        statsStackView.axis = .vertical
        statsStackView.spacing = 10
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statsStackView)

        NSLayoutConstraint.activate([
            statsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            statsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            statsStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10)
        ])

        // Initialize stat boxes
        faceStatsManager = FaceStatsManager(stackView: statsStackView, title: "Face Tracking")
        audioStatsManager = StatsWindowManager(stackView: statsStackView, title: "Audio Debugging")
        musicStatsManager = StatsWindowManager(stackView: statsStackView, title: "Music Debugging")
    }

    private func setupButtons() {
        // Create buttons with SF Symbols and consistent tint
        let savePatchButton = UIButton(type: .system)
        savePatchButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        savePatchButton.tintColor = .white
        savePatchButton.translatesAutoresizingMaskIntoConstraints = false
        savePatchButton.addTarget(self, action: #selector(savePatchButtonTapped), for: .touchUpInside)

        let gearButton = UIButton(type: .system)
        gearButton.setImage(UIImage(systemName: "pianokeys"), for: .normal)
        gearButton.tintColor = .white
        gearButton.translatesAutoresizingMaskIntoConstraints = false
        gearButton.addTarget(self, action: #selector(noteSettingsButtonTapped), for: .touchUpInside)

        let voiceSettingsButton = UIButton(type: .system)
        voiceSettingsButton.setImage(UIImage(systemName: "waveform.path.ecg.rectangle.fill"), for: .normal)
        voiceSettingsButton.tintColor = .white
        voiceSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        voiceSettingsButton.addTarget(self, action: #selector(voiceSettingsButtonTapped), for: .touchUpInside)

        let chordGridButton = UIButton(type: .system)
        chordGridButton.setImage(UIImage(systemName: "circle.grid.3x3"), for: .normal)
        chordGridButton.tintColor = .white
        chordGridButton.translatesAutoresizingMaskIntoConstraints = false
        chordGridButton.addTarget(self, action: #selector(toggleChordGridTapped), for: .touchUpInside)

        let resetButton = UIButton(type: .system)
        resetButton.setImage(UIImage(systemName: "person.fill.viewfinder"), for: .normal)
        resetButton.tintColor = .white
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.addTarget(self, action: #selector(resetTrackingTapped), for: .touchUpInside)

        // Stack the buttons vertically
        let buttonStack = UIStackView(arrangedSubviews: [voiceSettingsButton, gearButton, chordGridButton, resetButton, savePatchButton])
        buttonStack.axis = .vertical
        buttonStack.alignment = .center
        buttonStack.spacing = 10
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)

        // Constraints
        NSLayoutConstraint.activate([
            buttonStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            buttonStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])

        // Set fixed size for all buttons
        [savePatchButton, gearButton, voiceSettingsButton, chordGridButton, resetButton].forEach { btn in
            btn.widthAnchor.constraint(equalToConstant: 40).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        }
    }

    private func setupBottomOverlay() {
        bottomOverlayStackView = UIStackView()
        bottomOverlayStackView.axis = .vertical
        bottomOverlayStackView.distribution = .fill
        bottomOverlayStackView.alignment = .fill
        bottomOverlayStackView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        bottomOverlayStackView.spacing = 0
        bottomOverlayStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomOverlayStackView)

        NSLayoutConstraint.activate([
            bottomOverlayStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomOverlayStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomOverlayStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func setupPatchSelector() {
        let patchSelectorView = PatchSelectorViewRepresentable(viewModel: viewModel.patchSelectorViewModel)
        let hostingController = UIHostingController(rootView: patchSelectorView)
        self.patchSelectorHostingController = hostingController

        addChild(hostingController)
        bottomOverlayStackView.addArrangedSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        hostingController.view.heightAnchor.constraint(equalToConstant: 100).isActive = true
        hostingController.view.leadingAnchor.constraint(equalTo: bottomOverlayStackView.leadingAnchor).isActive = true
        hostingController.view.trailingAnchor.constraint(equalTo: bottomOverlayStackView.trailingAnchor).isActive = true
    }

    private func setupViewModel() {
        // Setup stats update callback
        viewModel.onStatsUpdate = { [weak self] faceData, audioStats, musicStats in
            guard let self = self else { return }
            self.faceStatsManager.updateFaceStats(with: faceData)
            self.audioStatsManager.updateStats(with: audioStats)
            self.musicStatsManager.updateStats(with: musicStats)
        }

        // Setup error callback
        viewModel.onError = { [weak self] title, message in
            self?.displayErrorMessage(title: title, message: message)
        }

        // Setup chord grid toggle callback
        viewModel.onChordGridToggleRequested = { [weak self] in
            self?.toggleChordGridView()
        }

        // Observe view model changes
        viewModel.$isARSessionRunning
            .sink { [weak self] isRunning in
                Log.line(actor: "😮 FaceTrackerViewController", fn: "setupViewModel", "AR Session running: \(isRunning)")
            }
            .store(in: &cancellables)

        viewModel.$currentPatchName
            .sink { [weak self] name in
                Log.line(actor: "😮 FaceTrackerViewController", fn: "setupViewModel", "Current patch: \(name)")
            }
            .store(in: &cancellables)
    }

    // MARK: - Button Actions

    @objc private func savePatchButtonTapped() {
        Log.line(actor: "👉 FaceTrackerViewController", fn: "savePatchButtonTapped", "SavePatchButtonTapped() called")

        let alert = UIAlertController(title: "Save Patch", message: "Enter name to save patch:", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Patch name"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            self?.viewModel.savePatch(withName: name)
        }))
        present(alert, animated: true, completion: nil)
    }

    @objc private func voiceSettingsButtonTapped() {
        let voiceSettingsViewController = VoiceSettingsViewController()
        let settings = viewModel.handleVoiceSettingsAction()
        voiceSettingsViewController.patchSettings = settings

        Log.line(actor: "😮 FaceTrackerViewController", fn: "voiceSettingsButtonTapped", "settings: \(settings)")

        var attributes = EKAttributes()
        attributes.displayDuration = .infinity
        attributes.name = "Voice Settings"
        attributes.windowLevel = .normal
        attributes.position = .center
        attributes.entryInteraction = .absorbTouches
        attributes.screenInteraction = .dismiss
        attributes.scroll = .enabled(swipeable: true, pullbackAnimation: .easeOut)
        attributes.positionConstraints = .fullScreen
        attributes.screenBackground = .color(color: EKColor(UIColor.black.withAlphaComponent(0.3)))
        attributes.entryBackground = .clear

        SwiftEntryKit.display(entry: voiceSettingsViewController, using: attributes)
    }

    @objc private func noteSettingsButtonTapped() {
        Log.line(actor: "👉 FaceTrackerViewController", fn: "noteSettingsButtonTapped", "noteSettingsButtonTapped() called")

        let noteSettingsViewController = NoteSettingsViewController()
        let settings = viewModel.handleNoteSettingsAction()
        noteSettingsViewController.patchSettings = settings

        var attributes = EKAttributes()
        attributes.displayDuration = .infinity
        attributes.name = "Note Settings"
        attributes.windowLevel = .normal
        attributes.position = .center
        attributes.entryInteraction = .absorbTouches
        attributes.screenInteraction = .dismiss
        attributes.scroll = .enabled(swipeable: true, pullbackAnimation: .easeOut)
        attributes.positionConstraints = .fullScreen
        attributes.screenBackground = .color(color: EKColor(UIColor.black.withAlphaComponent(0.3)))
        attributes.entryBackground = .clear

        SwiftEntryKit.display(entry: noteSettingsViewController, using: attributes)
    }

    @objc private func resetTrackingTapped() {
        viewModel.handleResetTrackingAction(session: sceneView.session)
    }

    @objc private func toggleChordGridTapped() {
        viewModel.handleChordGridToggle()
    }

    private func toggleChordGridView() {
        if let controller = chordGridHostingController {
            Log.line(actor: "😮 FaceTrackerViewController", fn: "toggleChordGridView", "Removing chord grid")
            // Remove from stack
            controller.willMove(toParent: UIViewController?.none)
            bottomOverlayStackView.removeArrangedSubview(controller.view)
            controller.view.removeFromSuperview()
            controller.removeFromParent()
            chordGridHostingController = nil
        } else {
            Log.line(actor: "😮 FaceTrackerViewController", fn: "toggleChordGridView", "Creating chord grid")
            let chordGridViewModel = ChordGridViewModel()

            // Import current settings from conductor into chordGrid's patchSettings
            let settings = viewModel.getChordGridPatchSettings()

            Log.line(actor: "😮 FaceTrackerViewController", fn: "toggleChordGridView", "updating chordGridViewModel.patchSettings")
            chordGridViewModel.patchSettings = settings

            let chordGridView = ChordGridView(viewModel: chordGridViewModel)
            let controller = UIViewController()

            controller.view = chordGridView
            controller.view.backgroundColor = .clear
            chordGridHostingController = controller

            addChild(controller)
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            bottomOverlayStackView.insertArrangedSubview(controller.view, at: 0)
            controller.didMove(toParent: self)
            controller.view.translatesAutoresizingMaskIntoConstraints = false

            // Dynamically calculate height based on rows
            let rowHeight: CGFloat = 60.0
            let rowCount = max(1, AppSettings().chordGridRows)
            let totalHeight = rowHeight * CGFloat(rowCount) + 20.0
            controller.view.heightAnchor.constraint(equalToConstant: totalHeight).isActive = true
            controller.view.leadingAnchor.constraint(equalTo: bottomOverlayStackView.leadingAnchor).isActive = true
            controller.view.trailingAnchor.constraint(equalTo: bottomOverlayStackView.trailingAnchor).isActive = true
        }
    }

    // MARK: - Error Handling

    func displayErrorMessage(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { [weak self] _ in
            alertController.dismiss(animated: true, completion: nil)
            if let session = self?.sceneView.session {
                self?.viewModel.resetTracking(session: session)
            }
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
}
