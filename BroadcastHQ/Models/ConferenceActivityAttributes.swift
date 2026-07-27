import ActivityKit
import Foundation

struct ConferenceActivityAttributes: ActivityAttributes {
    /// Fixed data set when the activity starts.
    var roomName: String
    var roomId: String
    var creatorName: String

    /// Dynamic state updated throughout the activity's lifetime.
    struct ContentState: Codable, Hashable {
        var participantCount: Int
        var participantNames: [String]
        var isMuted: Bool
        var elapsedSeconds: Int
        var isNoiseCancellationOn: Bool
    }
}
