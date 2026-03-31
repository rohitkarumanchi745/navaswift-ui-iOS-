import Foundation

// MARK: - Contact Sync (POST /contacts/sync)

public struct ContactSyncResponse: Codable {
    public let friends: [ContactFriend]

    public struct ContactFriend: Codable, Identifiable {
        public let id: String
        public let name: String
        public let photo: String?
        public let age: Int?
    }
}

// MARK: - Privacy Settings (GET/POST /privacy/settings)

public struct PrivacySettingsResponse: Codable {
    public let discoverableByContacts: Bool?
    public let shareMusicTaste: Bool?
    public let shareFitnessData: Bool?

    private enum CodingKeys: String, CodingKey {
        case discoverableByContacts = "discoverable_by_contacts"
        case shareMusicTaste = "share_music_taste"
        case shareFitnessData = "share_fitness_data"
    }
}
