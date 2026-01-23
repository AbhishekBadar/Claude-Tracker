import Foundation

final class ProfileStore {
    private let profilesKey = "claudeProfiles"
    private let legacySessionKey = "claudeSessionKey"
    private let legacyOrgIdKey = "claudeOrgId"

    func loadProfiles() -> [ProfileRecord] {
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let profiles = try? JSONDecoder().decode([ProfileRecord].self, from: data) {
            if profiles.isEmpty {
                return migrateLegacyIfNeeded()
            }
            return profiles
        }
        return migrateLegacyIfNeeded()
    }

    func saveProfiles(_ profiles: [ProfileRecord]) {
        let data = try? JSONEncoder().encode(profiles)
        UserDefaults.standard.set(data, forKey: profilesKey)
    }

    private func migrateLegacyIfNeeded() -> [ProfileRecord] {
        guard let legacyKey = UserDefaults.standard.string(forKey: legacySessionKey),
              !legacyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let legacyOrg = UserDefaults.standard.string(forKey: legacyOrgIdKey)
        let profile = ProfileRecord(
            id: UUID(),
            name: "Default",
            sessionKey: legacyKey,
            organizationId: legacyOrg
        )
        saveProfiles([profile])
        return [profile]
    }
}
