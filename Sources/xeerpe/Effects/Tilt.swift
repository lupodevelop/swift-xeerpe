import SwiftUI

extension Xeerpe {
    /// Rotation for a 3D tilt: the angle grows with the vector's length
    /// (capped at 1) and the axis is perpendicular to it, so the side the
    /// vector points to turns toward the viewer.
    static func tiltRotation(_ v: CGPoint, angle: Double) -> (degrees: Double, axis: CGPoint) {
        let len = min(Double(hypot(v.x, v.y)), 1)
        guard len > 0, len.isFinite else { return (0, CGPoint(x: 0, y: 1)) }
        let n = max(Double(hypot(v.x, v.y)), .ulpOfOne)
        return (angle * len, CGPoint(x: -v.y / n, y: v.x / n))
    }
}

extension XeerpeEffect {
    /// Turns the view in 3D following `vector`, up to `angle` degrees. On
    /// visionOS the turn is in real depth and `perspective` is ignored.
    public static func tilt3D(_ vector: XeerpeVector = .tilt, angle: Double = 14, perspective: Double = 0.5) -> XeerpeEffect {
        XeerpeEffect(name: "tilt3D", slot: .geometry, claims: [.rotation], inputs: vector.inputs) { view, ctx in
            let t = Xeerpe.tiltRotation(ctx.reduceMotion ? .zero : vector.value(in: ctx), angle: angle)
            #if os(visionOS)
            // visionOS turns the view in real depth, so `perspective` has no effect there.
            return AnyView(view.rotation3DEffect(.degrees(t.degrees), axis: RotationAxis3D(x: t.axis.x, y: t.axis.y, z: 0)))
            #else
            return AnyView(view.rotation3DEffect(.degrees(t.degrees), axis: (x: t.axis.x, y: t.axis.y, z: 0),
                                                 perspective: Xeerpe.clampUnit(perspective)))
            #endif
        }
    }

    /// A soft light on the view that slides with `vector`, as on a glossy
    /// card turned under a lamp. Clipped to `shape`; takes no touches. Off
    /// with Reduce Transparency.
    public static func glare(_ vector: XeerpeVector = .tilt, intensity: Double = 0.5, in shape: some Shape = Rectangle()) -> XeerpeEffect {
        let clip = AnyShape(shape)
        return XeerpeEffect(name: "glare", slot: .overlay, claims: [.highlight], inputs: vector.inputs) { view, ctx in
            if ctx.reduceTransparency { return view }
            let v = vector.value(in: ctx)
            let k = Xeerpe.clampUnit(intensity) * (0.35 + 0.65 * min(Double(hypot(v.x, v.y)), 1))
            return AnyView(view.overlay {
                GeometryReader { geo in
                    let reach = max(geo.size.width, geo.size.height) * 0.75
                    RadialGradient(colors: [.white.opacity(k), .white.opacity(k * 0.25), .clear],
                                   center: UnitPoint(x: 0.5 + v.x * 0.6, y: 0.5 + v.y * 0.6), startRadius: 0, endRadius: reach)
                        .blendMode(.plusLighter)
                }
                .clipShape(clip)
                .allowsHitTesting(false)
            })
        }
    }
}

extension XeerpeChain {
    /// A card that turns with `vector`, lit by a glare that follows it,
    /// over the reactive form of any catalog preset (`holographic` by default).
    public static func card(_ preset: XeerpePreset = .holographic, _ vector: XeerpeVector = .tilt, angle: Double = 12,
                            in shape: some Shape = RoundedRectangle(cornerRadius: 22, style: .continuous)) -> XeerpeChain {
        preset.reactive(to: vector, in: shape).glare(vector, intensity: 0.3, in: shape).tilt3D(vector, angle: angle)
    }
}
