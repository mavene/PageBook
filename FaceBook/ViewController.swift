//
//  ViewController.swift
//  FaceBook
//
//  Created by Dian Maisara on 22/10/26.
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {

    private enum AgeFilter: CaseIterable {
        case all, under30, thirtiesToForties, fiftyPlus

        var title: String {
            switch self {
            case .all: return "All ages"
            case .under30: return "Under 30"
            case .thirtiesToForties: return "30–49"
            case .fiftyPlus: return "50+"
            }
        }

        func matches(_ age: Int) -> Bool {
            switch self {
            case .all: return true
            case .under30: return age < 30
            case .thirtiesToForties: return (30...49).contains(age)
            case .fiftyPlus: return age >= 50
            }
        }
    }

    private var allUsers: [SimplifiedUser] = []   // everything loaded so far (source of truth)
    private var users: [SimplifiedUser] = []      // what the table shows (search + filter applied)

    private var searchText = ""
    private var ageFilter: AgeFilter = .all

    private var limit = 10 // for the "pagination", means loading next 10
    private var skip = 0 // ditto for above
    private var isLoadingUsers = false

    private let stackView : UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .fill
        view.spacing = 20
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let userTableView : UITableView = {
        let tableView = UITableView()
        tableView.separatorStyle = .none
        tableView.alwaysBounceVertical = true
        tableView.keyboardDismissMode = .interactive // drag the list down to dismiss the keyboard
        tableView.isHidden = true
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let userTableViewLoading: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView()
        loader.style = .medium
        loader.translatesAutoresizingMaskIntoConstraints = false
        return loader
    }()

    private let paginationLoading: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView()
        loader.style = .medium
        loader.hidesWhenStopped = true
        loader.frame = CGRect(x: 0, y: 0, width: 0, height: 44)
        return loader
    }()

    private static let searchBarHeight: CGFloat = 48
    private static let filterSize: CGFloat = 48

    private let searchField: UISearchTextField = {
        let field = UISearchTextField()
        field.placeholder = "Search name, email or age"
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.borderStyle = .none
        field.backgroundColor = .clear // the pill provides the background
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let filterButton: UIButton = {
        let button = UIButton(type: .system)
        button.showsMenuAsPrimaryAction = true // tap opens the menu directly
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let searchPill = FloatingBlurView(cornerRadius: ViewController.searchBarHeight / 2)
    private let filterPill = FloatingBlurView(cornerRadius: ViewController.filterSize / 2)

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: UserTableCell.identifier, for: indexPath) as? UserTableCell else {
            return UITableViewCell()
        }

        let user = users[indexPath.row]
        cell.configure(colName: user.fullName, colEmail: user.email, colAge: "\(user.age)", imageURL: user.imageURL)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user = users[indexPath.row]
        let detailVC = UserDetailViewController(user: user)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupElements()
        setupLayout()
        updateFilterButton()
        getUsers()
    }

    func setupElements() {
        view.addSubview(stackView)
        // added last so they float above the table
        view.addSubview(searchPill)
        view.addSubview(filterPill)

        searchPill.contentView.addSubview(searchField)
        filterPill.contentView.addSubview(filterButton)

        stackView.addArrangedSubview(userTableViewLoading)
        stackView.addArrangedSubview(userTableView)

        userTableView.dataSource = self
        userTableView.delegate = self
        userTableView.tableFooterView = paginationLoading

        userTableView.register(UserTableCell.self, forCellReuseIdentifier: UserTableCell.identifier)

        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
    }

    func setupLayout() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor), // let tableview stuff reach the bottom

            // keyboardLayoutGuide = safe-area bottom when the keyboard is hidden
            // and the top of the keyboard when it's showing so bar goes above
            searchPill.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            searchPill.trailingAnchor.constraint(equalTo: filterPill.leadingAnchor, constant: -8),
            searchPill.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8),
            searchPill.heightAnchor.constraint(equalToConstant: Self.searchBarHeight),

            searchField.leadingAnchor.constraint(equalTo: searchPill.contentView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: searchPill.contentView.trailingAnchor, constant: -8),
            searchField.centerYAnchor.constraint(equalTo: searchPill.contentView.centerYAnchor),

            // filter button sits beside search bar
            filterPill.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            filterPill.centerYAnchor.constraint(equalTo: searchPill.centerYAnchor),
            filterPill.widthAnchor.constraint(equalToConstant: Self.filterSize),
            filterPill.heightAnchor.constraint(equalToConstant: Self.filterSize),

            filterButton.topAnchor.constraint(equalTo: filterPill.contentView.topAnchor),
            filterButton.bottomAnchor.constraint(equalTo: filterPill.contentView.bottomAnchor),
            filterButton.leadingAnchor.constraint(equalTo: filterPill.contentView.leadingAnchor),
            filterButton.trailingAnchor.constraint(equalTo: filterPill.contentView.trailingAnchor),
        ])
    }

    // make sure last user does not get blocked/overlapped
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let tableFrame = userTableView.convert(userTableView.bounds, to: view)
        let overlap = max(0, tableFrame.maxY - searchPill.frame.minY)
        let bottomInset = overlap + 8

        if userTableView.contentInset.bottom != bottomInset {
            userTableView.contentInset.bottom = bottomInset
            userTableView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }

    // filter function
    private func matches(_ user: SimplifiedUser) -> Bool {
        guard ageFilter.matches(user.age) else { return false }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }

        let fields = [user.fullName, user.email, String(user.age)]
        return fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func applyFilters() {
        users = allUsers.filter(matches)
        userTableView.reloadData()
    }

    private func makeFilterMenu() -> UIMenu {
        let actions = AgeFilter.allCases.map { option in
            UIAction(title: option.title, state: option == ageFilter ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.ageFilter = option
                self.updateFilterButton()
                self.applyFilters()
            }
        }
        return UIMenu(title: "Filter by age", children: actions)
    }

    private func updateFilterButton() {
        let isActive = ageFilter != .all
        let symbol = isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        filterButton.setImage(UIImage(systemName: symbol, withConfiguration: config), for: .normal)
        filterButton.menu = makeFilterMenu() // rebuild so the checkmark follows the selection
    }

    @objc private func searchTextChanged() {
        searchText = searchField.text ?? ""
        applyFilters()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func getUsers() {
        guard !isLoadingUsers else { return }
        isLoadingUsers = true

        let isInitialLoad = skip == 0

        Task {
            defer {
                isLoadingUsers = false
                if isInitialLoad {
                    userTableViewLoading.stopAnimating()
                } else {
                    paginationLoading.stopAnimating()
                }
            }
            do {
                if isInitialLoad {
                    userTableView.isHidden = true
                    userTableViewLoading.startAnimating()
                } else {
                    paginationLoading.startAnimating()
                }

                guard let dataApiURL = URL(string: "https://dummyjson.com/users?limit=\(limit)&skip=\(skip)") else { throw URLError(.badURL) }

                let (data, response) = try await URLSession.shared.data(from: dataApiURL)

                // Check HTTP response status
                if let httpResponse = response as? HTTPURLResponse {
                    guard (200...299).contains(httpResponse.statusCode) else {
                        print("❌ HTTP Error: \(httpResponse.statusCode)")
                        switch httpResponse.statusCode {
                        case 404:
                            print("Not found")
                        case 500...599:
                            print("Server error")
                        default:
                            print("Request failed")
                        }
                        return
                    }
                }

                struct Response: Decodable {
                    let users: [SimplifiedUser]
                }

                let fetchedData = try JSONDecoder().decode(Response.self, from: data)
                let fetchedUsers = fetchedData.users

                // only for initial load!
                if isInitialLoad {
                    await MainActor.run {
                        self.allUsers = []
                        self.users = []
                        self.userTableView.reloadData()
                    }
                }

                // resolve each user's random photo URL (redirect only — no image bytes downloaded).
                // results arrive in completion order, so each row is shown as soon as image URL resolved, independent of the other users
                await withTaskGroup(of: (Int, URL?).self) { group in
                    for index in fetchedUsers.indices {
                        group.addTask {
                            guard let randomImageURL = URL(string: "https://100k-faces.vercel.app/api/random-image") else {
                                return (index, nil)
                            }
                            var request = URLRequest(url: randomImageURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
                            request.httpMethod = "HEAD"
                            do {
                                let (_, response) = try await URLSession.shared.data(for: request)
                                return (index, response.url)
                            } catch {
                                print("❌ Failed to resolve image URL: \(error)")
                                return (index, nil)
                            }
                        }
                    }

                    for await (index, url) in group {
                        var user = fetchedUsers[index]
                        user.imageURL = url // nil if resolution failed -> placeholder icon, user is not dropped
                        await MainActor.run {
                            self.appendUserRow(user)
                        }
                    }
                }

                skip += limit

            } catch DecodingError.keyNotFound(let key, let context) {
                print("❌ Missing key: '\(key.stringValue)'")
                print("Context: \(context.debugDescription)")

            } catch DecodingError.typeMismatch(let type, let context) {
                print("❌ Type mismatch for type: \(type)")
                print("Context: \(context.debugDescription)")

            } catch {
                print("❌ Error: \(error)")
            }
        }
    }

    private func appendUserRow(_ user: SimplifiedUser) {
        allUsers.append(user)

        // swap centered spinner for table (on first arrival, matching or not)
        if userTableView.isHidden {
            userTableView.isHidden = false
            userTableViewLoading.stopAnimating()
        }

        // only show it if it passes current search filter
        guard matches(user) else { return }
        users.append(user)
        let newIndexPath = IndexPath(row: users.count - 1, section: 0)
        userTableView.insertRows(at: [newIndexPath], with: .none)
    }

    // Hint: Detect scroll position
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height

        let visibleBottom = offsetY + height - scrollView.contentInset.bottom

        if visibleBottom > contentHeight - 1, contentHeight > height - scrollView.contentInset.bottom {
            getUsers()
        }
    }
}


#Preview {
    ViewController()
}


/// A rounded, translucent material pill with a soft shadow (the shadow lives on a wrapper
/// because the blur view has to clip to its rounded corners).
private final class FloatingBlurView: UIView {
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let cornerRadius: CGFloat

    var contentView: UIView { blur.contentView }

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 2)

        blur.clipsToBounds = true
        blur.layer.cornerRadius = cornerRadius
        blur.layer.cornerCurve = .continuous
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }
}
