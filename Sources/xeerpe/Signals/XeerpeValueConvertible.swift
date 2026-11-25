import CoreGraphics

/// Anything an effect parameter takes as a value: a number, a Bool (1 when
/// true) or a signal. Plain values are read when the view renders, so a
/// value computed in `body` needs no wrapping:
///
///     .bloom(intensity: glow * 0.35)
///     .privacy(.max(isHidden, .inactive))
public protocol XeerpeValueConvertible {
    var xeerpeValue: XeerpeValue { get }
}

extension XeerpeSignal: XeerpeValueConvertible where Value == Double {
    public var xeerpeValue: XeerpeValue { self }
}

extension Double: XeerpeValueConvertible {
    public var xeerpeValue: XeerpeValue { .constant(self) }
}

extension Int: XeerpeValueConvertible {
    public var xeerpeValue: XeerpeValue { .constant(Double(self)) }
}

extension CGFloat: XeerpeValueConvertible {
    public var xeerpeValue: XeerpeValue { .constant(Double(self)) }
}

extension Bool: XeerpeValueConvertible {
    public var xeerpeValue: XeerpeValue { .constant(self ? 1 : 0) }
}

/// Signals are declared here rather than on `XeerpeSignal`, so the
/// leading-dot form works both where a parameter is an `XeerpeValue` and
/// where it takes any `XeerpeValueConvertible`.
extension XeerpeValueConvertible where Self == XeerpeValue {
    /// The larger of two values at each render, e.g. hidden by a toggle or
    /// while the app is in the background.
    public static func max(_ a: some XeerpeValueConvertible, _ b: some XeerpeValueConvertible) -> XeerpeValue {
        .combine(a.xeerpeValue, b.xeerpeValue, using: Swift.max)
    }

    /// The smaller of two values at each render.
    public static func min(_ a: some XeerpeValueConvertible, _ b: some XeerpeValueConvertible) -> XeerpeValue {
        .combine(a.xeerpeValue, b.xeerpeValue, using: Swift.min)
    }
}

extension XeerpeSignal where Value == Double {
    /// Maps 0...1 linearly onto `a`...`b`, clamping outside values; `b` may
    /// be below `a`. NaN gives `a`.
    public func mapped(to a: Double, _ b: Double) -> XeerpeValue { remap(0...1, to: a, b) }

    public static func + (l: Self, r: Self) -> Self { .combine(l, r, using: +) }
    public static func + (l: Self, r: Double) -> Self { l.map { $0 + r } }
    public static func + (l: Double, r: Self) -> Self { r.map { l + $0 } }
    public static func - (l: Self, r: Self) -> Self { .combine(l, r, using: -) }
    public static func - (l: Self, r: Double) -> Self { l.map { $0 - r } }
    public static func - (l: Double, r: Self) -> Self { r.map { l - $0 } }
    public static func * (l: Self, r: Self) -> Self { .combine(l, r, using: *) }
    public static func * (l: Self, r: Double) -> Self { l.map { $0 * r } }
    public static func * (l: Double, r: Self) -> Self { r.map { l * $0 } }
}
