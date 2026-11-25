import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS) || os(tvOS)
import AudioToolbox
#endif

extension Xeerpe {
    static func fires(from old: Int, to new: Int, risingOnly: Bool) -> Bool {
        risingOnly ? new > old : new != old
    }

    /// Index of the detent `v` (0...1) falls in, out of `count` equal steps.
    static func detent(_ v: Double, count: Int) -> Int {
        guard v.isFinite else { return 0 }
        return Int((clampUnit(v) * Double(max(count, 1))).rounded(.down))
    }
}

/// When a feedback fires: each time `signal` changes, or with `risingOnly`
/// only when it goes up (a press, not its release).
public struct XeerpeTrigger: Sendable {
    /// The count the trigger watches.
    public let signal: XeerpeSignal<Int>
    /// Whether only increases fire.
    public let risingOnly: Bool

    public init(_ signal: XeerpeSignal<Int>, risingOnly: Bool = false) {
        self.signal = signal; self.risingOnly = risingOnly
    }

    /// Each tap.
    public static var tap: XeerpeTrigger {
        XeerpeTrigger(.init(inputs: .tap) { ctx in ctx.tap.map { Int(($0.time * 1000).rounded()) } ?? 0 })
    }
    /// The moment a press starts.
    public static var press: XeerpeTrigger { XeerpeTrigger(.init(inputs: .press) { $0.isPressed ? 1 : 0 }, risingOnly: true) }
    /// The pointer entering the view.
    public static var enter: XeerpeTrigger { XeerpeTrigger(.init(inputs: .hover) { $0.isHovering ? 1 : 0 }, risingOnly: true) }
    /// `value` (0...1) passing each of `count` detents, like a dial clicking.
    public static func steps(_ value: some XeerpeValueConvertible, count: Int) -> XeerpeTrigger {
        XeerpeTrigger(value.xeerpeValue.map { Xeerpe.detent($0, count: count) })
    }
    /// `value` going above `threshold`.
    public static func crossing(_ value: some XeerpeValueConvertible, above threshold: Double) -> XeerpeTrigger {
        XeerpeTrigger(value.xeerpeValue.map { $0 > threshold ? 1 : 0 }, risingOnly: true)
    }
}

/// A short system sound.
public enum XeerpeSound: Sendable {
    case tick, pop, glass
    /// A named system sound on macOS, a system sound id elsewhere.
    case system(name: String, id: UInt32)

    @MainActor func play() {
        #if os(macOS)
        let name = switch self { case .tick: "Tink"; case .pop: "Pop"; case .glass: "Glass"; case .system(let n, _): n }
        NSSound(named: NSSound.Name(name))?.play()
        #elseif os(iOS) || os(visionOS) || os(tvOS)
        let id: UInt32 = switch self { case .tick: 1104; case .pop: 1105; case .glass: 1057; case .system(_, let i): i }
        AudioServicesPlaySystemSound(id)
        #endif
    }
}

private struct FeedbackPlayer: ViewModifier {
    let value: Int
    let risingOnly: Bool
    let haptic: SensoryFeedback?
    let sound: XeerpeSound?
    @State private var fired = 0

    func body(content: Content) -> some View {
        let v = content.onChange(of: value) { old, new in
            guard Xeerpe.fires(from: old, to: new, risingOnly: risingOnly) else { return }
            fired &+= 1
            sound?.play()
        }
        if let haptic { v.sensoryFeedback(haptic, trigger: fired) } else { v }
    }
}

extension XeerpeEffect {
    /// Plays a haptic, a sound, or both when `trigger` fires. Haptics need
    /// hardware that has them (a phone, a watch, a Force Touch trackpad
    /// while dragging); elsewhere they do nothing.
    public static func feedback(_ haptic: SensoryFeedback? = .selection, sound: XeerpeSound? = nil, on trigger: XeerpeTrigger) -> XeerpeEffect {
        XeerpeEffect(name: "feedback", slot: .content, inputs: trigger.signal.inputs) { view, ctx in
            AnyView(view.modifier(FeedbackPlayer(value: trigger.signal.value(in: ctx), risingOnly: trigger.risingOnly,
                                                 haptic: haptic, sound: sound)))
        }
    }

    /// Blurs and dims the whole view by `amount` (0 clear, 1 hidden): a
    /// Bool, `.hover(from: 1, to: 0)` to show it only under the pointer,
    /// or `XeerpeValue.inactive` to hide it when the app leaves the foreground.
    /// Hidden content is also hidden from accessibility. With Reduce
    /// Transparency on, an opaque cover in the background color fades in
    /// instead of the blur.
    public static func privacy(_ amount: XeerpeValue, blur: Double = 24) -> XeerpeEffect {
        XeerpeEffect(name: "privacy", slot: .content, claims: [.blur], inputs: amount.inputs) { view, ctx in
            let k = Xeerpe.clampUnit(amount.value(in: ctx))
            if ctx.reduceTransparency {
                return AnyView(view.overlay { Rectangle().fill(.background).opacity(k).allowsHitTesting(false) }
                    .accessibilityHidden(k > 0.5))
            }
            return AnyView(view.blur(radius: max(blur, 0) * k).saturation(1 - 0.6 * k).brightness(-0.12 * k)
                .accessibilityHidden(k > 0.5))
        }
    }
}
