import SwiftUI

/// Looping motion built from signals. Each one is a plain effect: it claims
/// a property, reads `.time`, and stops (rests at its start value) under
/// Reduce Motion. None of them runs unless used.
extension XeerpeEffect {
    /// Slow scale in and out. `amount` is the peak growth: 0.04 = +4%.
    public static func breathe(period: Double = 4, amount: Double = 0.04) -> XeerpeEffect {
        scale(.time(period: period, from: 1, to: 1 + amount)).renamed("breathe")
    }

    /// Opacity swings between 1 and `low` (clamped to 0...1).
    public static func pulse(period: Double = 1.2, low: Double = 0.55) -> XeerpeEffect {
        opacity(.time(period: period, from: 1, to: low)).renamed("pulse")
    }

    /// A light band sweeping across the content once per `period`.
    /// Overlay slot; masked to the content's shape. Renders the content a
    /// second time for the mask, so avoid it on heavy views. Hidden from
    /// accessibility and hit testing; absent under Reduce Motion.
    public static func shimmer(_ color: Color = .white, period: Double = 2.4, width: Double = 0.18) -> XeerpeEffect {
        let phase = XeerpeSignal<Double>.time(period: period, from: -width, to: 1 + width, wave: .loop)
        return XeerpeEffect(name: "shimmer", slot: .overlay, claims: [.highlight], inputs: .time) { view, ctx in
            if ctx.reduceMotion { return view }
            let loc = Xeerpe.shimmerLocations(phase: phase.value(in: ctx), width: width)
            let band = LinearGradient(
                stops: [
                    .init(color: .clear, location: loc[0]),
                    .init(color: color.opacity(0.7), location: loc[1]),
                    .init(color: .clear, location: loc[2]),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            return AnyView(view.overlay(
                band.blendMode(.plusLighter).mask(view).allowsHitTesting(false).accessibilityHidden(true)
            ))
        }
    }
}
