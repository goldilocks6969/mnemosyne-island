import ActivityKit
import SwiftUI
import WidgetKit

/// Native system surfaces. iOS owns the camera area, expansion and update timing.
struct MnemosyneActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MnemosyneAttributes.self) { context in
            let style = IslandStyle(phase: context.state.phase)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    AgentGlyph(phase: context.state.phase)
                        .frame(width: 22, height: 22)
                    Spacer()
                    StatusTag(style: style)
                }
                ActivityDetails(context: context)
            }
            .padding(18)
            .foregroundStyle(.white)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
            .widgetURL(destination(for: context.state.phase))
        } dynamicIsland: { context in
            let style = IslandStyle(phase: context.state.phase)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    AgentGlyph(phase: context.state.phase)
                        .frame(width: 22, height: 22)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StatusTag(style: style)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ActivityDetails(context: context)
                        .padding(.horizontal, 4)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                }
            } compactLeading: {
                AgentGlyph(phase: context.state.phase)
                    .frame(width: 18, height: 18)
            } compactTrailing: {
                StatusTag(style: style)
            } minimal: {
                AgentGlyph(phase: context.state.phase)
                    .frame(width: 18, height: 18)
                    .accessibilityLabel(style.accessibleStatus)
                    .accessibilityHidden(false)
            }
            .widgetURL(destination(for: context.state.phase))
            .keylineTint(style.accent)
        }
    }

    private func destination(for phase: String) -> URL {
        URL(string: phase == "approval"
            ? "mnemosyne://agent/instinct/review"
            : "mnemosyne://home")!
    }
}

private struct IslandStyle {
    let phase: String

    var tag: String {
        switch phase {
        case "recording": return "[rec]"
        case "processing": return "[tinkering]"
        case "approval": return "[approve]"
        default: return "[working]"
        }
    }

    var accent: Color {
        switch phase {
        case "recording", "processing": return Color(red: 1, green: 0.27, blue: 0.31)
        case "approval": return Color(red: 1, green: 0.77, blue: 0.24)
        default: return Color(red: 0.31, green: 0.87, blue: 0.51)
        }
    }

    var tagColor: Color { phase == "working" ? .white : accent }
    var showsDot: Bool { phase == "recording" || phase == "working" }
    var accessibleStatus: String {
        switch phase {
        case "recording": return "Recording"
        case "processing": return "Transcribing speech"
        case "approval": return "Needs review"
        default: return "Agent working"
        }
    }
}

private struct StatusTag: View {
    let style: IslandStyle

    var body: some View {
        HStack(spacing: 4) {
            if style.showsDot {
                Circle().fill(style.accent).frame(width: 4, height: 4)
            }
            Text(style.tag)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(style.tagColor)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(style.accessibleStatus)
    }
}

private struct ActivityDetails: View {
    let context: ActivityViewContext<MnemosyneAttributes>

    var body: some View {
        Group {
            switch context.state.phase {
            case "recording":
                HStack(alignment: .firstTextBaseline) {
                    Text("Recording")
                    Spacer(minLength: 12)
                    // System-rendered timer continues without polling or waking Flutter.
                    Text(timerInterval: context.state.recordingStartedAt...Date.distantFuture,
                         countsDown: false)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 130, alignment: .trailing)
                        .accessibilityLabel("Elapsed recording time")
                }
            case "processing":
                Text("Transcribing your speech")
                    .frame(maxWidth: .infinity, alignment: .leading)
            case "approval":
                HStack(spacing: 12) {
                    Text(context.attributes.agentName)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Link(destination: URL(string: "mnemosyne://agent/instinct/review")!) {
                        Text("Review")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 44)
                            .background(IslandStyle(phase: "approval").accent, in: Capsule())
                    }
                    .accessibilityLabel("Review \(context.attributes.agentName)")
                }
            default:
                Text(context.attributes.agentName)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(.white)
    }
}

private let previewAttributes = MnemosyneAttributes(agentName: "Instinct", sessionID: "preview")

#Preview("Expanded states", as: .dynamicIsland(.expanded), using: previewAttributes) {
    MnemosyneActivityLiveActivity()
} contentStates: {
    MnemosyneAttributes.ContentState(phase: "recording", recordingStartedAt: Date().addingTimeInterval(-83))
    MnemosyneAttributes.ContentState(phase: "processing", recordingStartedAt: Date())
    MnemosyneAttributes.ContentState(phase: "working", recordingStartedAt: Date())
    MnemosyneAttributes.ContentState(phase: "approval", recordingStartedAt: Date())
}

#Preview("Compact states", as: .dynamicIsland(.compact), using: previewAttributes) {
    MnemosyneActivityLiveActivity()
} contentStates: {
    MnemosyneAttributes.ContentState(phase: "recording", recordingStartedAt: Date().addingTimeInterval(-83))
    MnemosyneAttributes.ContentState(phase: "processing", recordingStartedAt: Date())
    MnemosyneAttributes.ContentState(phase: "working", recordingStartedAt: Date())
    MnemosyneAttributes.ContentState(phase: "approval", recordingStartedAt: Date())
}
