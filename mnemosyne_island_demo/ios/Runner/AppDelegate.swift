import ActivityKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private let activities = IslandController()
    private var islandChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Flutter's scene-based lifecycle initializes the engine here, not in launch.
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        let channel = FlutterMethodChannel(
            name: "one.antimattr.mnemosyne/live_activity",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        islandChannel = channel
        ReviewRouter.shared.attach(channel)
        channel.setMethodCallHandler { [weak self] call, result in
            Task { @MainActor in
                guard let self else {
                    result(FlutterError(code: "UNAVAILABLE", message: "App is shutting down.", details: nil))
                    return
                }
                switch call.method {
                case "getStatus":
                    result(self.activities.status())
                case "setState":
                    guard let args = call.arguments as? [String: Any],
                          let phase = args["phase"] as? String else {
                        result(FlutterError(code: "INVALID_PHASE", message: "Choose an activity state.", details: nil))
                        return
                    }
                    do { result(try await self.activities.setPhase(phase)) }
                    catch { result(self.flutterError(error)) }
                case "stop":
                    do { result(try await self.activities.stop()) }
                    catch { result(self.flutterError(error)) }
                case "consumePendingReview":
                    result(ReviewRouter.shared.consumePending())
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }
    }

    private func flutterError(_ error: Error) -> FlutterError {
        FlutterError(code: "LIVE_ACTIVITY_ERROR", message: error.localizedDescription, details: nil)
    }
}

@MainActor
private final class IslandController {
    private var isUpdating = false
    private let phases: Set<String> = ["recording", "processing", "working", "approval"]

    private var activeActivities: [Activity<MnemosyneAttributes>] {
        Activity<MnemosyneAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    func status() -> [String: Any] {
        let activity = activeActivities.first
        return [
            "active": activity != nil,
            "phase": activity.map { $0.content.state.phase as Any } ?? NSNull(),
            "activityId": activity.map { $0.id as Any } ?? NSNull(),
            "enabled": ActivityAuthorizationInfo().areActivitiesEnabled,
        ]
    }

    func setPhase(_ phase: String) async throws -> [String: Any] {
        guard phases.contains(phase) else { throw IslandError.invalidPhase }
        guard !isUpdating else { throw IslandError.busy }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw IslandError.disabled }
        isUpdating = true
        defer { isUpdating = false }

        let existing = activeActivities
        let activity = existing.first
        let previous = activity?.content.state
        let startedAt: Date
        if phase == "recording" && previous?.phase != "recording" {
            startedAt = Date()
        } else {
            startedAt = previous?.recordingStartedAt ?? Date()
        }
        let content = ActivityContent(
            state: MnemosyneAttributes.ContentState(phase: phase, recordingStartedAt: startedAt),
            staleDate: nil
        )
        if let activity {
            await activity.update(content)
            // Recover cleanly if an earlier development build left duplicate sessions.
            for duplicate in existing.dropFirst() {
                await duplicate.end(nil, dismissalPolicy: .immediate)
            }
        } else {
            guard UIApplication.shared.applicationState == .active else { throw IslandError.openApp }
            _ = try Activity<MnemosyneAttributes>.request(
                attributes: MnemosyneAttributes(agentName: "Instinct", sessionID: UUID().uuidString),
                content: content,
                pushType: nil
            )
        }
        return status()
    }

    func stop() async throws -> [String: Any] {
        guard !isUpdating else { throw IslandError.busy }
        isUpdating = true
        defer { isUpdating = false }
        for activity in Activity<MnemosyneAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return status()
    }
}

private enum IslandError: LocalizedError {
    case invalidPhase, busy, disabled, openApp
    var errorDescription: String? {
        switch self {
        case .invalidPhase: return "This activity state is not supported."
        case .busy: return "An activity update is still finishing. Try again."
        case .disabled: return "Enable Live Activities for Mnemosyne Island in iPhone Settings, then try again."
        case .openApp: return "Open Mnemosyne Island before starting this demo."
        }
    }
}

/// Queue a cold-launch Review URL until Dart has installed its method handler.
@MainActor
final class ReviewRouter {
    static let shared = ReviewRouter()
    private var channel: FlutterMethodChannel?
    private var pending = false
    private var dartIsReady = false

    func attach(_ channel: FlutterMethodChannel) {
        self.channel = channel
        dartIsReady = false
    }

    func receive(_ url: URL) {
        guard url.scheme == "mnemosyne", url.host == "agent",
              url.path == "/instinct/review" else { return }
        if dartIsReady, let channel {
            channel.invokeMethod("openReview", arguments: nil)
        } else {
            pending = true
        }
    }

    func consumePending() -> Bool {
        dartIsReady = true
        let shouldOpen = pending
        pending = false
        return shouldOpen
    }
}
