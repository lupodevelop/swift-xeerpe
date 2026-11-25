import SwiftUI

/// Luxury finishes. Each is lit by a light that moves with `light`, a
/// vector signal (`.tilt` by default: x right, y down, -1...1), so the
/// surface catches the light as the device turns or the pointer moves. None
/// runs frames of its own. Not drawn on watchOS.
extension XeerpeEffect {
    /// Polished edges: a band `width` points wide inside the content's
    /// outline becomes a facet that lights up where it faces the light and
    /// darkens where it faces away. With no tilt the light comes from the
    /// top left. `intensity` 0...1.
    public static func bevel(_ light: XeerpeVector = .tilt, width: Double = 6, intensity: Double = 0.6) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("bevel", claims: [.bevel], inputs: light.inputs)
        #else
        let w = width.isFinite ? max(width, 1) : 6, k = Xeerpe.clampUnit(intensity)
        return .shader("bevel", claims: [.bevel], inputs: light.inputs) { ctx in
            .layer(XeerpeShaders.library.xeerpeBevel(.boundingRect, .float(w), .float2(light.value(in: ctx)), .float(k)),
                   maxSampleOffset: CGSize(width: w, height: w))
        }
        #endif
    }

    /// Brushed metal: fine grain along rows, or around the center when
    /// `radial` (a watch crown, a speaker grille), with a highlight that
    /// slides with the light: a band across rows, or two opposite lobes
    /// around the center. `intensity` 0...1.
    public static func brushed(_ light: XeerpeVector = .tilt, radial: Bool = false, intensity: Double = 0.5) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("brushed", claims: [.brushed], inputs: light.inputs)
        #else
        let k = Xeerpe.clampUnit(intensity)
        return .shader("brushed", claims: [.brushed], inputs: light.inputs) { ctx in
            .color(XeerpeShaders.library.xeerpeBrushed(.boundingRect, .float2(light.value(in: ctx)), .float(k), .float(radial ? 1 : 0)))
        }
        #endif
    }

    /// Hot foil stamping: every opaque pixel of the content (text, a logo)
    /// becomes `tint` foil with fine crinkles, shaded by them, and a sheen
    /// that sweeps across as the light moves. `crinkle` 0...1.
    public static func foil(_ tint: Color = Color(red: 0.93, green: 0.76, blue: 0.38), light: XeerpeVector = .tilt, crinkle: Double = 0.5) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("foil", claims: [.foil], inputs: light.inputs)
        #else
        let c = Xeerpe.clampUnit(crinkle)
        return .shader("foil", claims: [.foil], inputs: light.inputs) { ctx in
            .color(XeerpeShaders.library.xeerpeFoil(.boundingRect, .color(tint), .float2(light.value(in: ctx)), .float(c)))
        }
        #endif
    }

    /// Diamond glints: four-pointed stars `size` points across, at fixed
    /// spots on the content, each flashing at its own angle of the light,
    /// so they twinkle as it turns. `density` 0...1 is the share of spots
    /// that can flash.
    public static func sparkle(_ light: XeerpeVector = .tilt, density: Double = 0.5, size: Double = 6) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("sparkle", claims: [.sparkle], inputs: light.inputs)
        #else
        let s = size.isFinite ? max(size, 2) : 6, d = Xeerpe.clampUnit(density)
        return .shader("sparkle", claims: [.sparkle], inputs: light.inputs) { ctx in
            .color(XeerpeShaders.library.xeerpeSparkle(.float2(light.value(in: ctx)), .float(d), .float(s)))
        }
        #endif
    }

    /// Guilloché: two families of fine wavy rings with `lines` waves each,
    /// interlaced around the center like an engraved dial or a banknote, in
    /// `ink`. Lines facing the light shine more. `intensity` 0...1; 0 leaves
    /// the content alone.
    public static func guilloche(_ ink: Color = .white, light: XeerpeVector = .tilt, lines: Int = 18, intensity: Double = 0.5) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("guilloche", claims: [.guilloche], inputs: light.inputs)
        #else
        let n = Float(min(max(lines, 3), 64)), k = Xeerpe.clampUnit(intensity)
        return .shader("guilloche", claims: [.guilloche], inputs: light.inputs) { ctx in
            .color(XeerpeShaders.library.xeerpeGuilloche(.boundingRect, .color(ink), .float2(light.value(in: ctx)), .float(n), .float(k)), enabled: k > 0)
        }
        #endif
    }

    /// Mother of pearl: a soft pastel iridescence from a film of uneven
    /// thickness, whose colors shift with the light. `intensity` 0...1; 0
    /// leaves the content alone.
    public static func pearl(_ light: XeerpeVector = .tilt, intensity: Double = 0.6) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("pearl", claims: [.pearl], inputs: light.inputs)
        #else
        let k = Xeerpe.clampUnit(intensity)
        return .shader("pearl", claims: [.pearl], inputs: light.inputs) { ctx in
            .color(XeerpeShaders.library.xeerpePearl(.boundingRect, .float2(light.value(in: ctx)), .float(k)), enabled: k > 0)
        }
        #endif
    }

    /// Trading-card holo: rainbow bands across the content that slide as the
    /// light moves, brightest along a sheen, with fine diagonal lines.
    /// `intensity` 0...1; 0 leaves the content alone.
    public static func holo(_ light: XeerpeVector = .tilt, intensity: Double = 0.7) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("holo", claims: [.holo], inputs: light.inputs)
        #else
        let k = Xeerpe.clampUnit(intensity)
        return .shader("holo", claims: [.holo], inputs: light.inputs) { ctx in
            .color(XeerpeShaders.library.xeerpeHolo(.boundingRect, .float2(light.value(in: ctx)), .float(k)), enabled: k > 0)
        }
        #endif
    }

    /// Polished chrome: every opaque pixel of the content (letters, a logo)
    /// mirrors a horizon, white sky into `sky`, a dark line, then `ground`,
    /// which rolls as the light moves.
    public static func chrome(_ light: XeerpeVector = .tilt, sky: Color = Color(red: 0.45, green: 0.62, blue: 0.9),
                              ground: Color = Color(red: 0.85, green: 0.72, blue: 0.55)) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("chrome", claims: [.chrome], inputs: light.inputs)
        #else
        .shader("chrome", claims: [.chrome], inputs: light.inputs) { ctx in
            .color(XeerpeShaders.library.xeerpeChrome(.boundingRect, .float2(light.value(in: ctx)), .color(sky), .color(ground)))
        }
        #endif
    }

    /// Draws `build` on an empty layer the size of the view, behind the
    /// content. Finishes in it (`brushed`, `bevel`, `sparkle`...) shape the
    /// surface only, so text and icons on top stay sharp and readable.
    ///
    ///     card.xeerpe { .backdrop { .preset(.titanium, in: shape).brushed().bevel() } }
    public static func backdrop(@XeerpeBuilder _ build: () -> XeerpeChain) -> XeerpeEffect {
        let chain = build()
        return XeerpeEffect(name: "backdrop", slot: .background, claims: [.backgroundFill], inputs: chain.inputs) { view, ctx in
            AnyView(view.background(chain.render(AnyView(Color.clear), context: ctx)))
        }
    }
}
