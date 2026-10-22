//
//  UserDetailViewController.swift
//  FaceBook
//
//  Created by Dian Maisara on 22/10/26.
//

import UIKit

class UserDetailViewController: UIViewController {

    private let user: SimplifiedUser

    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 70 // half of the fixed 140x140 size below
        view.backgroundColor = .systemGray5
        view.image = UIImage(systemName: "person.fill")
        view.tintColor = .systemGray2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let imageLoading: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView(style: .medium)
        loader.hidesWhenStopped = true
        loader.translatesAutoresizingMaskIntoConstraints = false
        return loader
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textAlignment = .center
        return label
    }()

    private let emailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private let ageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private lazy var labelsStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, emailLabel, ageLabel])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    init(user: SimplifiedUser) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupElements()
        setupLayout()
        fetchImage()
    }

    private func setupElements() {
        nameLabel.text = user.fullName
        emailLabel.text = user.email
        ageLabel.text = "\(user.age) years old"

        view.addSubview(imageView)
        view.addSubview(imageLoading)
        view.addSubview(labelsStackView)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 140),
            imageView.heightAnchor.constraint(equalToConstant: 140),

            imageLoading.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            imageLoading.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),

            labelsStackView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 24),
            labelsStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            labelsStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
        ])
    }

    private func fetchImage() {
        guard let imageURL = user.imageURL else { return } // if image empty, return

        imageLoading.startAnimating()

        Task {
            defer { imageLoading.stopAnimating() } // try the defer method to do the stop animation
            do {
                let request = URLRequest(url: imageURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
                let (data, _) = try await URLSession.shared.data(for: request)
                if let image = UIImage(data: data) {
                    imageView.image = image
                }
            } catch {
                print("❌ Failed to fetch image: \(error)")
            }
        }
    }
}
