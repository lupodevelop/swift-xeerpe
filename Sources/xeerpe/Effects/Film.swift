import SwiftUI

/// Photographic looks: grain, color grading, gradient maps and the light
/// artifacts of film. They change only the content's own pixels, keep its
/// alpha, and are not drawn on watchOS.
extension XeerpeEffect {
    /// Film grain over the content, in specks of `size` points, strongest in
    /// the mid-tones. `amount` 0...1; 0 leaves the content alone. When
    /// `animated`, the pattern changes 24 times a second like a running
    /// film, and holds still under Reduce Motion.
    public static func grain(_ amount: XeerpeValue = 0.3, size: Double = 1, animated: Bool = true) -> XeerpeEffect {
        let inputs = amount.inputs.union(animated && !Xeerpe.isOff(amount) ? .time : [])
        #if os(watchOS)
        return .passthrough("grain", claims: [.grain], inputs: inputs)
        #else
        let s = size.isFinite ? max(size, 0.5) : 1
        return .shader("grain", claims: [.grain], inputs: inputs) { ctx in
            let k = Xeerpe.clampUnit(amount.value(in: ctx))
            let frame = animated && !ctx.reduceMotion ? (ctx.shaderTime * 24).rounded(.down).truncatingRemainder(dividingBy: 97) : 0
            return .color(XeerpeShaders.library.xeerpeFilmGrain(.float(k), .float(s), .float(frame)), enabled: k > 0)
        }
        #endif
    }

    /// Recolors the content by brightness: black takes the first of
    /// `colors`, white the last, and the tones between run through the rest,
    /// evenly spaced. Two colors make a duotone; a dark-to-hot ramp makes a
    /// thermal camera. `amount` 0...1 mixes it with the original colors.
    public static func gradientMap(_ colors: [Color], amount: XeerpeValue = 1) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("gradientMap", claims: [.colorMap], inputs: amount.inputs)
        #else
        let stops = colors.isEmpty ? [Color.black, .white] : colors
        return .shader("gradientMap", claims: [.colorMap], inputs: amount.inputs) { ctx in
            let k = Xeerpe.clampUnit(amount.value(in: ctx))
            return .color(XeerpeShaders.library.xeerpeGradientMap(.colorArray(stops), .float(k)), enabled: k > 0)
        }
        #endif
    }

    /// A color grade. Every parameter is 0 when neutral, and with all of
    /// them neutral the content is left alone. `contrast` and `saturation`
    /// go from -1 (flat, grey) up; `warmth` -1...1 runs from blue to amber;
    /// `fade` 0...1 lifts the blacks like a matte print. `shadows` and
    /// `highlights` tint the dark and the bright tones, as much as their
    /// opacity: `shadows: .teal.opacity(0.4)`.
    public static func grade(contrast: Double = 0, saturation: Double = 0, warmth: Double = 0, fade: Double = 0,
                             shadows: Color = .clear, highlights: Color = .clear) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("grade", claims: [.grade])
        #else
        let c = Float(contrast.isFinite ? max(contrast, -1) : 0), s = Float(saturation.isFinite ? max(saturation, -1) : 0)
        let w = Float(warmth.isFinite ? min(max(warmth, -1), 1) : 0), f = Float(Xeerpe.clampUnit(fade))
        return XeerpeEffect(name: "grade", slot: .content, claims: [.grade]) { view, _ in
            AnyView(GradeView(content: view, numbers: [c, s, w, f], shadows: shadows, highlights: highlights))
        }
        #endif
    }

    /// Halation: the red glow film shows around bright lights, scattered
    /// back from its base. Parts brighter than `threshold` (0...1) bleed
    /// `tint` into what lies within `radius` points. `intensity` 0...1; 0
    /// leaves the content alone.
    public static func halation(_ tint: Color = Color(red: 1, green: 0.3, blue: 0.12), radius: Double = 10,
                                threshold: Double = 0.75, intensity: Double = 0.6) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("halation", claims: [.halation])
        #else
        let r = radius.isFinite ? max(radius, 1) : 10, t = Xeerpe.clampUnit(threshold), k = Xeerpe.clampUnit(intensity)
        return .shader("halation", claims: [.halation]) { _ in
            .layer(XeerpeShaders.library.xeerpeHalation(.boundingRect, .float(r), .float(min(t, 0.99)), .color(tint), .float(k)),
                   maxSampleOffset: CGSize(width: r, height: r), enabled: k > 0)
        }
        #endif
    }

    /// Light leaking into the camera: warm blobs of `tint` bleeding in from
    /// the left and right edges and drifting slowly along them. `intensity`
    /// 0...1; 0 leaves the content alone. Holds still under Reduce Motion.
    public static func lightLeak(_ tint: Color = Color(red: 1, green: 0.35, blue: 0.1), intensity: XeerpeValue = 0.8) -> XeerpeEffect {
        let inputs = intensity.inputs.union(Xeerpe.isOff(intensity) ? [] : .time)
        #if os(watchOS)
        return .passthrough("lightLeak", claims: [.lightLeak], inputs: inputs)
        #else
        return .shader("lightLeak", claims: [.lightLeak], inputs: inputs) { ctx in
            let k = Xeerpe.clampUnit(intensity.value(in: ctx))
            return .color(XeerpeShaders.library.xeerpeLightLeak(.boundingRect, .float(ctx.reduceMotion ? 0 : ctx.shaderTime), .color(tint), .float(k)),
                          enabled: k > 0)
        }
        #endif
    }
}

#if !os(watchOS)
/// Applies the grade shader. The tints are resolved here, in the view's own
/// environment, so adaptive colors take the variant of its color scheme.
private struct GradeView: View {
    let content: AnyView
    let numbers: [Float]
    let shadows: Color, highlights: Color
    @Environment(\.self) private var env

    var body: some View {
        let lo = Xeerpe.split(shadows, in: env), hi = Xeerpe.split(highlights, in: env)
        let neutral = numbers.allSatisfy { $0 == 0 } && lo.amount == 0 && hi.amount == 0
        let shader = XeerpeShaders.library.xeerpeGrade(.float(numbers[0]), .float(numbers[1]), .float(numbers[2]), .float(numbers[3]),
                                                        .color(lo.color), .color(hi.color), .float2(lo.amount, hi.amount))
        content.colorEffect(shader, isEnabled: !neutral)
    }
}
#endif

extension Xeerpe {
    /// Whether `value` is a constant at or below 0, so an effect it scales
    /// never draws and needs no frames. A constant reads no inputs, so it
    /// can be read without the view's context.
    static func isOff(_ value: XeerpeValue) -> Bool {
        value.inputs.isEmpty && !(value.resolve(XeerpeContext()) > 0)
    }

    /// A tint color made opaque, and its opacity as a separate strength.
    static func split(_ color: Color, in env: EnvironmentValues) -> (color: Color, amount: Double) {
        var r = color.resolve(in: env)
        let a = Double(r.opacity)
        r.opacity = 1
        return (Color(r), a)
    }
}
