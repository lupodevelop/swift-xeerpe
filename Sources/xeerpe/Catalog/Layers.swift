import SwiftUI

/// A color stop: `rgba` is 0xRRGGBBAA, `at` is 0...1 along the gradient.
public struct XeerpeStop: Sendable, Hashable {
    public var rgba: UInt32
    public var at: Double
    /// A stop of color `rgba` (0xRRGGBBAA) at `at` (0...1).
    public init(_ rgba: UInt32, _ at: Double) { self.rgba = rgba; self.at = at }
}

/// One drawing step of a layered surface. Plain data: presets built from
/// layers can be listed, searched, compared and shown as code.
///
/// Fills (`base`, `stops`, `blob`) stack with the first one listed on top.
/// Overlays (`vignette`, `grid`, `dots`, `stars`, `rays`) are drawn above all
/// fills in the order listed, and `grain` and `noise` are applied last.
public enum XeerpeLayer: Sendable, Hashable {
    /// A flat color under everything.
    case base(UInt32)
    /// A linear gradient. `css` is a CSS angle (0 up, 90 right). `span` above 1
    /// stretches the gradient past the edges, so only part of it shows.
    case stops([XeerpeStop], css: Double, span: Double = 1)
    /// A radial gradient centered at `x`,`y` (0...1). `w`,`h` are ellipse radii as
    /// fractions of the size; without them it is a circle reaching the farthest corner.
    case blob(x: Double, y: Double, from: UInt32, to: UInt32, fromAt: Double, toAt: Double, w: Double?, h: Double?)
    /// Darkens (or tints) the edges. `spread` 0...1 is how far in it reaches.
    case vignette(color: UInt32, intensity: Double, spread: Double)
    case grid(color: UInt32, size: Double, line: Double, opacity: Double)
    case dots(color: UInt32, size: Double, radius: Double, opacity: Double)
    case stars(color: UInt32, count: Int, seed: Int, radius: Double, opacity: Double)
    case rays(color: UInt32, opacity: Double, count: Int, x: Double, y: Double, css: Double)
    /// Film grain, `intensity` 1 is a light, even speckle.
    case grain(Double)
    /// Soft mottled noise, `scale` is its frequency.
    case noise(opacity: Double, scale: Double)

    var isFill: Bool {
        switch self {
        case .base, .stops, .blob: true
        default: false
        }
    }
}

/// Slow movement a surface can carry. `period` is in seconds. Under Reduce
/// Motion every one of them rests in its first pose.
public enum XeerpeMotion: Sendable, Hashable {
    /// Blobs swell and shrink a little.
    case breathe(period: Double)
    /// Blobs drift in slow loops.
    case aurora(period: Double)
    /// Gradients slide along their axis.
    case drift(period: Double)
    /// A light band sweeps across.
    case shimmer(period: Double)
}
