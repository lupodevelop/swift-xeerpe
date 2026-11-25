import SwiftUI

/// How a reveal spreads. All of them are driven only by `progress` (0 hidden,
/// 1 shown), so they follow `withAnimation`, can be reversed and interrupted
/// mid-way, and need no frame updates of their own.
public struct XeerpeReveal: Sendable {
    enum Mode: Float { case wipe = 0, iris = 1, fluid = 2, dust = 3 }
    let mode: Mode
    let angle: Double
    let origin: UnitPoint
    let softness: Double
    let turbulence: Double

    /// A straight edge sweeping across. `angle` in degrees: 0 left to right,
    /// 90 top to bottom. `softness` is the edge width as a fraction of the sweep.
    public static func wipe(angle: Double = 0, softness: Double = 0.12) -> XeerpeReveal {
        XeerpeReveal(mode: .wipe, angle: angle, origin: .center, softness: softness, turbulence: 0)
    }

    /// A circle growing from `from`.
    public static func iris(from origin: UnitPoint = .center, softness: Double = 0.1) -> XeerpeReveal {
        XeerpeReveal(mode: .iris, angle: 0, origin: origin, softness: softness, turbulence: 0)
    }

    /// An iris whose edge is warped by noise, like liquid spreading.
    /// `turbulence` 0...1 is how far the edge wanders.
    public static func fluid(from origin: UnitPoint = .center, turbulence: Double = 0.45, softness: Double = 0.18) -> XeerpeReveal {
        XeerpeReveal(mode: .fluid, angle: 0, origin: origin, softness: softness, turbulence: turbulence)
    }

    /// A fluid iris from the center with the default settings.
    public static var fluid: XeerpeReveal { fluid() }

    /// A wipe that breaks into grains: each grain crosses the edge at its own
    /// moment, so the content turns to dust (or settles from it). `grain`
    /// 0...1 is how far ahead or behind a grain can be.
    public static func dust(angle: Double = 0, grain: Double = 0.6, softness: Double = 0.08) -> XeerpeReveal {
        XeerpeReveal(mode: .dust, angle: angle, origin: .center, softness: softness, turbulence: grain)
    }
}

/// Animatable, so a change of `progress` under `withAnimation` or a
/// transition is interpolated frame by frame.
struct XeerpeRevealView: View, Animatable {
    let content: AnyView
    nonisolated(unsafe) var progress: Double
    let style: XeerpeReveal
    let glow: Color

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = Xeerpe.clampUnit(progress)
        #if os(watchOS)
        // No shaders on watchOS: a plain fade.
        content.opacity(p).allowsHitTesting(Xeerpe.revealIsInteractive(p)).accessibilityHidden(!Xeerpe.revealIsInteractive(p))
        #else
        content
            .colorEffect(XeerpeShaders.library.xeerpeReveal(
                .boundingRect, .float(p), .float(Float(style.mode.rawValue)),
                .float2(CGPoint(x: style.origin.x, y: style.origin.y)),
                .float(Float(style.angle * .pi / 180)), .float(Float(Xeerpe.clampUnit(style.softness))),
                .float(Float(Xeerpe.clampUnit(style.turbulence))), .color(glow)))
            .allowsHitTesting(Xeerpe.revealIsInteractive(p))
            .accessibilityHidden(!Xeerpe.revealIsInteractive(p))
        #endif
    }
}

extension XeerpeEffect {
    /// Shows or hides everything built so far in the chain. While `progress`
    /// is 0.05 or less the content takes no touches and is hidden from
    /// accessibility; above it, both are back. `glow` colors the moving edge
    /// (`.clear` for none); it only lights pixels the content already has.
    /// To reveal real content, pass a binding and animate it.
    public static func reveal(_ style: XeerpeReveal = .fluid, progress: XeerpeValue, glow: Color = .white) -> XeerpeEffect {
        XeerpeEffect(name: "reveal", slot: .mask, claims: [.reveal], inputs: progress.inputs) { view, ctx in
            AnyView(XeerpeRevealView(content: view, progress: progress.value(in: ctx), style: style, glow: glow))
        }
    }
}

/// Reveal as a SwiftUI insertion and removal transition, fully shown at the
/// identity phase. SwiftUI drives the phases; there is no coordinator.
public struct XeerpeTransition: Transition {
    /// How the content appears.
    public var style: XeerpeReveal
    /// The color of the light along the edge.
    public var glow: Color
    public init(style: XeerpeReveal = .fluid, glow: Color = .white) { self.style = style; self.glow = glow }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        XeerpeRevealView(content: AnyView(content), progress: phase.isIdentity ? 1 : 0, style: style, glow: glow)
    }
}

extension Transition where Self == XeerpeTransition {
    /// A transition that reveals the view with `style`, with `glow` along the edge.
    public static func xeerpe(_ style: XeerpeReveal = .fluid, glow: Color = .white) -> XeerpeTransition {
        XeerpeTransition(style: style, glow: glow)
    }
}
