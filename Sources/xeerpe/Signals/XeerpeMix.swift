import SwiftUI

/// A value that can be blended. `t` is clamped to 0...1; NaN counts as 0.
public protocol XeerpeMixable {
    static func mix(_ a: Self, _ b: Self, _ t: Double) -> Self
}

extension Double: XeerpeMixable {
    public static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { let u = Xeerpe.clampUnit(t); return a * (1 - u) + b * u }
}

extension Color: XeerpeMixable {
    /// Blends the two colors, alpha included. From the 18 systems the
    /// blend is perceptual and resolved where the color is drawn, so
    /// adaptive colors follow that view's color scheme.
    public static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        if #available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *) {
            return a.mix(with: b, by: Xeerpe.clampUnit(t), in: .perceptual)
        }
        // shortcut: before the 18 systems the blend is in linear light and
        // resolved in a default (light) environment, so adaptive colors take
        // their light variant; drop it when the minimum reaches the 18 systems.
        let env = EnvironmentValues()
        let x = a.resolve(in: env), y = b.resolve(in: env)
        let f = Float(Xeerpe.clampUnit(t))
        func m(_ p: Float, _ q: Float) -> Double { Double(p + (q - p) * f) }
        return Color(.sRGBLinear,
                     red: m(x.linearRed, y.linearRed), green: m(x.linearGreen, y.linearGreen),
                     blue: m(x.linearBlue, y.linearBlue), opacity: m(x.opacity, y.opacity))
    }
}

/// Element-wise; the shorter array decides the length.
extension Array: XeerpeMixable where Element: XeerpeMixable {
    public static func mix(_ a: [Element], _ b: [Element], _ t: Double) -> [Element] {
        zip(a, b).map { Element.mix($0, $1, t) }
    }
}

extension XeerpeSignal where Value: XeerpeMixable {
    /// Blend of `a` and `b` driven by another signal.
    public static func mix(_ a: Value, _ b: Value, by t: XeerpeSignal<Double>) -> Self {
        .init(inputs: t.inputs) { Value.mix(a, b, t.resolve($0)) }
    }

    /// Walks through `stops` as `phase` goes 0...1, easing between
    /// neighbours. Share one `phase` across several effects and they mutate
    /// together. Out-of-range phase clamps to the ends.
    public static func keyframes(_ stops: [Value], phase: XeerpeSignal<Double>) -> Self {
        precondition(!stops.isEmpty, "keyframes needs at least one stop")
        return .init(inputs: phase.inputs) { ctx in
            guard stops.count > 1 else { return stops[0] }
            let p = Xeerpe.clampUnit(phase.resolve(ctx)) * Double(stops.count - 1)
            let i = Swift.min(Int(p), stops.count - 2)
            let f = p - Double(i)
            return Value.mix(stops[i], stops[i + 1], f * f * (3 - 2 * f))
        }
    }

    /// Loops through `stops` and back to the first, once per `period`.
    /// Rests on the first stop under Reduce Motion.
    public static func cycle(_ stops: [Value], period: Double) -> Self {
        keyframes(stops + [stops[0]], phase: XeerpeSignal<Double>.time(period: period, wave: .loop))
    }
}
