import SwiftUI
import Foundation
import os

/// Where an effect acts on the view it decorates.
public enum XeerpeSlot: Sendable, Hashable, CaseIterable {
    /// The content's own pixels: color, filters, texture.
    case content
    /// Behind the content.
    case background
    /// Over the content.
    case overlay
    /// What part of the content shows.
    case mask
    /// The content's shape on screen: scale, rotation, distortion.
    case geometry
}

/// A visual property an effect takes ownership of. Two effects claiming the
/// same property in one chain are reported by `XeerpeChain.conflicts`.
public struct XeerpeProperty: Sendable, Hashable, RawRepresentable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public static let opacity: Self = "opacity"
    public static let blur: Self = "blur"
    public static let scale: Self = "scale"
    public static let shadow: Self = "shadow"
    public static let backgroundFill: Self = "backgroundFill"
    public static let highlight: Self = "highlight"
    public static let surface: Self = "surface"
    public static let lens: Self = "lens"
    public static let distortion: Self = "distortion"
    public static let reveal: Self = "reveal"
    public static let duo: Self = "duo"
    public static let rotation: Self = "rotation"
    public static let foregroundFill: Self = "foregroundFill"
    public static let pixelate: Self = "pixelate"
    public static let glitch: Self = "glitch"
    public static let burn: Self = "burn"
    public static let embers: Self = "embers"
    public static let scanlines: Self = "scanlines"
    public static let phosphor: Self = "phosphor"
    public static let barrel: Self = "barrel"
    public static let vignette: Self = "vignette"
    public static let dither: Self = "dither"
    public static let toon: Self = "toon"
    public static let halftone: Self = "halftone"
    public static let gooey: Self = "gooey"
    public static let smoke: Self = "smoke"
    public static let sparks: Self = "sparks"
    public static let genie: Self = "genie"
    public static let colorBleed: Self = "colorBleed"
    public static let tracking: Self = "tracking"
    public static let riso: Self = "riso"
    public static let bevel: Self = "bevel"
    public static let brushed: Self = "brushed"
    public static let foil: Self = "foil"
    public static let sparkle: Self = "sparkle"
    public static let guilloche: Self = "guilloche"
    public static let pearl: Self = "pearl"
    public static let grain: Self = "grain"
    public static let colorMap: Self = "colorMap"
    public static let grade: Self = "grade"
    public static let halation: Self = "halation"
    public static let lightLeak: Self = "lightLeak"
    public static let ascii: Self = "ascii"
    public static let flicker: Self = "flicker"
    public static let holo: Self = "holo"
    public static let chrome: Self = "chrome"
}

enum Xeerpe {
    /// The gradient line of a CSS linear gradient in a box of `size`: angle
    /// 0 points up, 90 right, and the line is long enough that the corners
    /// sit exactly at its ends. `span` above 1 lengthens it; `shift` -1...1
    /// slides it, but only within that extra length, so the corners never
    /// leave the gradient.
    static func cssLine(degrees: Double, size: CGSize, span: Double, shift: Double) -> (start: CGPoint, end: CGPoint) {
        let a = (degrees.isFinite ? degrees : 0) * .pi / 180
        let dir = CGPoint(x: sin(a), y: -cos(a))
        let full = abs(size.width * sin(a)) + abs(size.height * cos(a))
        let len = max(span.isFinite ? span : 1, 1)
        let travel = (len - 1) / 2 * full * min(max(shift.isNaN ? 0 : shift, -1), 1)
        let c = CGPoint(x: size.width / 2 + dir.x * travel, y: size.height / 2 + dir.y * travel)
        let half = full * len / 2
        return (CGPoint(x: c.x - dir.x * half, y: c.y - dir.y * half), CGPoint(x: c.x + dir.x * half, y: c.y + dir.y * half))
    }

    /// How hidden a pixel `distance` points from the focus is, 0 clear to 1
    /// hidden, for a clear circle of `radius` with an edge `softness` wide.
    /// A zero radius hides everything; the edge never gets wider than the
    /// radius, so the circle grows from nothing without a jump.
    static func focusHidden(distance: Double, radius: Double, softness: Double) -> Double {
        guard radius > 0 else { return 1 }
        let s = max(min(softness, radius), 0.0001)
        let t = clampUnit((distance - (radius - s)) / (2 * s))
        return t * t * (3 - 2 * t)
    }

    private static func unitClamp(_ v: Double) -> Double { v.isNaN ? 0 : min(max(v, -1), 1) }

    /// A point in the view as -1...1 from its center.
    static func normalizedTouch(_ p: CGPoint, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGPoint(x: unitClamp(p.x / size.width * 2 - 1), y: unitClamp(p.y / size.height * 2 - 1))
    }

    /// A drag translation as -1...1, half the view's size per unit.
    static func normalizedDrag(_ t: CGSize, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGPoint(x: unitClamp(t.width / (size.width / 2)), y: unitClamp(t.height / (size.height / 2)))
    }

    /// Offset (fraction of the size) of the layer at `depthIndex` for a
    /// reaction vector: layers at different depths move by different amounts.
    static func parallax(_ v: CGPoint, depthIndex: Int, strength: Double) -> CGPoint {
        let depths = [1.0, 0.65, 1.35, 0.85, 1.15]
        let d = 0.12 * strength * depths[abs(depthIndex) % depths.count]
        return CGPoint(x: v.x * d, y: v.y * d)
    }

    /// The fold reveal of iPhone Duo: at `edge` 0...1 across the surface and
    /// `progress` 0...1, the blur radius in points and the darkening 0...1.
    /// The first fifth of the surface never darkens.
    static func duoFactors(edge: Double, progress: Double, maxBlur: Double) -> (radius: Double, darken: Double) {
        let p = clampUnit(progress)
        let motion = p * p * (3 - 2 * p)
        let blur = clampUnit(edge), dark = clampUnit((edge - 0.2) / 0.8)
        return (maxBlur * motion * pow(blur, 1.35), min(1, 2 * motion * pow(dark, 1.35)))
    }

    /// RGBA channels (0...1) of a 0xRRGGBBAA value.
    static func channels(rgba v: UInt32) -> (r: Double, g: Double, b: Double, a: Double) {
        (Double(v >> 24 & 255) / 255, Double(v >> 16 & 255) / 255, Double(v >> 8 & 255) / 255, Double(v & 255) / 255)
    }

    static func color(rgba v: UInt32) -> Color {
        let c = channels(rgba: v)
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }

    /// Stops clamped to 0...1 and sorted by position (stable).
    static func normalizedStops(_ stops: [XeerpeStop]) -> [XeerpeStop] {
        stops.map { XeerpeStop($0.rgba, min(max($0.at.isNaN ? 0 : $0.at, 0), 1)) }
            .enumerated().sorted { ($0.element.at, $0.offset) < ($1.element.at, $1.offset) }.map(\.element)
    }

    /// Unit-length gradient axis in the unit square for a CSS angle:
    /// 0 points up, 90 points right.
    static func cssAxis(degrees: Double) -> (start: CGPoint, end: CGPoint) {
        gradientPoints(angleDegrees: degrees - 90)
    }

    /// `count` points in the unit square, always the same for one seed
    /// (SplitMix64). Kept after the first call, since starfields redraw
    /// them every frame.
    static func starPoints(count: Int, seed: Int) -> [CGPoint] {
        let key = StarKey(count: count, seed: seed)
        if let hit = starCache.withLock({ $0[key] }) { return hit }
        let points = makeStarPoints(count: count, seed: seed)
        starCache.withLock { $0[key] = points }
        return points
    }

    private struct StarKey: Hashable { let count: Int, seed: Int }
    private static let starCache = OSAllocatedUnfairLock(initialState: [StarKey: [CGPoint]]())

    private static func makeStarPoints(count: Int, seed: Int) -> [CGPoint] {
        var state = UInt64(truncatingIfNeeded: seed) &+ 0x9E3779B97F4A7C15
        func next() -> Double {
            state = state &+ 0x9E3779B97F4A7C15
            return splitMix(state)
        }
        return (0..<max(count, 0)).map { _ in CGPoint(x: next(), y: next()) }
    }

    /// A value in 0..<1, always the same for one `n`.
    static func unitHash(_ n: Int) -> Double {
        splitMix(UInt64(truncatingIfNeeded: n) &* 0x9E3779B97F4A7C15)
    }

    /// The SplitMix64 finalizer, scaled to 0..<1.
    static func splitMix(_ x: UInt64) -> Double {
        var z = x
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }

    /// Below this progress a reveal blocks touches and hides its content
    /// from accessibility, so a hidden control cannot be activated.
    static func revealIsInteractive(_ progress: Double) -> Bool { progress.isFinite && progress > 0.05 }

    /// Seconds a tap keeps driving frames and the ripple.
    static let rippleLifetime: TimeInterval = 3.5

    /// Distance from `p` to the farthest corner of a rect of `size` at the origin.
    static func farthestCorner(from p: CGPoint, in size: CGSize) -> Double {
        hypot(max(p.x, size.width - p.x), max(p.y, size.height - p.y))
    }

    /// Clamps to 0...1; NaN becomes 0.
    static func clampUnit(_ v: Double) -> Double { v.isNaN ? 0 : min(max(v, 0), 1) }
    /// Clamps to 0...; NaN becomes 0.
    static func clampNonNegative(_ v: Double) -> Double { v.isNaN ? 0 : max(v, 0) }

    /// Endpoints of a unit-length gradient axis through the center of the
    /// unit square, rotated `angleDegrees` clockwise from the +x axis.
    static func gradientPoints(angleDegrees: Double) -> (start: CGPoint, end: CGPoint) {
        let r = (angleDegrees.isFinite ? angleDegrees : 0) * .pi / 180
        let dx = cos(r) / 2, dy = sin(r) / 2
        return (CGPoint(x: 0.5 - dx, y: 0.5 - dy), CGPoint(x: 0.5 + dx, y: 0.5 + dy))
    }

    /// Three non-decreasing stop locations in 0...1 for a highlight band of
    /// half-width `width` centered on `phase`.
    static func shimmerLocations(phase: Double, width: Double) -> [Double] {
        let p = phase.isNaN ? 0 : phase
        let w = clampNonNegative(width)
        return [p - w, p, p + w].map { clampUnit($0) }
    }
}
