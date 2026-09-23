import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let liveActivityManager = ResonaLiveActivityManager()
  private var liveActivityChannel: FlutterMethodChannel?
  private var pendingPlayerOpen = false
  private var pendingWearablePair: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "ai.synheart.resona/live_activity",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    liveActivityChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      if call.method == "consumePendingPlayerOpen" {
        result(self.pendingPlayerOpen)
        self.pendingPlayerOpen = false
        if let pendingWearablePair = self.pendingWearablePair {
          self.liveActivityChannel?.invokeMethod("pairWearable", arguments: pendingWearablePair)
          self.pendingWearablePair = nil
        }
        return
      }
      self.liveActivityManager.handle(call, result: result)
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if openPlayer(from: url) { return true }
    return super.application(app, open: url, options: options)
  }

  @discardableResult
  func openPlayer(from url: URL) -> Bool {
    if url.scheme == "wearsim", url.host == "pair" {
      if let liveActivityChannel {
        liveActivityChannel.invokeMethod("pairWearable", arguments: url.absoluteString)
      } else {
        pendingWearablePair = url.absoluteString
      }
      return true
    }
    guard url.scheme == "resona", url.host == "player" else { return false }
    if let liveActivityChannel {
      liveActivityChannel.invokeMethod("openPlayer", arguments: nil)
    } else {
      pendingPlayerOpen = true
    }
    return true
  }
}
