import UIKit

class LoadingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(.black)

        let titleLabel = UILabel()
        titleLabel.text = "\u{1F979} FaceMusic \u{1F3B6}" // 🥹 FaceMusic 🎶
        titleLabel.textAlignment = .center
        titleLabel.font = .boldSystemFont(ofSize: 28)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            titleLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
}
