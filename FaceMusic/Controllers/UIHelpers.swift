import UIKit

private func uihelpers_addTickDots(to slider: UISlider, count: Int, dotColor: UIColor = .tertiaryLabel) {
    slider.subviews.filter { $0.tag == 999_101 }.forEach { $0.removeFromSuperview() }
    slider.layoutIfNeeded()
    let trackRect = slider.trackRect(forBounds: slider.bounds)
    let trackOriginX = trackRect.origin.x
    let trackWidth = trackRect.width
    let trackCenterY = trackRect.midY
    guard count > 1 else { return }
    for i in 0..<(count) {
        let normalized = CGFloat(i) / CGFloat(max(count - 1, 1))
        let x = trackOriginX + normalized * trackWidth
        let dotSize: CGFloat = 6.0
        let dot = UIView(frame: CGRect(x: x - dotSize/2, y: trackCenterY - dotSize/2, width: dotSize, height: dotSize))
        dot.backgroundColor = dotColor
        dot.layer.cornerRadius = dotSize / 2
        dot.isUserInteractionEnabled = false
        dot.tag = 999_101
        dot.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        slider.addSubview(dot)
    }
}

private func uihelpers_alignLabels(_ labels: [UILabel], to slider: UISlider, count: Int) {
    slider.layoutIfNeeded()
    guard let superview = slider.superview, !labels.isEmpty, count > 1 else { return }
    let trackRect = slider.trackRect(forBounds: slider.bounds)
    let trackOriginX = trackRect.origin.x
    let trackWidth = trackRect.width
    let sliderOriginInSuperview = slider.convert(CGPoint.zero, to: superview)
    for (i, label) in labels.enumerated() {
        let normalized = CGFloat(i) / CGFloat(max(count - 1, 1))
        let xInSlider = trackOriginX + normalized * trackWidth
        let xInSuperview = sliderOriginInSuperview.x + xInSlider
        label.sizeToFit()
        var frame = label.frame
        let desiredX = xInSuperview - frame.width / 2.0
        // Clamp within labels container bounds if possible
        if let labelsContainer = label.superview {
            let containerOrigin = labelsContainer.convert(CGPoint.zero, to: superview)
            let minX = containerOrigin.x
            let maxX = containerOrigin.x + labelsContainer.bounds.width - frame.width
            frame.origin.x = max(minX, min(desiredX, maxX))
        } else {
            frame.origin.x = desiredX
        }
        label.frame = frame
    }
}

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

func createSettingsStack(with views: [UIView], spacing: CGFloat = 2) -> UIStackView {
    let stack = UIStackView(arrangedSubviews: views)
    stack.axis = .vertical
    stack.alignment = .fill
    stack.spacing = spacing
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
}

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

func createLabeledPicker(title: String, tag: Int, delegate: UIPickerViewDelegate & UIPickerViewDataSource) -> (container: UIView, picker: UIPickerView) {
    let titleLabel = createTitleLabel(title)
    let picker = UIPickerView()
    picker.delegate = delegate
    picker.dataSource = delegate
    picker.tag = tag
    picker.backgroundColor = .clear
    picker.translatesAutoresizingMaskIntoConstraints = false

    let stack = createSettingsStack(with: [titleLabel, picker])
    let container = createSettingsContainer(with: stack)
    return (container, picker)
}

func createLabeledSlider(title: String,
                         minLabel: String,
                         maxLabel: String,
                         minValue: Float,
                         maxValue: Float,
                         initialValue: Float,
                         target: Any?,
                         valueChangedAction: Selector,
                         touchUpAction: Selector,
                         trackLabels: [String]? = nil,
                         integerTickCount: Int? = nil,
                         showShadedBox: Bool = true,
                         liveUpdate: @escaping (Float) -> Void,
                         persist: @escaping (Float) -> Void,
                         toDisplay: ((Float) -> Float)? = nil,
                         toSlider: ((Float) -> Float)? = nil,
                         formatValueLabel: ((Float) -> String)? = nil) -> (container: UIView, slider: UISlider, valueLabel: UILabel) {

    let titleLabel = createTitleLabel(title)

    let labelStack: UIStackView
    if let trackLabels = trackLabels, !trackLabels.isEmpty {
        // Build a container that will host track-aligned labels
        let labelsContainer = UIView()
        labelsContainer.translatesAutoresizingMaskIntoConstraints = false
        labelsContainer.heightAnchor.constraint(equalToConstant: 18).isActive = true
        // Add labels as subviews (manual positioning after layout)
        for text in trackLabels {
            let l = UILabel.settingsLabel(text: text, fontSize: 14, bold: false)
            l.textAlignment = .center
            l.translatesAutoresizingMaskIntoConstraints = true
            labelsContainer.addSubview(l)
        }
        // Use a stack just to place the container in the vertical flow
        labelStack = UIStackView(arrangedSubviews: [labelsContainer])
        labelStack.axis = .vertical
        labelStack.alignment = .fill
        labelStack.spacing = 0
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        // We'll align labels after slider layout below
    } else {
        let ls = UIStackView()
        let minTextLabel = UILabel.settingsLabel(text: minLabel, fontSize: 14, bold: false)
        minTextLabel.textAlignment = .left
        let maxTextLabel = UILabel.settingsLabel(text: maxLabel, fontSize: 14, bold: false)
        maxTextLabel.textAlignment = .right
        ls.axis = .horizontal
        ls.distribution = .fillEqually
        ls.alignment = .fill
        ls.translatesAutoresizingMaskIntoConstraints = false
        ls.addArrangedSubview(minTextLabel)
        ls.addArrangedSubview(maxTextLabel)
        labelStack = ls
    }

    let slider = UISlider()
    
    slider.minimumValue = minValue
    slider.maximumValue = maxValue
    let sliderInitial = toSlider?(initialValue) ?? initialValue
    slider.value = sliderInitial
    slider.translatesAutoresizingMaskIntoConstraints = false
    slider.addTarget(target, action: valueChangedAction, for: .valueChanged)
    slider.addTarget(target, action: touchUpAction, for: [.touchUpInside, .touchUpOutside])
    
    // Padded content container to prevent label overflow at edges
    let contentContainer = UIView()
    contentContainer.translatesAutoresizingMaskIntoConstraints = false
    let contentStack = UIStackView()
    contentStack.axis = .vertical
    contentStack.spacing = 6
    contentStack.translatesAutoresizingMaskIntoConstraints = false
    contentContainer.addSubview(contentStack)
    let horizontalPadding: CGFloat = 16
    NSLayoutConstraint.activate([
        contentStack.topAnchor.constraint(equalTo: contentContainer.topAnchor),
        contentStack.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        contentStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: horizontalPadding),
        contentStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -horizontalPadding)
    ])

    contentStack.addArrangedSubview(labelStack)
    contentStack.addArrangedSubview(slider)

    // Build the main vertical stack with title and padded content
    let verticalStack = createSettingsStack(with: [titleLabel, contentContainer])
    let container: UIView
    if showShadedBox {
        container = createSettingsContainer(with: verticalStack)
    } else {
        container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(verticalStack)
        NSLayoutConstraint.activate([
            verticalStack.topAnchor.constraint(equalTo: container.topAnchor),
            verticalStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            verticalStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            verticalStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    let initialDisplay = toDisplay?(slider.value) ?? initialValue
    let initialLabelText = formatValueLabel?(initialDisplay) ?? "\(Int(initialDisplay)) ms"
    let valueLabel = UILabel.settingsLabel(text: initialLabelText, fontSize: 13, bold: false)
    if trackLabels == nil {
        contentStack.addArrangedSubview(valueLabel)
    }

    slider.addAction(UIAction { [weak valueLabel = valueLabel] _ in
        let displayValue = toDisplay?(slider.value) ?? slider.value
        let text = formatValueLabel?(displayValue) ?? "\(Int(displayValue)) ms"
        valueLabel?.text = text
    }, for: .valueChanged)

    if let count = integerTickCount, count > 1 || (trackLabels?.count ?? 0) > 0 {
        DispatchQueue.main.async { [weak slider] in
            guard let slider = slider else { return }
            if let count = integerTickCount, count > 1 {
                uihelpers_addTickDots(to: slider, count: count)
            }
            if let trackLabels = trackLabels, !trackLabels.isEmpty {
                // labelStack contains a single arranged subview: labelsContainer
                let labelsContainer = labelStack.arrangedSubviews.first
                let labels = labelsContainer?.subviews.compactMap { $0 as? UILabel } ?? []
                uihelpers_alignLabels(labels, to: slider, count: trackLabels.count)
            }
        }
    }

    // Default behavior: live-update audio while dragging, then persist on touch-up
    slider.addAction(UIAction { _ in
        let displayValue = toDisplay?(slider.value) ?? slider.value
        liveUpdate(displayValue)
    }, for: .valueChanged)

    slider.addAction(UIAction { _ in
        let displayValue = toDisplay?(slider.value) ?? slider.value
        // Ensure final live update, then persist the patch value
        liveUpdate(displayValue)
        persist(displayValue)
    }, for: [.touchUpInside, .touchUpOutside, .touchCancel])

    return (container, slider, valueLabel)
}

func createCloseButton(target: Any?, action: Selector) -> UIButton {
    let button = UIButton(type: .system)
    button.setTitle("X", for: .normal)
    button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
    button.setTitleColor(.white, for: .normal)
    button.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
    button.layer.cornerRadius = 20
    button.addTarget(target, action: action, for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
}

