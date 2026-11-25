import SwiftUI

public enum XeerpeWave: Sendable {
    /// Smooth back-and-forth between `from` and `to`.
    case sine
    /// Rises from `from` to `to`, then jumps back.
    case loop
}

/// A typed source of a parameter value, resolved against the local context
/// each time the view renders. Not an event bus: it holds no state.
public struct XeerpeSignal<Value> {
    public let inputs: XeerpeInput
    let resolve: (XeerpeContext) -> Value

    init(inputs: XeerpeInput = [], resolve: @escaping (XeerpeContext) -> Value) {
        self.inputs = inputs
        self.resolve = resolve
    }

    @MainActor
    public func value(in context: XeerpeContext) -> Value { resolve(context) }

    public func map<T>(_ transform: @escaping (Value) -> T) -> XeerpeSignal<T> {
        XeerpeSignal<T>(inputs: inputs) { transform(self.resolve($0)) }
    }

    /// Explicit combination of two sources; the caller picks the policy.
    public static func combine<A, B>(
        _ a: XeerpeSignal<A>,
        _ b: XeerpeSignal<B>,
        using f: @escaping (A, B) -> Value
    ) -> XeerpeSignal<Value> {
        XeerpeSignal(inputs: a.inputs.union(b.inputs)) { f(a.resolve($0), b.resolve($0)) }
    }
}

extension XeerpeSignal: ExpressibleByFloatLiteral where Value == Double {
    public init(floatLiteral value: Double) { self.init { _ in value } }
}

extension XeerpeSignal: ExpressibleByIntegerLiteral where Value == Double {
    public init(integerLiteral value: Int) { self.init { _ in Double(value) } }
}

extension XeerpeSignal {
    public static func constant(_ v: Value) -> Self { .init { _ in v } }
}

extension XeerpeValueConvertible where Self == XeerpeValue {
    /// Reads app-owned state on every render.
    public static func binding(_ b: Binding<Double>) -> Self { .init { _ in b.wrappedValue } }
    /// 1 while `b` is true, else 0.
    public static func binding(_ b: Binding<Bool>) -> Self { .init { _ in b.wrappedValue ? 1 : 0 } }

    /// `from` while not hovered, `to` while hovered. Unavailable where the
    /// platform has no pointer or gaze hover (tvOS, watchOS): stays `from`.
    public static func hover(from: Double, to: Double) -> Self {
        .init(inputs: .hover) { $0.isHovering ? to : from }
    }

    public static func press(from: Double, to: Double) -> Self {
        .init(inputs: .press) { $0.isPressed ? to : from }
    }

    /// Reads the environment focus of the enclosing focusable view.
    public static func focus(from: Double, to: Double) -> Self {
        .init(inputs: .focus) { $0.isFocused ? to : from }
    }

    /// Oscillates (or loops) between `from` and `to` every `period` seconds.
    /// With Reduce Motion on it stays at `from`. A non-finite or non-positive
    /// period is treated as 1 second.
    public static func time(period: Double, from: Double = 0, to: Double = 1, wave: XeerpeWave = .sine) -> Self {
        let T = (period.isFinite && period > 0) ? period : 1
        return .init(inputs: .time) { ctx in
            if ctx.reduceMotion { return from }
            let p = (ctx.time / T).truncatingRemainder(dividingBy: 1)
            let phase = p < 0 ? p + 1 : p
            let w = wave == .sine ? 0.5 - 0.5 * cos(2 * .pi * phase) : phase
            return from + (to - from) * w
        }
    }
}

/// Resolvers run only through `value(in:)`, which is main-actor isolated,
/// so sharing a signal across isolation domains cannot race.
extension XeerpeSignal: @unchecked Sendable {}
