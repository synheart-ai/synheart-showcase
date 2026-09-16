import ActivityKit
import Flutter
import Foundation

@MainActor
final class ResonaLiveActivityManager {
  private var currentActivity: Activity<ResonaActivityAttributes>?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    Task { @MainActor in
      do {
        switch call.method {
        case "start":
          let state = try contentState(from: call.arguments)
          try await startOrUpdate(state)
        case "update":
          let state = try contentState(from: call.arguments)
          try await update(state)
        case "end":
          await end()
        default:
          result(FlutterMethodNotImplemented)
          return
        }
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "LIVE_ACTIVITY_ERROR",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  private func contentState(from arguments: Any?) throws -> ResonaActivityAttributes.ContentState {
    guard
      let values = arguments as? [String: Any],
      let title = values["title"] as? String,
      let artist = values["artist"] as? String,
      let state = values["state"] as? String,
      let stateImage = values["stateImage"] as? String,
      let message = values["message"] as? String,
      let isPlaying = values["isPlaying"] as? Bool
    else {
      throw LiveActivityError.invalidPayload
    }

    return ResonaActivityAttributes.ContentState(
      title: title,
      artist: artist,
      state: state,
      stateImage: stateImage,
      message: message,
      isPlaying: isPlaying
    )
  }

  private func startOrUpdate(_ state: ResonaActivityAttributes.ContentState) async throws {
    if let activity = activeActivity {
      currentActivity = activity
      await update(state)
      return
    }

    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      throw LiveActivityError.disabled
    }

    let attributes = ResonaActivityAttributes(sessionID: UUID().uuidString)
    let content = ActivityContent(
      state: state,
      staleDate: Date().addingTimeInterval(60 * 30),
      relevanceScore: 80
    )
    currentActivity = try Activity.request(
      attributes: attributes,
      content: content,
      pushType: nil
    )
  }

  private func update(_ state: ResonaActivityAttributes.ContentState) async {
    guard let activity = activeActivity else { return }
    currentActivity = activity
    await activity.update(
      ActivityContent(
        state: state,
        staleDate: Date().addingTimeInterval(60 * 30),
        relevanceScore: state.isPlaying ? 80 : 45
      )
    )
  }

  private func end() async {
    guard let activity = activeActivity else { return }
    await activity.end(nil, dismissalPolicy: .immediate)
    currentActivity = nil
  }

  private var activeActivity: Activity<ResonaActivityAttributes>? {
    currentActivity ?? Activity<ResonaActivityAttributes>.activities.first
  }
}

private enum LiveActivityError: LocalizedError {
  case invalidPayload
  case disabled

  var errorDescription: String? {
    switch self {
    case .invalidPayload:
      return "The Live Activity update was incomplete."
    case .disabled:
      return "Live Activities are disabled for Resona."
    }
  }
}
