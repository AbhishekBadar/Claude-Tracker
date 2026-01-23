import Foundation

final class UsageService {
    private let profileStore = ProfileStore()

    var hasProfiles: Bool {
        !profileStore.loadProfiles().isEmpty
    }

    func loadProfiles() -> [ProfileRecord] {
        profileStore.loadProfiles()
    }

    func addProfile(name: String, sessionKey: String) throws {
        let trimmedKey = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw UsageServiceError.invalidSessionKey }
        guard !trimmedName.isEmpty else { throw UsageServiceError.invalidProfileName }

        var profiles = profileStore.loadProfiles()
        let profile = ProfileRecord(id: UUID(), name: trimmedName, sessionKey: trimmedKey, organizationId: nil)
        profiles.append(profile)
        profileStore.saveProfiles(profiles)
    }

    func removeProfile(id: UUID) {
        var profiles = profileStore.loadProfiles()
        profiles.removeAll { $0.id == id }
        profileStore.saveProfiles(profiles)
    }

    func clearAllProfiles() {
        profileStore.saveProfiles([])
    }

    func fetchUsage(for profile: ProfileRecord) async throws -> UsageSnapshot {
        let orgId = try await fetchOrganizationId(sessionKey: profile.sessionKey, storedOrgId: profile.organizationId)
        if profile.organizationId == nil {
            updateOrganizationId(orgId, for: profile.id)
        }
        let usageData = try await fetchUsageData(sessionKey: profile.sessionKey, orgId: orgId)
        return try parseUsageResponse(usageData)
    }

    private func updateOrganizationId(_ orgId: String, for id: UUID) {
        var profiles = profileStore.loadProfiles()
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].organizationId = orgId
        profileStore.saveProfiles(profiles)
    }

    private func fetchOrganizationId(sessionKey: String, storedOrgId: String?) async throws -> String {
        if let storedOrgId, !storedOrgId.isEmpty {
            return storedOrgId
        }

        let url = URL(string: "https://claude.ai/api/organizations")!
        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageServiceError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw UsageServiceError.unauthorized
            }
            throw UsageServiceError.serverError(statusCode: httpResponse.statusCode)
        }

        let organizations = try JSONDecoder().decode([Organization].self, from: data)
        guard let first = organizations.first else {
            throw UsageServiceError.noOrganizations
        }

        return first.uuid
    }

    private func fetchUsageData(sessionKey: String, orgId: String) async throws -> Data {
        let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage")!
        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageServiceError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw UsageServiceError.unauthorized
            }
            throw UsageServiceError.serverError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    private func parseUsageResponse(_ data: Data) throws -> UsageSnapshot {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageServiceError.invalidResponse
        }

        let sessionInfo = json["five_hour"] as? [String: Any]
        let weeklyInfo = json["seven_day"] as? [String: Any]

        let sessionPercentage = parseUtilization(sessionInfo?["utilization"])
        let weeklyPercentage = parseUtilization(weeklyInfo?["utilization"])

        let sessionResetTime = parseISODate(sessionInfo?["resets_at"] as? String)
        let weeklyResetTime = parseISODate(weeklyInfo?["resets_at"] as? String)

        return UsageSnapshot(
            sessionPercentage: sessionPercentage,
            sessionResetTime: sessionResetTime,
            weeklyPercentage: weeklyPercentage,
            weeklyResetTime: weeklyResetTime,
            lastUpdated: Date()
        )
    }

    private func parseISODate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private func parseUtilization(_ value: Any?) -> Double {
        if let intValue = value as? Int {
            return Double(intValue)
        }
        if let doubleValue = value as? Double {
            return doubleValue
        }
        if let stringValue = value as? String {
            let cleaned = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "%", with: "")
            return Double(cleaned) ?? 0
        }
        return 0
    }
}

struct Organization: Codable {
    let uuid: String
    let name: String
}

enum UsageServiceError: Error, LocalizedError {
    case noSessionKey
    case invalidSessionKey
    case invalidResponse
    case unauthorized
    case serverError(statusCode: Int)
    case noOrganizations
    case invalidProfileName

    var errorDescription: String? {
        switch self {
        case .noSessionKey:
            return "No session key saved."
        case .invalidSessionKey:
            return "Session key cannot be empty."
        case .invalidResponse:
            return "Invalid response from Claude API."
        case .unauthorized:
            return "Unauthorized. Your session key may have expired."
        case .serverError(let statusCode):
            return "Claude API error (HTTP \(statusCode))."
        case .noOrganizations:
            return "No organizations found for this account."
        case .invalidProfileName:
            return "Profile name cannot be empty."
        }
    }
}
