import ActivityKit
import Foundation

struct ResonaActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var title: String
    var artist: String
    var state: String
    var stateImage: String
    var message: String
    var isPlaying: Bool
  }

  var sessionID: String
}
