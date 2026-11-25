import SwiftUI

extension Xeerpe {
    /// How far item `index` of `count` has risen (0 hidden, 1 in place) at
    /// `progress` 0...1. Items start one after another, each taking `spread`
    /// item-steps to arrive, and all are in place at 1.
    static func riseAmount(index: Int, count: Int, progress: Double, spread: Double) -> Double {
        guard progress.isFinite, count > 0 else { return 0 }
        if progress >= 1 { return 1 }
        let s = max(spread.isFinite ? spread : 1, 0.001)
        return clampUnit((clampUnit(progress) * (Double(count - 1) + s) - Double(index)) / s)
    }
}

extension XeerpeEffect {
    /// Shapes closer than about `radius` points melt into one blob, like
    /// drops of liquid: the alpha is blurred and cut at half. Meant for
    /// opaque shapes; the blob takes the color of the most opaque shape
    /// near each point. Not drawn on watchOS.
    public static func gooey(radius: Double = 12) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("gooey", claims: [.gooey])
        #else
        let r = radius.isFinite ? max(radius, 1) : 12
        return .shader("gooey", claims: [.gooey]) { _ in
            .layer(XeerpeShaders.library.xeerpeGooey(.boundingRect, .float(r)), maxSampleOffset: CGSize(width: r * 2, height: r * 2))
        }
        #endif
    }

    /// Smoke billowing up to `height` points from the content's top edge,
    /// fanning out and thinning as it rises. `amount` 0...1 is how dense.
    /// Keeps frames running; off under Reduce Motion and on watchOS.
    public static func smoke(_ amount: XeerpeValue = 1, color: Color = Color(white: 0.8), height: Double = 90) -> XeerpeEffect {
        let inputs = amount.inputs.union(.time)
        #if os(watchOS)
        return .passthrough("smoke", slot: .overlay, claims: [.smoke], inputs: inputs)
        #else
        let h = height.isFinite ? max(height, 8) : 90
        return .shader("smoke", slot: .overlay, claims: [.smoke], inputs: inputs) { ctx in
            let a = Xeerpe.clampUnit(amount.value(in: ctx))
            return .layer(XeerpeShaders.library.xeerpeSmoke(.boundingRect, .float(ctx.shaderTime), .float(a), .float(h), .color(color)),
                          maxSampleOffset: CGSize(width: h * 0.6 + 8, height: h + 8), enabled: a > 0 && !ctx.reduceMotion)
        }
        #endif
    }

    /// A burst of `count` sparks from where the view is tapped, flying out
    /// at about `speed` points a second and falling, gone in 0.9 s. Draws
    /// nothing until a tap; off under Reduce Motion and on watchOS.
    public static func sparks(_ color: Color = Color(red: 1, green: 0.8, blue: 0.3), count: Int = 18, speed: Double = 220) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("sparks", slot: .overlay, claims: [.sparks], inputs: .tap)
        #else
        let n = min(max(count, 1), 32), v = speed.isFinite ? max(speed, 0) : 220
        let reach = v * 1.5 * Xeerpe.sparkLifetime
        return .shader("sparks", slot: .overlay, claims: [.sparks], inputs: .tap) { ctx in
            let dt = ctx.tap.map { ctx.time - $0.time } ?? -1
            return .layer(XeerpeShaders.library.xeerpeSparks(.boundingRect, .float2(ctx.tap?.location ?? .zero), .float(dt), .float(Float(n)), .float(v), .color(color)),
                          maxSampleOffset: CGSize(width: reach, height: reach),
                          enabled: dt >= 0 && dt < Xeerpe.sparkLifetime && !ctx.reduceMotion)
        }
        #endif
    }

    /// Chroma smeared `amount` points to the right while brightness stays
    /// sharp, like a VHS tape. 0 leaves the content alone. Not drawn on watchOS.
    public static func colorBleed(_ amount: XeerpeValue) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("colorBleed", claims: [.colorBleed], inputs: amount.inputs)
        #else
        .shader("colorBleed", claims: [.colorBleed], inputs: amount.inputs) { ctx in
            let a = Xeerpe.clampNonNegative(amount.value(in: ctx))
            return .layer(XeerpeShaders.library.xeerpeColorBleed(.boundingRect, .float(a)), maxSampleOffset: CGSize(width: a, height: 0), enabled: a > 0)
        }
        #endif
    }

    /// VHS tracking: rows wobble sideways by up to `amount` points and a
    /// band of noise rolls down the view every 6.7 s, shifting the rows it
    /// crosses. Keeps frames running; off under Reduce Motion and on watchOS.
    public static func tracking(_ amount: XeerpeValue = 3) -> XeerpeEffect {
        let inputs = amount.inputs.union(.time)
        #if os(watchOS)
        return .passthrough("tracking", claims: [.tracking], inputs: inputs)
        #else
        return .shader("tracking", claims: [.tracking], inputs: inputs) { ctx in
            let a = Xeerpe.clampNonNegative(amount.value(in: ctx))
            return .layer(XeerpeShaders.library.xeerpeTracking(.boundingRect, .float(ctx.shaderTime), .float(a)),
                          maxSampleOffset: CGSize(width: a * 2, height: 0), enabled: a > 0 && !ctx.reduceMotion)
        }
        #endif
    }

    /// A risograph print: the content's darkness printed in two `inks` on
    /// white paper, the second ink shifted `offset` points from the first,
    /// with `grain` 0...1 of speckle. Not drawn on watchOS.
    public static func riso(_ inks: [Color] = [Color(red: 1, green: 0.28, blue: 0.55), Color(red: 0.1, green: 0.35, blue: 0.9)],
                            offset: Double = 2, grain: Double = 0.25) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("riso", claims: [.riso])
        #else
        let a = inks.first ?? .pink, b = inks.count > 1 ? inks[1] : a
        let o = offset.isFinite ? offset : 2, g = Xeerpe.clampUnit(grain)
        return .shader("riso", claims: [.riso]) { _ in
            .layer(XeerpeShaders.library.xeerpeRiso(.boundingRect, .color(a), .color(b), .float(o), .float(g)),
                   maxSampleOffset: CGSize(width: abs(o), height: abs(o) / 2))
        }
        #endif
    }
}

extension Xeerpe {
    /// Seconds a spark burst lasts after its tap.
    static let sparkLifetime = 0.9
}

/// Animatable, so a change of `progress` under `withAnimation` pours the
/// content in frame by frame.
struct XeerpeGenieView: View, Animatable {
    let content: AnyView
    nonisolated(unsafe) var progress: Double
    let target: UnitPoint

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = Xeerpe.clampUnit(progress)
        #if os(watchOS)
        content.scaleEffect(1 - p, anchor: target).opacity(1 - p)
        #else
        let tx = Float(Xeerpe.clampUnit(target.x)), top: Float = target.y < 0.5 ? 1 : 0
        content
            .visualEffect { c, proxy in
                c.distortionEffect(XeerpeShaders.library.xeerpeGenie(.boundingRect, .float(Float(p)), .float(tx), .float(top)),
                                   maxSampleOffset: proxy.size, isEnabled: p > 0)
            }
            .allowsHitTesting(p < 0.5)
            .accessibilityHidden(p >= 0.5)
        #endif
    }
}

extension XeerpeEffect {
    /// The macOS genie: as `progress` goes 0 to 1 the content pinches,
    /// lowest rows first, and pours into the point `to` on its bottom edge
    /// (or the top edge, for a point in the top half). Only `to.x` picks the
    /// spot. Change `progress` inside `withAnimation`, or use the
    /// `.xeerpeGenie(to:)` transition.
    public static func genie(progress: XeerpeValue, to target: UnitPoint = .bottom) -> XeerpeEffect {
        XeerpeEffect(name: "genie", slot: .geometry, claims: [.genie], inputs: progress.inputs) { view, ctx in
            AnyView(XeerpeGenieView(content: view, progress: progress.value(in: ctx), target: target))
        }
    }
}

/// The genie as a removal and insertion transition.
public struct XeerpeGenieTransition: Transition {
    public var target: UnitPoint
    public init(to target: UnitPoint = .bottom) { self.target = target }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        XeerpeGenieView(content: AnyView(content), progress: phase.isIdentity ? 0 : 1, target: target)
    }
}

extension Transition where Self == XeerpeGenieTransition {
    public static func xeerpeGenie(to target: UnitPoint = .bottom) -> XeerpeGenieTransition { XeerpeGenieTransition(to: target) }
}

/// Lines or glyphs that fade in, unblur and rise into place one after
/// another as `progress` goes 0 to 1. Animatable: change `progress` inside
/// `withAnimation`.
@available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
public struct XeerpeTextRise: TextRenderer, Animatable {
    public enum Unit: Sendable { case line, glyph }
    public var progress: Double
    public var unit: Unit
    /// How many items arrive at once, in item-steps.
    public var spread: Double
    public var blur: Double
    public var rise: Double

    public init(progress: Double, by unit: Unit = .line, spread: Double = 2, blur: Double = 6, rise: Double = 10) {
        self.progress = progress; self.unit = unit; self.spread = spread; self.blur = blur; self.rise = rise
    }

    public var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    public func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        switch unit {
        case .line:
            let lines = Array(layout)
            for (i, line) in lines.enumerated() {
                let c = place(i, of: lines.count, in: ctx)
                c.draw(line)
            }
        case .glyph:
            let slices = layout.flatMap { $0 }.flatMap { $0 }
            for (i, slice) in slices.enumerated() {
                let c = place(i, of: slices.count, in: ctx)
                c.draw(slice)
            }
        }
    }

    private func place(_ i: Int, of n: Int, in ctx: GraphicsContext) -> GraphicsContext {
        let a = Xeerpe.riseAmount(index: i, count: n, progress: progress, spread: spread)
        var c = ctx
        c.opacity = a
        if blur > 0, a < 1 { c.addFilter(.blur(radius: (1 - a) * blur)) }
        c.translateBy(x: 0, y: (1 - a) * rise)
        return c
    }
}

extension View {
    /// Text in this view fades in, unblurs and rises into place line by line
    /// (or glyph by glyph) as `progress` goes 0 to 1.
    @available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
    public func xeerpeTextRise(_ progress: Double, by unit: XeerpeTextRise.Unit = .line, spread: Double = 2,
                               blur: Double = 6, rise: Double = 10) -> some View {
        textRenderer(XeerpeTextRise(progress: progress, by: unit, spread: spread, blur: blur, rise: rise))
    }
}
