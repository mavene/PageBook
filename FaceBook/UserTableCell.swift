//
//  UserTableCell.swift
//  FaceBook
//
//  Created by Dian Maisara on 22/10/26.
//

import UIKit

class UserTableCell: UITableViewCell {
    
    static let identifier = "UserTableCell"
    
    let userImage = UIImageView()
    let userName = UILabel()
    let userEmail = UILabel()
    let userAge = UILabel()

    private var imageTask: Task<Void, Never>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupColumns()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupColumns() {
        selectionStyle = .none

        userImage.contentMode = .scaleAspectFill
        userImage.clipsToBounds = true
        userImage.layer.cornerRadius = 22 // half of the fixed 44x44 size below
        userImage.backgroundColor = .systemGray5
        userImage.image = UIImage(systemName: "person.fill")
        userImage.tintColor = .systemGray2

        userName.textAlignment = .center
        userName.font = .systemFont(ofSize: 14, weight: .semibold)
        userEmail.textAlignment = .center
        userEmail.font = .systemFont(ofSize: 12)
        userEmail.textColor = .secondaryLabel
        userAge.textAlignment = .right
        userAge.font = .systemFont(ofSize: 12)
        userAge.textColor = .secondaryLabel

//        let labelsStackView = UIStackView(arrangedSubviews: [userName, userEmail, userAge])
        let labelsStackView = UIStackView(arrangedSubviews: [userEmail, userAge])
        labelsStackView.axis = .horizontal
        labelsStackView.distribution = .fillEqually
        labelsStackView.alignment = .center
        labelsStackView.spacing = 8
        
        let overallLabelsStackView = UIStackView(arrangedSubviews: [userName, labelsStackView])
        overallLabelsStackView.axis = .vertical
        overallLabelsStackView.distribution = .fillEqually
        overallLabelsStackView.alignment = .leading
        overallLabelsStackView.spacing = 8

        let stackView = UIStackView(arrangedSubviews: [userImage, overallLabelsStackView])
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        userImage.setContentHuggingPriority(.required, for: .horizontal)
        userImage.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentView.addSubview(stackView)

        // pin stack view to the cell's contentView edges
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            userImage.heightAnchor.constraint(equalToConstant: 44),
            userImage.widthAnchor.constraint(equalToConstant: 44),
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        userImage.image = UIImage(systemName: "person.fill")
    }

    func configure(colName: String, colEmail: String, colAge: String, imageURL: URL?) {
        userName.text = colName
        userEmail.text = colEmail
        userAge.text = colAge

        imageTask?.cancel() // prevent race condition of previous fetching of the SAME row !!!
        userImage.image = UIImage(systemName: "person.fill")

        guard let imageURL else { return }

        imageTask = Task {
            do {
                let request = URLRequest(url: imageURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
                let (data, _) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled, let image = UIImage(data: data) else { return }
                userImage.image = image
            } catch {
                print("❌ Failed to fetch image: \(error)")
            }
        }
    }
}

