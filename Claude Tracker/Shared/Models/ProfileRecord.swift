import Foundation

struct ProfileRecord: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var sessionKey: String
    var organizationId: String?
}

struct ProfileUsage: Identifiable, Equatable {
    let id: UUID
    let name: String
    let usage: UsageSnapshot?
    let errorMessage: String?
}
