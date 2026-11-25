import SwiftUI

/// Four colors for `liquid`, darkest-to-lightest is a good order. Built from
/// any number of colors: extra ones are ignored, missing ones repeat.
public struct XeerpePalette: ExpressibleByArrayLiteral {
    public let colors: [Color]

    public init(_ colors: [Color]) {
        self.colors = (0..<4).map { colors.isEmpty ? Color.gray : colors[$0 % colors.count] }
    }
    public init(arrayLiteral elements: Color...) { self.init(elements) }

    public static var aurora: XeerpePalette { [Color(red: 0.03, green: 0.05, blue: 0.22), Color(red: 0.08, green: 0.78, blue: 0.68), Color(red: 0.42, green: 0.22, blue: 0.92), Color(red: 0.62, green: 1.0, blue: 0.82)] }
    public static var lava: XeerpePalette { [Color(red: 0.10, green: 0, blue: 0.02), Color(red: 0.92, green: 0.18, blue: 0.04), Color(red: 1.0, green: 0.76, blue: 0.20), Color(red: 0.52, green: 0.04, blue: 0.22)] }
    public static var ocean: XeerpePalette { [Color(red: 0, green: 0.04, blue: 0.16), Color(red: 0, green: 0.34, blue: 0.62), Color(red: 0.30, green: 0.80, blue: 0.92), Color(red: 0.72, green: 0.96, blue: 1.0)] }
    /// The four greens of the original Game Boy screen.
    public static var gameBoy: XeerpePalette { [Color(red: 0.06, green: 0.22, blue: 0.06), Color(red: 0.19, green: 0.38, blue: 0.19), Color(red: 0.55, green: 0.67, blue: 0.06), Color(red: 0.61, green: 0.74, blue: 0.06)] }
    public static var orchid: XeerpePalette { [Color(red: 0.05, green: 0, blue: 0.10), Color(red: 0.85, green: 0.12, blue: 0.60), Color(red: 0.35, green: 0.15, blue: 0.85), Color(red: 1.0, green: 0.55, blue: 0.75)] }
}

#if !os(watchOS)
enum XeerpeShaders {
    static let library = ShaderLibrary.bundle(.module)
}
#endif

/// Effects drawn by Metal shaders. Each reads only the inputs it names, so
/// none of them schedules frames until it is used.
extension XeerpeEffect {
    /// Flowing, domain-warped noise in four colors, behind the content and
    /// clipped to `shape`. The pointer pulls the flow toward itself; `pull`,
    /// a vector signal such as `.tilt`, steers it instead. Frozen under
    /// Reduce Motion; a still gradient on watchOS, which has no shaders.
    /// Cost grows with the area it fills.
    public static func liquid(
        _ palette: XeerpePalette = .aurora,
        speed: XeerpeValue = 1,
        warp: XeerpeValue = 1.6,
        in shape: some Shape = Rectangle(),
        pull: XeerpeVector? = nil
    ) -> XeerpeEffect {
        let clip = AnyShape(shape)
        let c = palette.colors
        let inputs = speed.inputs.union(warp.inputs).union([.time, .pointer]).union(pull?.inputs ?? [])
        return XeerpeEffect(name: "liquid", slot: .background, claims: [.backgroundFill], inputs: inputs) { view, ctx in
            #if os(watchOS)
            // No shaders on watchOS: a still gradient of the same palette.
            return AnyView(view.background(LinearGradient(colors: c, startPoint: .topLeading, endPoint: .bottomTrailing).clipShape(clip)))
            #else
            var p = ctx.pointer ?? .zero
            var on: Float = ctx.pointer == nil ? 0 : 1
            if let v = pull?.value(in: ctx), ctx.size.width > 0 {
                p = CGPoint(x: ctx.size.width * (0.5 + v.x * 0.45), y: ctx.size.height * (0.5 + v.y * 0.45))
                on = 1
            }
            let shader = XeerpeShaders.library.xeerpeLiquid(
                .boundingRect,
                .float(ctx.reduceMotion ? 0 : ctx.time),
                .float(speed.value(in: ctx)),
                .float(warp.value(in: ctx)),
                .color(c[0]), .color(c[1]), .color(c[2]), .color(c[3]),
                .float2(p),
                .float(on)
            )
            return AnyView(view.background(Rectangle().fill(Color.white).colorEffect(shader).clipShape(clip)))
            #endif
        }
    }

    /// A glass lens that follows the pointer and magnifies what is under it.
    /// Absent (no shader runs) while the pointer is outside the view, and on
    /// watchOS, where layer shaders do not exist.
    /// `strength` 0...1 is the magnification at the center.
    public static func lens(radius: XeerpeValue = 70, strength: XeerpeValue = 0.45) -> XeerpeEffect {
        let inputs = radius.inputs.union(strength.inputs).union(.pointer)
        #if os(watchOS)
        return .passthrough("lens", claims: [.lens], inputs: inputs)   // layer sampling shaders are not available on watchOS
        #else
        return .shader("lens", claims: [.lens], inputs: inputs) { ctx in
            let r = Xeerpe.clampNonNegative(radius.value(in: ctx))
            return .layer(XeerpeShaders.library.xeerpeLens(.boundingRect, .float2(ctx.pointer ?? .zero), .float(r),
                                                           .float(Xeerpe.clampUnit(strength.value(in: ctx)))),
                          maxSampleOffset: CGSize(width: r, height: r), enabled: ctx.pointer != nil)
        }
        #endif
    }

    /// A wave that spreads from where the view was tapped and fades out.
    /// `amplitude` is in points. Does nothing until the first tap and after
    /// it has faded.
    public static func ripple(amplitude: XeerpeValue = 9, frequency: XeerpeValue = 14, speed: XeerpeValue = 420, decay: XeerpeValue = 2.2) -> XeerpeEffect {
        let inputs = amplitude.inputs.union(frequency.inputs).union(speed.inputs).union(decay.inputs).union(.tap)
        #if os(watchOS)
        return .passthrough("ripple", slot: .geometry, claims: [.distortion], inputs: inputs)   // distortion shaders are not available on watchOS
        #else
        return .shader("ripple", slot: .geometry, claims: [.distortion], inputs: inputs) { ctx in
            let dt = ctx.tap.map { ctx.time - $0.time } ?? -1
            let a = amplitude.value(in: ctx)
            return .distortion(XeerpeShaders.library.xeerpeRipple(
                .float2(ctx.tap?.location ?? .zero), .float(max(dt, 0)), .float(a),
                .float(frequency.value(in: ctx)), .float(speed.value(in: ctx)), .float(decay.value(in: ctx))),
                maxSampleOffset: CGSize(width: abs(a), height: abs(a)),
                enabled: dt >= 0 && dt < Xeerpe.rippleLifetime && !ctx.reduceMotion)
        }
        #endif
    }
}
