import SwiftUI

/// Small flat, vector glyphs keep the native Island legible at compact sizes.
/// Deliberately no repeatForever/TimelineView: Live Activities aren't a continuous
/// animation surface. Native state changes use the system's update transitions.
struct AgentGlyph: View {
    let phase: String

    var body: some View {
        Group {
            switch phase {
            case "recording":
                RingGlyph()
            case "processing":
                ProcessingWave()
                    .stroke(.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            case "approval":
                Image(systemName: "exclamationmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(red: 1, green: 0.77, blue: 0.24))
            default:
                CursorGlyph()
            }
        }
        .accessibilityHidden(true)
    }
}

private struct RingGlyph: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Ellipse()
                    .stroke(.white.opacity(0.7), lineWidth: side * 0.065)
                    .frame(width: side * 0.59, height: side * 0.77)
                    .offset(x: side * 0.12, y: side * 0.04)
                Ellipse()
                    .stroke(.white, lineWidth: side * 0.12)
                    .frame(width: side * 0.59, height: side * 0.77)
            }
            .rotationEffect(.degrees(32))
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

private struct ProcessingWave: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let margin = rect.width * 0.06
        for step in 0...64 {
            let fraction = CGFloat(step) / 64
            let x = margin + fraction * (rect.width - margin * 2)
            let envelope = sin(fraction * .pi)
            let y = rect.midY - sin(fraction * .pi * 4) * envelope * rect.height * 0.35
            if step == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}

private struct CursorGlyph: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: width * 0.25, y: height * 0.08))
                    path.addLine(to: CGPoint(x: width * 0.88, y: height * 0.58))
                    path.addLine(to: CGPoint(x: width * 0.59, y: height * 0.63))
                    path.addLine(to: CGPoint(x: width * 0.72, y: height * 0.90))
                    path.addLine(to: CGPoint(x: width * 0.56, y: height * 0.97))
                    path.addLine(to: CGPoint(x: width * 0.43, y: height * 0.70))
                    path.addLine(to: CGPoint(x: width * 0.24, y: height * 0.90))
                    path.closeSubpath()
                }.fill(.white)
                Path { path in
                    path.move(to: CGPoint(x: width * 0.03, y: height * 0.42))
                    path.addLine(to: CGPoint(x: width * 0.13, y: height * 0.49))
                    path.move(to: CGPoint(x: width * 0.02, y: height * 0.64))
                    path.addLine(to: CGPoint(x: width * 0.12, y: height * 0.64))
                }.stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }
    }
}
