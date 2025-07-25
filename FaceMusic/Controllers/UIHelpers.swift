import UIKit

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
                         touchUpAction: Selector) -> (container: UIView, slider: UISlider, valueLabel: UILabel) {

    let titleLabel = createTitleLabel(title)

    let labelStack = UIStackView()
    let minTextLabel = UILabel.settingsLabel(text: minLabel, fontSize: 14, bold: false)
    minTextLabel.textAlignment = .left
    let maxTextLabel = UILabel.settingsLabel(text: maxLabel, fontSize: 14, bold: false)
    maxTextLabel.textAlignment = .right
    labelStack.axis = .horizontal
    labelStack.distribution = .fillEqually
    labelStack.alignment = .fill
    labelStack.translatesAutoresizingMaskIntoConstraints = false
    labelStack.addArrangedSubview(minTextLabel)
    labelStack.addArrangedSubview(maxTextLabel)

    let slider = UISlider()
    slider.minimumValue = minValue
    slider.maximumValue = maxValue
    slider.value = initialValue
    slider.translatesAutoresizingMaskIntoConstraints = false
    slider.addTarget(target, action: valueChangedAction, for: .valueChanged)
    slider.addTarget(target, action: touchUpAction, for: [.touchUpInside, .touchUpOutside])

    let valueLabel = UILabel.settingsLabel(text: "\(Int(initialValue)) ms", fontSize: 13, bold: false)

    let stack = createSettingsStack(with: [titleLabel, labelStack, slider, valueLabel])
    let container = createSettingsContainer(with: stack)

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
