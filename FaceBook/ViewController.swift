//
//  ViewController.swift
//  FaceBook
//
//  Created by Dian Maisara on 22/10/26.
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private var users: [SimplifiedUser]?

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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: UserTableCell.identifier, for: indexPath) as? UserTableCell else {
            return UITableViewCell()
        }
        
        if let user = users?[indexPath.row] {
            cell.configure(colName: user.fullName, colEmail: user.email, colAge: "\(user.age)", imageURL: user.imageURL)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let user = users?[indexPath.row] else { return }
        let detailVC = UserDetailViewController(user: user)
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
     
        setupElements()
        setupLayout()
        getUsers()
    }

    func setupElements() {
        view.addSubview(stackView)

        stackView.addArrangedSubview(userTableViewLoading)
        stackView.addArrangedSubview(userTableView)

        userTableView.dataSource = self
        userTableView.delegate = self
        userTableView.tableFooterView = paginationLoading

        userTableView.register(UserTableCell.self, forCellReuseIdentifier: UserTableCell.identifier)
    }

    func setupLayout() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            ])
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
                var fetchedUsers = fetchedData.users

                // Resolve each user's random photo URL (redirect only — no image bytes downloaded).
                // The actual image is fetched later, on the detail page.
                // TODO: Swap to withTaskGroup feature / functionality
                for index in fetchedUsers.indices {
                    do {
                        guard let randomImageURL = URL(string: "https://100k-faces.vercel.app/api/random-image") else { continue }
                        var request = URLRequest(url: randomImageURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
                        request.httpMethod = "HEAD"
                        let (_, response) = try await URLSession.shared.data(for: request)
                        fetchedUsers[index].imageURL = response.url
                    } catch {
                        print("❌ Failed to resolve image URL: \(error)")
                    }
                }

                await MainActor.run {
                    updateUsers(users: fetchedUsers, append: !isInitialLoad)
                }
                
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
    private func updateUsers(users: [SimplifiedUser], append: Bool) {
        
        // update UI
        if append {
            self.users = (self.users ?? []) + users
        } else {
            self.users = users
        }
        userTableView.reloadData()
        userTableView.isHidden = false

        skip += limit // change the private properties
    }

    // Hint: Detect scroll position
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height

        if offsetY > contentHeight - height, contentHeight > height {
            getUsers()
        }
    }
}


#Preview {
    ViewController()
}



