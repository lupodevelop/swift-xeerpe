import SwiftUI

extension Xeerpe {
    /// Seconds in which at most one glitch burst happens.
    static let glitchWindow = 0.6

    /// Glitch strength 0...1 at `time`. Each 0.6 s window holds at most one
    /// burst, 0.05 to 0.2 s long and starting in its first 0.1 s, so two
    /// starts are always more than 0.5 s apart and no second holds more
    /// than two (WCAG 2.3.1 allows three flashes). Six windows in ten have one.
    static func glitchBurst(at time: Double) -> Double {
        guard time.isFinite, abs(time) < 1e9 else { return 0 }
        let w = (time / glitchWindow).rounded(.down)
        let n = Int(w) * 4
        guard unitHash(n) < 0.6 else { return 0 }
        let start = 0.1 * unitHash(n + 1), length = 0.05 + 0.15 * unitHash(n + 2)
        let local = time - w * glitchWindow
        return local >= start && local < start + length ? 0.4 + 0.6 * unitHash(n + 3) : 0
    }
}

extension Xeerpe {
    /// Seconds in which at most one flicker happens.
    static let flickerWindow = 2.0

    /// How far a flickering light dims at `time`, 0...1. Four windows in ten
    /// of 2 s hold a flicker: one dip 0.05 to 0.1 s long starting in the
    /// first 0.3 s, and half the time a second, shorter dip 0.18 s after it.
    /// Every dip ends by 0.6 s into its window, so dips of different
    /// windows are more than a second apart and no second holds more than
    /// two (WCAG 2.3.1 allows three flashes).
    static func flickerDip(at time: Double) -> Double {
        guard time.isFinite, abs(time) < 1e9 else { return 0 }
        let w = (time / flickerWindow).rounded(.down)
        let n = Int(w) * 6 + 7
        guard unitHash(n) < 0.4 else { return 0 }
        let local = time - w * flickerWindow
        let start = 0.3 * unitHash(n + 1)
        if local >= start && local < start + 0.05 + 0.05 * unitHash(n + 2) { return 0.6 + 0.4 * unitHash(n + 3) }
        if unitHash(n + 4) < 0.5, local >= start + 0.18, local < start + 0.22 + 0.04 * unitHash(n + 5) { return 0.4 + 0.4 * unitHash(n + 3) }
        return 0
    }
}

extension XeerpeEffect {
    /// Blocks of `size` points, each the color at its center, like a censored
    /// photo or an 8-bit sprite. 1 or less leaves the content alone, so a
    /// signal such as `.hover(from: 14, to: 1)` sharpens it under the
    /// pointer. Hide pixelated private content from VoiceOver yourself: the
    /// effect does not know why it is used.
    public static func pixelate(_ size: XeerpeValue) -> XeerpeEffect {
        #if os(watchOS)
        // Layer shaders are not available on watchOS: blur instead.
        XeerpeEffect(name: "pixelate", slot: .content, claims: [.pixelate], inputs: size.inputs) { view, ctx in
            let s = Xeerpe.clampNonNegative(size.value(in: ctx))
            return s > 1 ? AnyView(view.blur(radius: s / 2)) : view
        }
        #else
        .shader("pixelate", claims: [.pixelate], inputs: size.inputs) { ctx in
            let s = Xeerpe.clampNonNegative(size.value(in: ctx))
            return .layer(XeerpeShaders.library.xeerpePixelate(.boundingRect, .float(s)), maxSampleOffset: CGSize(width: s, height: s), enabled: s > 1)
        }
        #endif
    }

    /// Short digital glitches: rows slide sideways by up to `shift` points
    /// and red and blue split apart, in bursts of one pattern each, never
    /// more than two a second. `amount` 0...1 scales them. The effect keeps
    /// frames running even at 0, so for an error state add it only while
    /// the error lasts: `if offline { .glitch() }`. Off under Reduce Motion
    /// and on watchOS.
    public static func glitch(_ amount: XeerpeValue = 1, shift: Double = 16) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("glitch", claims: [.glitch], inputs: amount.inputs)
        #else
        let shift = Xeerpe.clampNonNegative(shift)
        return .shader("glitch", claims: [.glitch], inputs: amount.inputs.union(.time)) { ctx in
            let s = Xeerpe.clampUnit(amount.value(in: ctx)) * Xeerpe.glitchBurst(at: ctx.time)
            // One pattern per burst; kept small for float precision.
            let seed = (ctx.time / Xeerpe.glitchWindow).rounded(.down).truncatingRemainder(dividingBy: 997)
            return .layer(XeerpeShaders.library.xeerpeGlitch(.boundingRect, .float(s), .float(seed), .float(shift)),
                          maxSampleOffset: CGSize(width: shift * 1.25, height: 0), enabled: s > 0 && !ctx.reduceMotion)
        }
        #endif
    }

    /// Digital rain behind the content, clipped to `shape`: columns of
    /// `cell`-point glyphs (at least 4) fall in `tint` over `background`.
    /// `speed` 1 is eight cells a second, clamped to 0...; `density` 0...1 is the share of columns that
    /// rain. Frozen under Reduce Motion; a plain fill on watchOS.
    public static func matrix(
        _ tint: Color = Color(red: 0.3, green: 1, blue: 0.45),
        speed: XeerpeValue = 1,
        density: XeerpeValue = 0.8,
        cell: Double = 14,
        background: Color = Color(red: 0, green: 0.05, blue: 0.02),
        in shape: some Shape = Rectangle()
    ) -> XeerpeEffect {
        let clip = AnyShape(shape)
        let inputs = speed.inputs.union(density.inputs).union(.time)
        return XeerpeEffect(name: "matrix", slot: .background, claims: [.backgroundFill], inputs: inputs) { view, ctx in
            #if os(watchOS)
            return AnyView(view.background(background.clipShape(clip)))
            #else
            let shader = XeerpeShaders.library.xeerpeMatrix(
                .boundingRect,
                .float(ctx.reduceMotion ? 0 : ctx.time.truncatingRemainder(dividingBy: 3600)),
                .float(cell.isFinite ? max(cell, 4) : 14),
                .float(Xeerpe.clampNonNegative(speed.value(in: ctx)) * 8),
                .float(Xeerpe.clampUnit(density.value(in: ctx))),
                .color(tint), .color(background)
            )
            return AnyView(view.background(Rectangle().fill(Color.white).colorEffect(shader).clipShape(clip)))
            #endif
        }
    }

    /// A failing light: now and then the content dims for a few hundredths
    /// of a second, once or twice, like an old neon tube. `amount` 0...1 is
    /// how deep the dips go. Never more than two dips a second; off under
    /// Reduce Motion.
    public static func flicker(_ amount: Double = 0.7) -> XeerpeEffect {
        let k = Xeerpe.clampUnit(amount)
        return XeerpeEffect(name: "flicker", slot: .content, claims: [.flicker], inputs: .time) { view, ctx in
            let dip = ctx.reduceMotion ? 0 : Xeerpe.flickerDip(at: ctx.time)
            return AnyView(view.opacity(1 - k * dip * 0.85))
        }
    }

    /// The content drawn as text characters in cells of `cell` points (at
    /// least 4): the brighter a cell, the more ink its character has, from a
    /// space to `#`, drawn in `ink` on `paper`, or in each cell's own color
    /// when `colored`. Each cell takes its own average alpha: cells outside
    /// the content stay clear, cells across its edge draw at partial alpha.
    /// Not drawn on watchOS.
    public static func ascii(cell: Double = 10, ink: Color = .white, paper: Color = .black, colored: Bool = false) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("ascii", claims: [.ascii])
        #else
        let c = cell.isFinite ? max(cell, 4) : 10
        return .shader("ascii", claims: [.ascii]) { _ in
            .layer(XeerpeShaders.library.xeerpeAscii(.boundingRect, .float(c), .color(ink), .color(paper), .float(colored ? 1 : 0)),
                   maxSampleOffset: CGSize(width: c, height: c))
        }
        #endif
    }
}
