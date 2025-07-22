import UIKit
import SwiftEntryKit
import AudioKitEX
import AudioKitUI
import PianoKeyboard

class NoteSettingsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    // Track the last highlighted note for piano key highlighting
    private var lastHighlightedNote: Int?
    
    var conductor: VoiceConductorProtocol?
    let appSettings = AppSettings()
    var patchSettings: PatchSettings!
    
    var keyPicker: UIPickerView!
    var chordTypePicker: UIPickerView!
    var voicesPicker: UIPickerView!
    var closeButton: UIButton!
    
    // Pickers for voice pitch and note range
    var voicePitchPicker: UIPickerView!
    var noteRangePicker: UIPickerView!

    // Store selected indices for new pickers
    var selectedVoicePitchIndex: Int = 2 // Default to "Medium"
    var selectedNoteRangeIndex: Int = 1 // Default to "Medium (2 Octaves)"

    let voicePitchOptions: [(label: String, centerMIDINote: Int)] = [
        ("Very High", 84),
        ("High", 72),
        ("Medium", 60),
        ("Low", 48),
        ("Very Low", 36)
    ]
    let noteRangeOptions: [(label: String, rangeSize: Int)] = [
        ("Small", 12),
        ("Medium", 24),
        ("Large", 48),
        ("X-Large", 128)
    ]
    
    var selectedNumOfVoices: Int = 1 // Store the selected number of voices
    let chordTypes = MusicBrain.ChordType.allCases
    
    var glissandoSlider: UISlider!
    var glissandoValueLabel: UILabel!
    
    // Piano keyboard reference
    private let keyboard = PianoKeyboard()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Add a blur effect view that fills the entire background
        let blurEffect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)

        if let refreshedSettings = PatchManager.shared.load(forID: patchSettings.id) {
            patchSettings = refreshedSettings
            //print("PatchSettings: \(patchSettings!)")
        }
        setupUI()
        configurePickersWithConductorSettings()
        NotificationCenter.default.addObserver(self, selector: #selector(handlePianoKeyCurrentNoteHighlight(_:)), name: Notification.Name("HighlightPianoKey"), object: nil)
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    private func setupUI() {
        
        // --- Voice Pitch Container ---

        let voicePitchTitleLabel = createTitleLabel("Voice Pitch")
        


        voicePitchPicker = UIPickerView()
        voicePitchPicker.delegate = self
        voicePitchPicker.dataSource = self
        voicePitchPicker.tag = 10
        voicePitchPicker.backgroundColor = .clear
        voicePitchPicker.translatesAutoresizingMaskIntoConstraints = false

        let voicePitchStack = createSettingsStack(with: [voicePitchTitleLabel, voicePitchPicker])
        
        let voicePitchContainer = createSettingsContainer(with: voicePitchStack)

        // --- Note Range Container ---

        let noteRangeTitleLabel = createTitleLabel("Note Range")

        
        noteRangePicker = UIPickerView()
        noteRangePicker.delegate = self
        noteRangePicker.dataSource = self
        noteRangePicker.tag = 11
        noteRangePicker.backgroundColor = .clear
        noteRangePicker.translatesAutoresizingMaskIntoConstraints = false

        let noteRangeStack = createSettingsStack(with: [noteRangeTitleLabel, noteRangePicker])
        
        let noteRangeContainer = createSettingsContainer(with: noteRangeStack)

        // --- Stack view containing the two containers ---
        
        let pitchRangeStack = UIStackView(arrangedSubviews: [voicePitchContainer, noteRangeContainer])
        pitchRangeStack.axis = .horizontal
        pitchRangeStack.spacing = 10
        pitchRangeStack.alignment = .top
        pitchRangeStack.distribution = .fillEqually
        pitchRangeStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pitchRangeStack)
        NSLayoutConstraint.activate([
            pitchRangeStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            pitchRangeStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pitchRangeStack.heightAnchor.constraint(equalToConstant: 130),
            pitchRangeStack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.9)
        ])

        // --- Key Picker with Label in Container ---
        keyPicker = UIPickerView()
        keyPicker.delegate = self
        keyPicker.dataSource = self
        keyPicker.tag = 0
        keyPicker.backgroundColor = .clear
        keyPicker.translatesAutoresizingMaskIntoConstraints = false

        let keyLabel = createTitleLabel("Key")
        
        let keyStack = createSettingsStack(with: [keyLabel, keyPicker])
        
        let keyContainer = createSettingsContainer(with: keyStack)
        
        // --- Chord Picker with Label in Container ---
        chordTypePicker = UIPickerView()
        chordTypePicker.delegate = self
        chordTypePicker.dataSource = self
        chordTypePicker.tag = 1
        chordTypePicker.backgroundColor = .clear
        chordTypePicker.translatesAutoresizingMaskIntoConstraints = false
        
        let chordLabel = createTitleLabel("Chord")

        let chordStack = createSettingsStack(with: [chordLabel, chordTypePicker])
        
        let chordContainer = createSettingsContainer(with: chordStack)
        
        // --- Horizontal Stack for Key and Chord Containers ---
        let keyChordStack = UIStackView(arrangedSubviews: [keyContainer, chordContainer])
        keyChordStack.axis = .horizontal
        keyChordStack.spacing = 10
        keyChordStack.alignment = .center
        keyChordStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyChordStack)
        // Fixed height and max width
        NSLayoutConstraint.activate([
            keyChordStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            keyChordStack.topAnchor.constraint(equalTo: pitchRangeStack.bottomAnchor, constant: 10),
            keyChordStack.heightAnchor.constraint(equalToConstant: 120),
            keyChordStack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40)
        ])
        // Optional: set a minimum width for each container
        keyPicker.widthAnchor.constraint(equalToConstant: 110).isActive = true
        
        // PIANO KEYBOARD
        setupPianoKeyboard(below: keyChordStack)
        
        
        // --- Voices Container ---

        let voicesLabel = createTitleLabel("Number of Voices")

        voicesPicker = UIPickerView()
        voicesPicker.delegate = self
        voicesPicker.dataSource = self
        voicesPicker.tag = 2
        voicesPicker.backgroundColor = .clear
        voicesPicker.translatesAutoresizingMaskIntoConstraints = false

        let voicesStack = createSettingsStack(with: [voicesLabel, voicesPicker])
        
        let voicesContainer = createSettingsContainer(with: voicesStack)
        
        // --- Glissando Container ---


        // Glissando Speed Label
        let glissandoLabel = createTitleLabel("Note Glide Speed")

        // Glissando Instant/Slow Labels Stack
        
        let glissandoLabelsStack = UIStackView()
        let instantLabel = UILabel.settingsLabel(text: "Instant", fontSize: 14, bold: false)
        instantLabel.textAlignment = .left
        let slowLabel = UILabel.settingsLabel(text: "Slow", fontSize: 14, bold: false)
        slowLabel.textAlignment = .right
        glissandoLabelsStack.axis = .horizontal
        glissandoLabelsStack.distribution = .fillEqually
        glissandoLabelsStack.alignment = .fill
        glissandoLabelsStack.translatesAutoresizingMaskIntoConstraints = false
        glissandoLabelsStack.addArrangedSubview(instantLabel)
        glissandoLabelsStack.addArrangedSubview(slowLabel)

        // Glissando Slider
        glissandoSlider = UISlider()
        glissandoSlider.minimumValue = 0
        glissandoSlider.maximumValue = 500 // 500 ms max
        glissandoSlider.value = patchSettings.glissandoSpeed
        glissandoSlider.translatesAutoresizingMaskIntoConstraints = false
        glissandoSlider.addTarget(self, action: #selector(glissandoSliderChanged), for: .valueChanged)
        glissandoSlider.addTarget(self, action: #selector(glissandoSliderDidEndSliding), for: [.touchUpInside, .touchUpOutside])

        // Glissando Value Label
        glissandoValueLabel = UILabel.settingsLabel(text: "\(Int(patchSettings.glissandoSpeed)) ms", fontSize: 13, bold: false)

        // Stack for glissando controls
        let glissandoStack = createSettingsStack(with: [glissandoLabel, glissandoLabelsStack, glissandoSlider, glissandoValueLabel])
        
        let glissandoContainer = createSettingsContainer(with: glissandoStack)
        
        // --- Voices and Glissando Horizontal Stack ---
        let voicesAndGlissStack = UIStackView(arrangedSubviews: [voicesContainer, glissandoContainer])
        voicesAndGlissStack.axis = .horizontal
        voicesAndGlissStack.spacing = 10
        voicesAndGlissStack.alignment = .top
        voicesAndGlissStack.distribution = .fillEqually
        voicesAndGlissStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(voicesAndGlissStack)


        // Constraints for voicesAndGlissStack, containers
        NSLayoutConstraint.activate([
            voicesAndGlissStack.topAnchor.constraint(equalTo: keyboard.bottomAnchor, constant: 20),
            voicesAndGlissStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            voicesAndGlissStack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            voicesAndGlissStack.heightAnchor.constraint(equalToConstant: 130),
            voicesContainer.heightAnchor.constraint(equalToConstant: 130),
            glissandoContainer.heightAnchor.constraint(equalToConstant: 130)
        ])
        
        // Create and configure the close button (X)
        closeButton = UIButton(type: .system)
        closeButton.setTitle("X", for: .normal)
        closeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        closeButton.layer.cornerRadius = 20
        closeButton.addTarget(self, action: #selector(closeSettings), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        // Close button constraints
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
    }
    
    private func configurePickersWithConductorSettings() {
        // Use the current key from MusicBrain
        let currentKey = MusicBrain.shared.currentKey
        
        let reversedNotes = MusicBrain.NoteName.allCases.reversed()
        let reversedArray = Array(reversedNotes)
        if let keyIndex = reversedArray.firstIndex(of: currentKey) {
            let middleRow = (reversedArray.count * 50) + keyIndex
            keyPicker.selectRow(middleRow, inComponent: 0, animated: false)
        }
        
        // Use the current chord type from MusicBrain
        let currentChordType = MusicBrain.shared.currentChordType
        if let chordIndex = chordTypes.firstIndex(of: currentChordType) {
            chordTypePicker.selectRow(chordIndex, inComponent: 0, animated: false)
        }
        
        // Number of voices from conductor if you want:
        if let conductor = conductor {
            selectedNumOfVoices = Int(conductor.numOfVoices)
            voicesPicker.selectRow(selectedNumOfVoices - 1, inComponent: 0, animated: false)
            
            // Set default selections for new pickers based on current lowest/highest notes, if possible
            // Try to infer closest pitch/range
            let currentLowest = conductor.lowestNote
            let currentHighest = conductor.highestNote
            let currentCenter = (currentLowest + currentHighest) / 2
            let currentRange = currentHighest - currentLowest
            // Find closest match for center
            if let idx = voicePitchOptions.enumerated().min(by: { abs($0.element.centerMIDINote - currentCenter) < abs($1.element.centerMIDINote - currentCenter) })?.offset {
                selectedVoicePitchIndex = idx
            }
            // Find closest match for range
            if let idx = noteRangeOptions.enumerated().min(by: { abs($0.element.rangeSize - currentRange) < abs($1.element.rangeSize - currentRange) })?.offset {
                selectedNoteRangeIndex = idx
            }
            voicePitchPicker.selectRow(selectedVoicePitchIndex, inComponent: 0, animated: false)
            noteRangePicker.selectRow(selectedNoteRangeIndex, inComponent: 0, animated: false)
        }
        
        // Update piano highlighting after configuring pickers
        let reversedNotesArr = Array(MusicBrain.NoteName.allCases.reversed())
        let selectedKey = reversedNotesArr[keyPicker.selectedRow(inComponent: 0) % reversedNotesArr.count]
        let selectedChordType = chordTypes[chordTypePicker.selectedRow(inComponent: 0)]
        
        // ✅ Sync MusicBrain so updatePianoHighlighting uses the correct state
        MusicBrain.shared.setKeyAndChordType(key: selectedKey, chordType: selectedChordType)
        print("updating musicbrain with selectedkey: \(selectedKey), chordType: \(selectedChordType)")
        
        DispatchQueue.main.async {
            self.updatePianoHighlighting()
        }
    }
    
    // MARK: - UIPickerViewDataSource Methods
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView.tag == 0 { // Key picker
            return MusicBrain.NoteName.allCases.count * 100
        } else if pickerView.tag == 1 { // Chord Type picker
            return chordTypes.count
        } else if pickerView.tag == 2 { // Number of Voices picker
            return 8 // Number of voices options (1-8)
        } else if pickerView.tag == 10 { // Voice Pitch
            return voicePitchOptions.count
        } else if pickerView.tag == 11 { // Note Range
            return noteRangeOptions.count
        }
        return 0
    }

    // MARK: - UIPickerViewDelegate Methods

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14)

        switch pickerView.tag {
        case 0:
            let reversedNotes = Array(MusicBrain.NoteName.allCases.reversed())
            label.text = reversedNotes[row % reversedNotes.count].displayName
        case 1:
            label.text = chordTypes[row].rawValue
        case 2:
            label.text = "\(row + 1)"
        case 10:
            label.text = voicePitchOptions[row].label
        case 11:
            label.text = noteRangeOptions[row].label
        default:
            label.text = ""
        }
        return label
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView.tag == 2 { // Number of Voices picker
            selectedNumOfVoices = row + 1 // Picker rows are 0-indexed
            print("Selected number of voices: \(selectedNumOfVoices)")
        } else if pickerView.tag == 10 {
            selectedVoicePitchIndex = row
        } else if pickerView.tag == 11 {
            selectedNoteRangeIndex = row
        }

        let reversedNotes = Array(MusicBrain.NoteName.allCases.reversed())
        let selectedKey = reversedNotes[keyPicker.selectedRow(inComponent: 0) % reversedNotes.count]
        let selectedChordType = chordTypes[chordTypePicker.selectedRow(inComponent: 0)]
        let center = voicePitchOptions[selectedVoicePitchIndex].centerMIDINote
        let halfRange = noteRangeOptions[selectedNoteRangeIndex].rangeSize / 2
        let lowestNote = max(0, center - halfRange)
        let highestNote = min(127, center + halfRange)

        patchSettings.lowestNote = lowestNote
        patchSettings.highestNote = highestNote
        patchSettings.numOfVoices = selectedNumOfVoices
        patchSettings.key = selectedKey
        patchSettings.chordType = selectedChordType
        patchSettings.glissandoSpeed = glissandoSlider.value

        if pickerView.tag == 0 || pickerView.tag == 1 {
            patchSettings.scaleMask = nil
        }
        PatchManager.shared.save(settings: patchSettings, forID: patchSettings.id)
        conductor?.applySettings(patchSettings)

        if pickerView.tag == 0 || pickerView.tag == 1 {
            MusicBrain.shared.setKeyAndChordType(key: selectedKey, chordType: selectedChordType)
            updatePianoHighlighting()
        } else if pickerView.tag == 10 || pickerView.tag == 11 {
            MusicBrain.shared.updateVoicePitchOrRangeOnly()
        }
    }
        
    
    
    
    @objc private func closeSettings() {
        // Dismiss the settings view using SwiftEntryKit's dismiss method
        SwiftEntryKit.dismiss()
    }
    
    @objc private func glissandoSliderChanged() {
        let intValue = Int(glissandoSlider.value)
        glissandoValueLabel.text = "\(intValue) ms"
    }

    @objc private func glissandoSliderDidEndSliding() {
        patchSettings.glissandoSpeed = glissandoSlider.value
        PatchManager.shared.save(settings: patchSettings, forID: patchSettings.id)
        conductor?.applySettings(patchSettings)
    }
    
    // MARK: - Piano Keyboard Setup
    private func setupPianoKeyboard(below anchorView: UIView){
        keyboard.delegate = self
        keyboard.translatesAutoresizingMaskIntoConstraints = false

        // Label for the piano keyboard
        let melodyLabel = createTitleLabel("Melody Scale")

        // Create stack for label and keyboard
        let pianoStack = createSettingsStack(with: [melodyLabel, keyboard])
        let pianoContainer = createSettingsContainer(with: pianoStack)

        view.addSubview(pianoContainer)

        NSLayoutConstraint.activate([
            pianoContainer.topAnchor.constraint(equalTo: anchorView.bottomAnchor, constant: 10),
            pianoContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pianoContainer.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            keyboard.heightAnchor.constraint(equalToConstant: 130)
        ])

        keyboard.setNeedsLayout()
        keyboard.layoutIfNeeded()
        keyboard.numberOfKeys = 12
    }

    // MARK: - Piano Highlighting
    private func updatePianoHighlighting(highlightNote: Int? = nil) {
        //print("updatePianoHighlighting with highlightNote: \(String(describing: highlightNote)), currentScalePitchClasses: \(MusicBrain.shared.currentScalePitchClasses)")

        // Use MusicBrain's currentPitchClasses for highlighting instead of computed intervals
        let scaleNotes = MusicBrain.shared.currentScalePitchClasses
        
        let allNotesInOctave = 60..<72
        for note in allNotesInOctave {
            if let highlightNote = highlightNote, note == highlightNote {
                // Highlight the current note in green
                keyboard.highlightKey(noteNumber: note, color: UIColor.green.withAlphaComponent(0.7), resets: false)
            } else if scaleNotes.contains(note % 12) {
                keyboard.highlightKey(noteNumber: note, color: UIColor.systemBlue.withAlphaComponent(0.7), resets: false)
            } else {
                keyboard.highlightKey(noteNumber: note, color: UIColor.black.withAlphaComponent(0.7), resets: false)
            }
        }
    }
        
    // MARK: - Piano Key Highlight Notification Handler
    @objc private func handlePianoKeyCurrentNoteHighlight(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let midiNote = userInfo["midiNote"] as? Int else { return }

        let displayedOctaveStart = 60 // MIDI note for C4
        let displayedNote = displayedOctaveStart + (midiNote % 12)

        // Check if the note has changed
        if lastHighlightedNote == displayedNote {
            return
        }

        lastHighlightedNote = displayedNote

        updatePianoHighlighting(highlightNote: displayedNote)
    }
    
}



// MARK: - Extensions for Settings Style
extension UIView {
    func applySettingsStyle(cornerRadius: CGFloat = 16) {
        backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        layer.cornerRadius = cornerRadius
        translatesAutoresizingMaskIntoConstraints = false
    }
}

extension UILabel {
    static func settingsLabel(text: String, fontSize: CGFloat = 15, bold: Bool = true) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        // Reduce vertical padding and control alignment
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.baselineAdjustment = .alignCenters
        label.font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        return label
    }
}


// MARK: - PianoDelegate
extension NoteSettingsViewController: PianoKeyboardDelegate {
    func pianoKeyDown(_ keyNumber: Int) {
        print("Key down: \(keyNumber)")
    }

    func pianoKeyUp(_ keyNumber: Int) {
        let pitchClass = keyNumber % 12
        MusicBrain.shared.togglePitchClass(pitchClass)

        // Update patch settings
        patchSettings.scaleMask = MusicBrain.shared.scaleMaskFromCurrentPitchClasses()
        
        // Save the updated patch
        PatchManager.shared.save(settings: patchSettings, forID: patchSettings.id)

        // Apply to conductor
        conductor?.applySettings(patchSettings)
        
        // Rebuild quantization with current lowest/highest notes
        MusicBrain.shared.rebuildQuantization(
            withScaleClasses: MusicBrain.shared.currentScalePitchClasses
        )
        
        // Refresh keyboard
        updatePianoHighlighting()
    }
}





// Helper for creating settings container views
func createSettingsContainer(with stack: UIStackView, cornerRadius: CGFloat = 16) -> UIView {
    let container = UIView()
    container.translatesAutoresizingMaskIntoConstraints = false
    container.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
    container.layer.cornerRadius = cornerRadius
    container.addSubview(stack)
    NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
        stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
        stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8)
    ])
    return container
}

// Helper for creating settings stack views
func createSettingsStack(with views: [UIView], spacing: CGFloat = 2) -> UIStackView {
    let stack = UIStackView(arrangedSubviews: views)
    stack.axis = .vertical
    stack.alignment = .fill
    stack.spacing = spacing
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
}

// Helper for creating title labels for settings
func createTitleLabel(_ text: String) -> UILabel {
    let label = UILabel()
    label.text = text
    label.textColor = .white
    label.textAlignment = .center
    label.backgroundColor = .clear
    label.translatesAutoresizingMaskIntoConstraints = false
    label.setContentHuggingPriority(.required, for: .vertical)
    label.setContentCompressionResistancePriority(.required, for: .vertical)
    label.numberOfLines = 1
    label.adjustsFontSizeToFitWidth = true
    label.baselineAdjustment = .alignCenters
    label.font = UIFont.boldSystemFont(ofSize: 15)
    return label
}
