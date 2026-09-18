import ActivityKit
import Foundation

// Compiled into both Runner and the widget extension; keep the types identical.
struct MnemosyneAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: String
        var recordingStartedAt: Date
    }
    var agentName: String
    var sessionID: String
}
