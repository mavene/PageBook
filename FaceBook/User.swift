//
//  User.swift
//  FaceBook
//
//  Created by Dian Maisara on 22/10/26.
//

import UIKit

// Codable - is both Decodable, Encodable
struct SimplifiedUser: Decodable { // Decode only!
    let fullName: String         // Computed from firstName + lastName
    let email: String
    let age: Int
    var imageURL: URL?           // Resolved per-user during list load; image bytes fetched later on the detail page

    // This enum maps JSON keys to Swift properties
    enum CodingKeys: String, CodingKey {
        case firstName
        case lastName
        case email
        case age
    }

    // Custom initializer to handle the decoding
    init(from decoder: Decoder) throws {
        // Get the main container using our CodingKeys
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode and combine firstName + lastName into fullName
        let firstName = try container.decode(String.self, forKey: .firstName)
        let lastName = try container.decode(String.self, forKey: .lastName)
        self.fullName = "\(firstName) \(lastName)"

        let email = try container.decode(String.self, forKey: .email)
        self.email = email

        let age = try container.decode(Int.self, forKey: .age)
        self.age = age

        self.imageURL = nil // resolved separately after decoding, not from JSON
    }
}
