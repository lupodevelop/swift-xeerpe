import SwiftUI

/// While loading: the content's redacted placeholder with a light sweeping
/// across it. When loading ends the real content comes in with a reveal.
/// `progress` is 0 while loading and 1 when loaded; animate the change.
struct XeerpeLoadingView: View, Animatable {
    let content: AnyView
    nonisolated(unsafe) var progress: Double
    let reveal: XeerpeReveal
    let glow: Color

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = Xeerpe.clampUnit(progress)
        ZStack {
            if p < 1 {
                XeerpeTicker(paused: p > 0) { now in
                    let phase = now.truncatingRemainder(dividingBy: 1.4) / 1.4
                    let loc = Xeerpe.shimmerLocations(phase: phase * 1.6 - 0.3, width: 0.22)
                    content.redacted(reason: .placeholder)
                        .overlay {
                            LinearGradient(stops: [.init(color: .clear, location: loc[0]), .init(color: .white.opacity(0.55), location: loc[1]),
                                                   .init(color: .clear, location: loc[2])], startPoint: .leading, endPoint: .trailing)
                                .mask(content.redacted(reason: .placeholder))
                                .blendMode(.plusLighter)
                        }
                }
                .opacity(1 - p)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            XeerpeRevealView(content: content, progress: p, style: reveal, glow: glow)
        }
    }
}

extension XeerpeEffect {
    /// A skeleton while `isLoading`, then the content revealed with
    /// `reveal`. Change `isLoading` inside `withAnimation` for the reveal to play.
    public static func loading(_ isLoading: Bool, reveal: XeerpeReveal = .wipe(angle: 0, softness: 0.35), glow: Color = .white) -> XeerpeEffect {
        XeerpeEffect(name: "loading", slot: .mask, claims: [.reveal]) { view in
            AnyView(XeerpeLoadingView(content: view, progress: isLoading ? 0 : 1, reveal: reveal, glow: glow))
        }
    }
}
