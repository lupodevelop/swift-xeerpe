import SwiftUI

/// A 2D signal, each component -1...1.
public typealias XeerpeVector = XeerpeSignal<CGPoint>

extension XeerpeSignal where Value == CGPoint {
    /// Device tilt. On devices without an accelerometer, the pointer's
    /// offset from the center of the view.
    public static var tilt: XeerpeVector { .init(inputs: .tilt) { $0.tilt } }
    /// Drag offset, springing back to zero when released.
    public static var drag: XeerpeVector { .init(inputs: .drag) { $0.drag } }
    /// Finger or pointer position from the center; zero when untouched.
    public static var touch: XeerpeVector { .init(inputs: .touch) { $0.touch ?? .zero } }

    /// The horizontal component.
    public var x: XeerpeValue { map { Double($0.x) } }
    /// The vertical component, growing downward.
    public var y: XeerpeValue { map { Double($0.y) } }
    /// Distance from the center, 0...1.
    public var length: XeerpeValue { map { Swift.min(Double(hypot($0.x, $0.y)), 1) } }
}

extension XeerpeValueConvertible where Self == XeerpeValue {
    /// 0 with nothing on the view, easing to 1 while it is hovered or touched.
    public static var presence: XeerpeValue { .init(inputs: .touch) { $0.presence } }
    /// 1 while the app is inactive or in the background (the app switcher,
    /// a call, Control Center), else 0.
    public static var inactive: XeerpeValue { .init(inputs: .scene) { $0.isInactive ? 1 : 0 } }
    /// 1 while the system is in Low Power Mode, else 0.
    public static var lowPower: XeerpeValue { .init { $0.isLowPower ? 1 : 0 } }
}

extension XeerpeSignal where Value == Double {
    /// Maps `input` linearly onto `a`...`b`, clamping outside values; NaN gives `a`.
    public func remap(_ input: ClosedRange<Double>, to a: Double, _ b: Double) -> XeerpeValue {
        map { v in
            guard !v.isNaN else { return a }
            let span = Swift.max(input.upperBound - input.lowerBound, .ulpOfOne)
            let t = (Swift.min(Swift.max(v, input.lowerBound), input.upperBound) - input.lowerBound) / span
            return a + (b - a) * t
        }
    }
}

/// Exponential smoothing toward a target, used so vector signals glide
/// instead of jumping. Never overshoots.
final class XeerpeSmoother {
    private var value: CGPoint?
    private var last = 0.0
    private let rate: Double
    init(rate: Double = 10) { self.rate = rate }

    func step(_ target: CGPoint, at time: Double) -> CGPoint {
        guard let v = value else { value = target; last = time; return target }
        let k = 1 - exp(-Swift.max(0, time - last) * rate)
        last = time
        let next = CGPoint(x: v.x + (target.x - v.x) * k, y: v.y + (target.y - v.y) * k)
        value = next
        return next
    }
}

final class XeerpeSmoothers {
    let tilt = XeerpeSmoother(), touch = XeerpeSmoother(), drag = XeerpeSmoother(rate: 7)
    let focus = XeerpeSmoother(rate: 14), presence = XeerpeSmoother(rate: 6)
    var lastFocus = CGPoint.zero
}
