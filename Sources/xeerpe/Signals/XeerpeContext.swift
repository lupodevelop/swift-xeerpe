import CoreGraphics
import Foundation

/// The inputs an effect may depend on. A chain only wires up the inputs its
/// effects declare: no `.time` means no frame updates are scheduled.
public struct XeerpeInput: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    /// The clock. Frames run while an effect reads it.
    public static let time = XeerpeInput(rawValue: 1 << 0)
    /// Whether the pointer is over the view.
    public static let hover = XeerpeInput(rawValue: 1 << 1)
    /// Whether the view is being pressed.
    public static let press = XeerpeInput(rawValue: 1 << 2)
    /// Whether the view has focus.
    public static let focus = XeerpeInput(rawValue: 1 << 3)
    /// Continuous pointer position inside the view (where the platform has a pointer).
    public static let pointer = XeerpeInput(rawValue: 1 << 4)
    /// The last tap. The chain runs frames for a few seconds after a tap, then stops.
    public static let tap = XeerpeInput(rawValue: 1 << 5)
    /// Device tilt from the accelerometer (iOS, watchOS). Where there is
    /// none, the pointer's offset from the center stands in for it.
    public static let tilt = XeerpeInput(rawValue: 1 << 6)
    /// How far the view is being dragged; springs back to zero on release.
    public static let drag = XeerpeInput(rawValue: 1 << 7)
    /// Where the finger (or pointer) is on the view.
    public static let touch = XeerpeInput(rawValue: 1 << 8)
    /// Whether the scene is in the foreground.
    public static let scene = XeerpeInput(rawValue: 1 << 9)
}

/// Where and when the view was last tapped; `time` is on the same clock as `XeerpeContext.time`.
public struct XeerpeTap: Sendable, Equatable {
    /// Where the view was tapped, in its own coordinates.
    public var location: CGPoint
    /// When the view was tapped.
    public var time: TimeInterval
    public init(location: CGPoint, time: TimeInterval) { self.location = location; self.time = time }
}

/// Snapshot of local state handed to every effect at render time.
public struct XeerpeContext: Sendable {
    /// Seconds on the chain's clock.
    public var time: TimeInterval
    /// Whether the pointer is over the view.
    public var isHovering: Bool
    /// Whether the view is being pressed.
    public var isPressed: Bool
    /// Whether the view has focus.
    public var isFocused: Bool
    /// Pointer position in the view's own coordinates, nil when it is outside.
    public var pointer: CGPoint?
    /// The last tap, nil before the first.
    public var tap: XeerpeTap?
    /// The view's size in points.
    public var size: CGSize
    /// Each component -1...1, smoothed. x grows to the right, y downward.
    public var tilt: CGPoint
    /// -1...1 from the center, smoothed; nil when nothing touches the view.
    public var touch: CGPoint?
    /// -1...1, half the view's width or height per unit, smoothed.
    public var drag: CGPoint
    /// Where the finger or pointer last was, -1...1 from the center,
    /// smoothed. Unlike `touch` it stays put after release.
    public var focus: CGPoint
    /// 0 when nothing is on the view, 1 while the pointer hovers or a finger
    /// touches; it eases between the two.
    public var presence: Double
    /// With Reduce Motion on, moving effects hold still or move less.
    public var reduceMotion: Bool
    /// With Reduce Transparency on, effects that lay translucent or blurred
    /// light over the content draw it opaque or not at all: privacy covers
    /// the view, a blur sweep dims instead of blurring, edge glow keeps only
    /// its line, and bloom and glare are off.
    public var reduceTransparency: Bool
    /// Whether Increase Contrast is on.
    public var increasedContrast: Bool
    /// True while the scene is inactive or in the background.
    public var isInactive = false
    /// True while the system is in Low Power Mode. Chains then run at half
    /// the frame rate.
    public var isLowPower = false

    public init(
        time: TimeInterval = 0,
        isHovering: Bool = false,
        isPressed: Bool = false,
        isFocused: Bool = false,
        pointer: CGPoint? = nil,
        tap: XeerpeTap? = nil,
        size: CGSize = .zero,
        tilt: CGPoint = .zero,
        touch: CGPoint? = nil,
        drag: CGPoint = .zero,
        focus: CGPoint = .zero,
        presence: Double = 0,
        reduceMotion: Bool = false,
        reduceTransparency: Bool = false,
        increasedContrast: Bool = false
    ) {
        self.time = time
        self.isHovering = isHovering
        self.isPressed = isPressed
        self.isFocused = isFocused
        self.pointer = pointer
        self.tap = tap
        self.size = size
        self.tilt = tilt
        self.touch = touch
        self.drag = drag
        self.focus = focus
        self.presence = presence
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency
        self.increasedContrast = increasedContrast
    }
}
