import Foundation

struct UsageSnapshot: Equatable {
    let sessionPercentage: Double
    let sessionResetTime: Date?
    let weeklyPercentage: Double?
    let weeklyResetTime: Date?
    let lastUpdated: Date
}
