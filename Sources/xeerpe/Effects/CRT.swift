import SwiftUI

/// The pieces of a CRT screen. Each claims its own property, so a preset
/// built from them can drop or swap any one.
extension XeerpeEffect {
    /// Dark horizontal lines every `spacing` points; `intensity` 0...1 is how
    /// dark. `roll` > 0 sends a bar at most 8% brighter down the view, once
    /// every 10 / `roll` seconds; it keeps frames running and stops under
    /// Reduce Motion. Not drawn on watchOS.
    public static func scanlines(spacing: Double = 3, intensity: XeerpeValue = 0.35, roll: Double = 0) -> XeerpeEffect {
        let rolls = roll.isFinite && roll > 0
        let inputs = intensity.inputs.union(rolls ? .time : [])
        #if os(watchOS)
        return .passthrough("scanlines", claims: [.scanlines], inputs: inputs)
        #else
        let gap = spacing.isFinite ? max(spacing, 1) : 3
        return .shader("scanlines", claims: [.scanlines], inputs: inputs) { ctx in
            let k = Xeerpe.clampUnit(intensity.value(in: ctx))
            let r = rolls && !ctx.reduceMotion ? roll : 0
            return .color(XeerpeShaders.library.xeerpeScanlines(.boundingRect, .float(gap), .float(k), .float(ctx.shaderTime), .float(r)),
                          enabled: k > 0 || r > 0)
        }
        #endif
    }

    /// Columns of red, green and blue `size` points wide, like the phosphor
    /// stripes of a tube; `intensity` 0...1 is how strong. Not drawn on watchOS.
    public static func phosphor(size: Double = 1, intensity: XeerpeValue = 0.35) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("phosphor", claims: [.phosphor], inputs: intensity.inputs)
        #else
        let s = size.isFinite ? max(size, 0.5) : 1
        return .shader("phosphor", claims: [.phosphor], inputs: intensity.inputs) { ctx in
            let k = Xeerpe.clampUnit(intensity.value(in: ctx))
            return .color(XeerpeShaders.library.xeerpePhosphor(.float(s), .float(k)), enabled: k > 0)
        }
        #endif
    }

    /// Bulges the content like curved glass; the corners fall outside and
    /// turn clear. `amount` 0...1, 0.1 to 0.2 reads as a tube. Not drawn on watchOS.
    public static func barrel(_ amount: XeerpeValue) -> XeerpeEffect {
        XeerpeEffect(name: "barrel", slot: .geometry, claims: [.barrel], inputs: amount.inputs) { view, ctx in
            #if os(watchOS)
            return view
            #else
            let k = Xeerpe.clampUnit(amount.value(in: ctx))
            guard k > 0 else { return view }
            return AnyView(view.visualEffect { content, proxy in
                content.distortionEffect(XeerpeShaders.library.xeerpeBarrel(.boundingRect, .float(k)),
                                         maxSampleOffset: CGSize(width: proxy.size.width * k, height: proxy.size.height * k))
            })
            #endif
        }
    }

    /// Darkens toward the corners; `amount` 0...1 is how dark they get.
    /// Not drawn on watchOS.
    public static func vignette(_ amount: XeerpeValue = 0.5) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("vignette", claims: [.vignette], inputs: amount.inputs)
        #else
        .shader("vignette", claims: [.vignette], inputs: amount.inputs) { ctx in
            let k = Xeerpe.clampUnit(amount.value(in: ctx))
            return .color(XeerpeShaders.library.xeerpeVignette(.boundingRect, .float(k)), enabled: k > 0)
        }
        #endif
    }
}
