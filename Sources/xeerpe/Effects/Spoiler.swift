import SwiftUI

extension Xeerpe {
    /// How far the reveal front travels: from 2 bands before `origin`
    /// (everything covered at progress 0) to 2 bands past the farthest
    /// corner of `size`, past the noisy edge (everything shown at 1).
    static func spoilerReach(from origin: CGPoint, in size: CGSize, band: Double) -> Double {
        farthestCorner(from: origin, in: size) + band * 4
    }
}

/// Particles over the content until it is tapped; the tap starts a front
/// that dissolves them outward from the tap point. A second tap covers it
/// again from there. Frames run only while something is covered.
struct XeerpeSpoilerView: View, Animatable {
    let content: AnyView
    let tint: Color
    let band: Double
    nonisolated(unsafe) var progress: Double
    let origin: CGPoint
    let toggle: (CGPoint) -> Void
    @State private var size: CGSize = .zero

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let shown = progress >= 1
        #if os(watchOS)
        content.redacted(reason: shown ? [] : .placeholder).onTapGesture { toggle(.zero) }
        #else
        XeerpeTicker(paused: shown) { now in
            content.layerEffect(
                XeerpeShaders.library.xeerpeSpoiler(
                    .boundingRect, .float(Float(now.truncatingRemainder(dividingBy: 3600))),
                    .float2(origin), .float(Float(Xeerpe.spoilerReach(from: origin, in: size, band: band) * Xeerpe.clampUnit(progress) - band * 2)),
                    .float(Float(band)), .color(tint)),
                maxSampleOffset: .zero)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .accessibilityHidden(!shown)
        .contentShape(Rectangle())
        #if os(tvOS)
        .onTapGesture { toggle(CGPoint(x: size.width / 2, y: size.height / 2)) }
        #else
        // Simultaneous: a tap gesture already on the content (a feedback, a
        // button) would otherwise win and this one would never fire.
        .simultaneousGesture(SpatialTapGesture().onEnded { toggle($0.location) })
        #endif
        #endif
    }
}

/// Owns the reveal state so the effect itself stays a value.
private struct SpoilerHost: View {
    let content: AnyView
    let tint: Color
    let band: Double
    let duration: Double
    @State private var progress = 0.0
    @State private var origin = CGPoint.zero

    var body: some View {
        XeerpeSpoilerView(content: content, tint: tint, band: band, progress: progress, origin: origin) { p in
            origin = p
            withAnimation(.easeOut(duration: duration)) { progress = progress > 0.5 ? 0 : 1 }
        }
        .accessibilityAction(named: progress > 0.5 ? "Hide spoiler" : "Show spoiler") {
            withAnimation(.easeOut(duration: duration)) { progress = progress > 0.5 ? 0 : 1 }
        }
    }
}

extension XeerpeEffect {
    /// Hides the content under drifting particles, like a chat spoiler.
    /// A tap dissolves them outward from the tap point in `duration`
    /// seconds; another tap brings them back. Apply it to the text, not to
    /// its bubble, so the particles fill only the text's frame.
    public static func spoiler(_ tint: Color = .white, duration: Double = 0.9) -> XeerpeEffect {
        XeerpeEffect(name: "spoiler", slot: .mask, claims: [.reveal]) { view in
            AnyView(SpoilerHost(content: view, tint: tint, band: 14, duration: max(duration, 0.05)))
        }
    }
}
