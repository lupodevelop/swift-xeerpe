import SwiftUI

extension Xeerpe {
    /// For a view-angle privacy blur: how blurred (0...1) once the tilt
    /// passes `start`, and the sweep direction in degrees, along the tilt.
    static func viewAngle(_ v: CGPoint, start: Double) -> (amount: Double, degrees: Double) {
        let len = min(Double(hypot(v.x, v.y)), 1)
        // Eased at both ends, so the blur creeps in past `start` and settles at full tilt.
        let t = len <= start ? 0 : clampUnit((len - start) / max(1 - start, 0.001))
        return (t * t * (3 - 2 * t), atan2(Double(v.y), Double(v.x)) * 180 / .pi)
    }

    /// Star `i` of a field: three depths, nearer ones larger, brighter and
    /// faster; a slow drift, a shift with `tilt` by depth, and a twinkle.
    /// Positions wrap around the view.
    static func star(_ i: Int, time: Double, tilt: CGPoint, in size: CGSize, speed: Double)
        -> (position: CGPoint, radius: Double, brightness: Double) {
        let depth = 0.35 + 0.65 * Double(i % 3) / 2
        let w = max(size.width, 1), h = max(size.height, 1)
        var x = unit(i, 21) * w + time * speed * 4 * depth - tilt.x * 26 * depth
        var y = unit(i, 22) * h + time * speed * 1.5 * depth - tilt.y * 26 * depth
        x = x.truncatingRemainder(dividingBy: w); if x < 0 { x += w }
        y = y.truncatingRemainder(dividingBy: h); if y < 0 { y += h }
        let twinkle = 0.55 + 0.45 * sin(time * (0.8 + 2.2 * unit(i, 23)) + unit(i, 24) * 6.28)
        return (CGPoint(x: x, y: y), 0.35 + 0.9 * depth * unit(i, 25), clampUnit(twinkle * (0.35 + 0.65 * depth)))
    }
}

extension XeerpeEffect {
    /// Privacy by viewing angle: the content stays clear facing you, and
    /// blurs and darkens from the side tilted away as `vector` (device tilt
    /// by default, the pointer on a Mac) leans past `start`, as if seen at an
    /// angle through a privacy filter.
    public static func viewAngle(_ vector: XeerpeVector = .tilt, start: Double = 0.15, maxBlur: Double = 26,
                                 darken: Double = 0.5) -> XeerpeEffect {
        XeerpeEffect(name: "viewAngle", slot: .content, claims: [.blur], inputs: vector.inputs) { view, ctx in
            let a = Xeerpe.viewAngle(vector.value(in: ctx), start: start)
            return AnyView(XeerpeBlurSweepView(content: view, progress: a.amount * 0.85, angle: a.degrees,
                                               maxBlur: maxBlur, band: 0.45, darken: darken, opaque: ctx.reduceTransparency))
        }
    }

    /// A field of stars behind the view: drifting slowly, twinkling, and
    /// shifting with `tilt` at three depths.
    public static func starfield(count: Int = 140, color: Color = .white, speed: Double = 1, tilt: XeerpeVector = .tilt) -> XeerpeEffect {
        XeerpeEffect(name: "starfield", slot: .background, inputs: tilt.inputs.union(.time)) { view, ctx in
            let t = ctx.reduceMotion ? 0 : ctx.time, v = tilt.value(in: ctx)
            return AnyView(view.background {
                Canvas { c, size in
                    for i in 0..<max(count, 0) {
                        let s = Xeerpe.star(i, time: t, tilt: v, in: size, speed: speed)
                        let r = s.radius
                        c.fill(Path(ellipseIn: CGRect(x: s.position.x - r, y: s.position.y - r, width: r * 2, height: r * 2)),
                               with: .color(color.opacity(s.brightness)))
                    }
                }
                .allowsHitTesting(false)
            })
        }
    }

    /// Relief on the edges of the view's own shape: a light rim on the side
    /// facing the light and a shade on the other, `depth` points wide. The
    /// light comes from the top-left and moves with `light`.
    public static func emboss(depth: Double = 2, light: XeerpeVector = .tilt, highlight: Double = 0.8, shadow: Double = 0.6) -> XeerpeEffect {
        XeerpeEffect(name: "emboss", slot: .overlay, claims: [.highlight], inputs: light.inputs) { view, ctx in
            let v = light.value(in: ctx)
            let dx = (-0.7 + v.x * 0.6) * depth, dy = (-0.7 + v.y * 0.6) * depth
            func rim(_ color: Color, _ ox: Double, _ oy: Double) -> some View {
                ZStack {
                    color
                    view.offset(x: ox, y: oy).blendMode(.destinationOut)
                }
                .compositingGroup()
                .mask(view)
            }
            return AnyView(view.overlay {
                ZStack {
                    rim(.white.opacity(Xeerpe.clampUnit(highlight)), -dx, -dy).blendMode(.plusLighter)
                    rim(.black.opacity(Xeerpe.clampUnit(shadow)), dx, dy)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            })
        }
    }
}
