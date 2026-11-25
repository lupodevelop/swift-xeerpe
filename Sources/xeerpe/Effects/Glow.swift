import SwiftUI

/// Color sets for `edgeGlow`.
public enum XeerpeGlow {
    /// The violet, pink, blue and orange of a system assistant glow.
    public static let intelligence: [Color] = [
        Color(red: 0.74, green: 0.51, blue: 0.95), Color(red: 0.96, green: 0.73, blue: 0.92),
        Color(red: 0.55, green: 0.62, blue: 1.0), Color(red: 1.0, green: 0.40, blue: 0.47),
        Color(red: 1.0, green: 0.73, blue: 0.44), Color(red: 0.78, green: 0.53, blue: 1.0),
    ]
    /// Cyan, white and blue.
    public static let ice: [Color] = [.cyan, .white, .blue, Color(red: 0.5, green: 0.9, blue: 1)]
    /// Orange, red, yellow and pink.
    public static let ember: [Color] = [.orange, .red, .yellow, Color(red: 1, green: 0.3, blue: 0.5)]
}

extension Xeerpe {
    /// A point on the border of `rect` at fraction `t` of its perimeter,
    /// clockwise from the top-left corner; `t` wraps around.
    static func perimeterPoint(_ t: Double, in rect: CGRect) -> CGPoint {
        let w = rect.width, h = rect.height
        let total = 2 * (w + h)
        guard total > 0, t.isFinite else { return rect.origin }
        var d = (t - t.rounded(.down)) * total
        if d < w { return CGPoint(x: rect.minX + d, y: rect.minY) }
        d -= w
        if d < h { return CGPoint(x: rect.maxX, y: rect.minY + d) }
        d -= h
        if d < w { return CGPoint(x: rect.maxX - d, y: rect.maxY) }
        d -= w
        return CGPoint(x: rect.minX, y: rect.maxY - min(d, h))
    }
}

extension XeerpeEffect {
    /// Light along the inside of the edge of `shape`, like a system
    /// assistant listening: a faint line, and wider, softer bands of the same
    /// colors bleeding inward, each drifting at its own pace so the colors
    /// keep shifting. A soft flare travels along the border. `intensity`
    /// 0...1 fades it in and out (a job's phase, a press, a level). Drawn
    /// over the view and clipped to `shape`; takes no touches. With Reduce
    /// Transparency on, only the line is drawn, without blur or flare.
    public static func edgeGlow(_ colors: [Color] = XeerpeGlow.intelligence, intensity: XeerpeValue = 1, width: Double = 5,
                                speed: Double = 1, in shape: some InsettableShape = RoundedRectangle(cornerRadius: 30, style: .continuous)) -> XeerpeEffect {
        let ring = colors.isEmpty ? XeerpeGlow.intelligence : colors
        let stops = ring + [ring[0]]
        // (line width, blur, opacity, drift) from the edge inward. The bands
        // are clipped to the shape, so the blur only spreads inward.
        let layers: [(Double, Double, Double, Double)] = [(0.35, 0.5, 0.6, 1), (0.9, 4, 0.55, -0.8), (2, 10, 0.4, 0.6), (3.6, 20, 0.28, -0.45)]
        return XeerpeEffect(name: "edgeGlow", slot: .overlay, claims: [.highlight], inputs: intensity.inputs.union(.time)) { view, ctx in
            let k = Xeerpe.clampUnit(intensity.value(in: ctx))
            let t = ctx.reduceMotion ? 0 : ctx.time * speed
            let opaque = ctx.reduceTransparency
            return AnyView(view.overlay {
                if k > 0.001 {
                    ZStack {
                        ForEach(0..<(opaque ? 1 : layers.count), id: \.self) { i in
                            let l = layers[i]
                            let turn = t * 36 * l.3 + 28 * sin(t * 0.6 + Double(i) * 1.7) + Double(i) * 50
                            shape.strokeBorder(AngularGradient(colors: stops, center: .center, angle: .degrees(turn)), lineWidth: width * l.0 * 2)
                                .blur(radius: opaque ? 0 : l.1)
                                .opacity(opaque ? k : l.2 * k)
                        }
                        if !opaque { GeometryReader { g in
                            let p = Xeerpe.perimeterPoint(t * 0.11, in: CGRect(origin: .zero, size: g.size))
                            Ellipse().fill(ring[2 % ring.count])
                                .frame(width: width * 22, height: width * 10)
                                .blur(radius: width * 4)
                                .position(p)
                                .opacity(0.45 * k)
                                .blendMode(.plusLighter)
                        } }
                    }
                    .clipShape(shape)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            })
        }
    }

    /// A short beam of light running around the border of `shape`, fading
    /// out behind its bright head through `colors`, the last at the head.
    /// `length` 0...1 is the share of the way round it covers; one lap takes
    /// 4 s at `speed` 1. Holds still under Reduce Motion.
    public static func borderBeam(_ colors: [Color] = [Color(red: 0.6, green: 0.3, blue: 1), Color(red: 1, green: 0.4, blue: 0.75), Color(red: 1, green: 0.85, blue: 0.6)],
                                  width: Double = 2, length: Double = 0.2, speed: Double = 1,
                                  in shape: some InsettableShape = RoundedRectangle(cornerRadius: 22, style: .continuous)) -> XeerpeEffect {
        let ring = colors.isEmpty ? [Color.white] : colors
        let span = min(max(length.isFinite ? length : 0.2, 0.02), 0.95)
        let stops: [Gradient.Stop] = [.init(color: .clear, location: 0), .init(color: .clear, location: 1 - span)]
            + ring.enumerated().map { .init(color: $0.element, location: 1 - span + span * 0.995 * Double($0.offset + 1) / Double(ring.count)) }
            + [.init(color: .clear, location: 1)]
        let w = width.isFinite ? max(width, 0.5) : 1.5
        return XeerpeEffect(name: "borderBeam", slot: .overlay, claims: [.highlight], inputs: .time) { view, ctx in
            let turn = ctx.reduceMotion ? 300 : (ctx.time * speed * 90).truncatingRemainder(dividingBy: 360)
            let beam = AngularGradient(stops: stops, center: .center, angle: .degrees(turn))
            return AnyView(view.overlay {
                ZStack {
                    if !ctx.reduceTransparency { shape.strokeBorder(beam, lineWidth: w * 5).blur(radius: w * 3).blendMode(.plusLighter) }
                    shape.strokeBorder(beam, lineWidth: w)
                    shape.strokeBorder(beam, lineWidth: w * 0.5).blendMode(.plusLighter)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            })
        }
    }

    /// A soft light inside `shape` that follows the pointer or finger and
    /// lights the border near it more strongly, fading in while the view is
    /// hovered or touched. `intensity` 0...1, `radius` in points. Off under
    /// Reduce Transparency.
    public static func spotlight(_ color: Color = .white, radius: Double = 160, intensity: Double = 0.25,
                                 in shape: some InsettableShape = RoundedRectangle(cornerRadius: 22, style: .continuous)) -> XeerpeEffect {
        let k = Xeerpe.clampUnit(intensity), r = radius.isFinite ? max(radius, 1) : 160
        return XeerpeEffect(name: "spotlight", slot: .overlay, claims: [.highlight], inputs: .touch) { view, ctx in
            if ctx.reduceTransparency { return view }
            let on = k * Xeerpe.clampUnit(ctx.presence)
            let at = UnitPoint(x: 0.5 + ctx.focus.x / 2, y: 0.5 + ctx.focus.y / 2)
            return AnyView(view.overlay {
                if on > 0.001 {
                    ZStack {
                        RadialGradient(colors: [color.opacity(on), color.opacity(on * 0.3), .clear], center: at, startRadius: 0, endRadius: r)
                        shape.strokeBorder(RadialGradient(colors: [color.opacity(min(on * 3.5, 1)), .clear], center: at, startRadius: 0, endRadius: r),
                                           lineWidth: 1.5)
                    }
                    .blendMode(.plusLighter)
                    .clipShape(shape)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            })
        }
    }

    /// Colors that keep flowing into each other inside `shape`, like soft
    /// blobs of light in liquid, with a highlight on top: the look of an
    /// assistant orb. With `organic` above 0 the outline wobbles too
    /// (0.05...0.12 reads as alive) and the shape is ignored. `speed` is a
    /// signal, integrated over time, so the flow can quicken without jumping.
    public static func aura(_ colors: [Color] = XeerpeGlow.intelligence, speed: XeerpeValue = 1, organic: Double = 0,
                            in shape: some Shape = Circle()) -> XeerpeEffect {
        let ring = colors.isEmpty ? XeerpeGlow.intelligence : colors
        let clip = AnyShape(shape)
        let clock = XeerpeBeatClock()
        return XeerpeEffect(name: "aura", slot: .background, claims: [.backgroundFill], inputs: speed.inputs.union(.time)) { view, ctx in
            // Radians of flow: about one radian a second at speed 1.
            let u = ctx.reduceMotion ? 0 : clock.advance(to: ctx.time, bpm: max(speed.value(in: ctx), 0) * 60)
            let outline = organic > 0 ? AnyShape(XeerpeBlob(t: u, amount: organic)) : clip
            return AnyView(view.background {
                ZStack {
                    XeerpeAuraFill(colors: ring, t: u)
                    LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .center)
                        .blendMode(.plusLighter)
                    outline.stroke(.white.opacity(0.18), lineWidth: 1).blur(radius: 0.5)
                }
                .clipShape(outline)
            })
        }
    }

    /// A blurred, brightened copy of the content glowing behind it.
    /// `radius` in points, `intensity` 0...1. Off with Reduce Transparency.
    public static func bloom(radius: XeerpeValue = 18, intensity: XeerpeValue = 0.8) -> XeerpeEffect {
        XeerpeEffect(name: "bloom", slot: .background, claims: [.shadow], inputs: radius.inputs.union(intensity.inputs)) { view, ctx in
            if ctx.reduceTransparency { return view }
            let r = Xeerpe.clampNonNegative(radius.value(in: ctx)), k = Xeerpe.clampUnit(intensity.value(in: ctx))
            return AnyView(view.background {
                view.blur(radius: r).brightness(0.15).saturation(1.3).opacity(k)
                    .allowsHitTesting(false).accessibilityHidden(true)
            })
        }
    }
}

/// A closed outline whose radius wanders with three slow waves around the
/// center, so a circle breathes like a drop. `amount` is the largest change
/// of radius as a fraction of it.
struct XeerpeBlob: Shape {
    var t: Double
    var amount: Double

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let base = min(rect.width, rect.height) / 2 / (1 + abs(amount))
        let n = 72
        let pts: [CGPoint] = (0..<n).map { i in
            let a = Double(i) / Double(n) * 2 * .pi
            let wave = 0.5 * sin(3 * a + t * 1.1) + 0.3 * sin(5 * a - t * 1.7 + 1) + 0.2 * sin(2 * a + t * 0.6 + 2)
            let r = base * (1 + amount * wave)
            return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        }
        // Quadratic curves through the midpoints: smooth, no corners.
        var p = Path()
        let mid = { (a: CGPoint, b: CGPoint) in CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        p.move(to: mid(pts[n - 1], pts[0]))
        for i in 0..<n { p.addQuadCurve(to: mid(pts[i], pts[(i + 1) % n]), control: pts[i]) }
        p.closeSubpath()
        return p
    }
}

struct XeerpeAuraFill: View {
    let colors: [Color]
    let t: Double

    var body: some View {
        #if os(watchOS)
        AngularGradient(colors: colors + [colors[0]], center: .center, angle: .radians(t * 0.4)).blur(radius: 12)
        #else
        let c = (0..<5).map { colors[$0 % colors.count] }
        Rectangle().colorEffect(XeerpeShaders.library.xeerpeAura(
            .boundingRect, .float(Float(t)), .color(c[0]), .color(c[1]), .color(c[2]), .color(c[3]), .color(c[4])))
        #endif
    }
}
