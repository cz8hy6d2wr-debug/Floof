import ActivityKit
import Foundation

/// Live-Aktivität für die nächste Gabe (Sperrbildschirm & Dynamic Island).
struct DoseActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "Gabapentin + Panacur"
        var title: String
        /// "0,15 ml · Brownie"
        var detail: String
        var due: Date
        var doseIDs: [String]
        var symbol: String
    }
}
