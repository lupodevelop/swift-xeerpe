import SwiftUI

// The dot pattern of a cash card: rings of dots around an origin, each one a
// small gradient whose hue grows with its distance from a focal point that
// moves with tilt, so the colors sweep across the dots as the card turns.
// After Janum Trivedi's recreation of the wallet shimmer (MIT).

struct XeerpeDot {
    let center: CGPoint
    let size: Double
    /// Outward direction from the origin, radians.
    let angle: Double
}

extension Xeerpe {
    /// Rings 24 pt apart around `origin`, out to the farthest corner, with
    /// dots about 20 pt apart along each ring. Dots are largest on the
    /// middle rings and shrink toward the origin and the edge.
    static func dotLayout(in size: CGSize, origin: CGPoint) -> [XeerpeDot] {
        guard size.width > 0, size.height > 0 else { return [] }
        let far = Xeerpe.farthestCorner(from: origin, in: size)
        let rings = max(Int((far - 30) / 24) + 2, 1)
        let bounds = CGRect(origin: .zero, size: size)
        var out: [XeerpeDot] = []
        for i in 0..<rings {
            let r = 30 + Double(i) * 24
            let mid = Double(rings - 1) / 2
            let s = 13 * (1 - 0.7 * abs(Double(i) - mid) / max(mid, 1))
            let count = max(Int(2 * .pi * r / 20), 6)
            for k in 0..<count {
                let a = Double(k) / Double(count) * 2 * .pi
                let c = CGPoint(x: origin.x + r * cos(a), y: origin.y + r * sin(a))
                if bounds.insetBy(dx: -s, dy: -s).contains(c) { out.append(XeerpeDot(center: c, size: s, angle: a)) }
            }
        }
        return out
    }

    /// Hue from the low end at the focus to the high end at `reach`; past
    /// `reach` the dot also loses its color.
    static func dotColor(distance: Double, reach: Double, hue: ClosedRange<Double>) -> (hue: Double, saturation: Double) {
        let t = clampUnit(distance / max(reach, 1))
        let fade = clampUnit((distance - reach) / max(reach * 0.75, 1))
        return (hue.lowerBound + (hue.upperBound - hue.lowerBound) * t, 0.75 * (1 - fade))
    }

    /// 1 for a dot on the wave's ring, falling to 0 within about 60 pt.
    /// A negative ring is no wave.
    static func dotSwell(distance: Double, ring: Double) -> Double {
        guard ring >= 0 else { return 0 }
        let d = (distance - ring) / 28
        return exp(-d * d)
    }
}

extension XeerpeEffect {
    /// The cash-card dot field, drawn behind the view. `focus` moves the
    /// point the colors spread from (tilt by default, so turning the device
    /// sweeps them); `wave` 0...1 sends a ring of light out from `origin`
    /// across the dots, swelling and brightening them as it passes.
    public static func dotField(focus: XeerpeVector = .tilt, wave: XeerpeValue = -1, origin: UnitPoint = .bottom,
                                hue: ClosedRange<Double> = 0.2...0.8, arrows: Bool = true) -> XeerpeEffect {
        XeerpeEffect(name: "dotField", slot: .background, claims: [.backgroundFill], inputs: focus.inputs.union(wave.inputs)) { view, ctx in
            let f = focus.value(in: ctx), w = wave.value(in: ctx)
            return AnyView(view.background {
                Canvas { c, size in
                    let o = CGPoint(x: origin.x * size.width, y: origin.y * size.height)
                    let diag = hypot(size.width, size.height)
                    let focal = CGPoint(x: o.x - f.x * size.width * 0.6, y: o.y - f.y * size.height * 0.6)
                    let ring = w < 0 ? -1 : w * (diag + 80) - 40
                    for dot in Xeerpe.dotLayout(in: size, origin: o) {
                        let d = hypot(dot.center.x - focal.x, dot.center.y - focal.y)
                        let swell = Xeerpe.dotSwell(distance: hypot(dot.center.x - o.x, dot.center.y - o.y), ring: ring)
                        let a = Xeerpe.dotColor(distance: d - 30, reach: diag * 0.75, hue: hue)
                        let b = Xeerpe.dotColor(distance: d, reach: diag * 0.75, hue: hue)
                        let light = 0.68 + 0.25 * swell
                        let s = dot.size * (1 + 0.8 * swell)
                        let rect = CGRect(x: dot.center.x - s / 2, y: dot.center.y - s / 2, width: s, height: s)
                        c.fill(Path(ellipseIn: rect), with: .linearGradient(
                            Gradient(colors: [Color(hue: a.hue, saturation: a.saturation, brightness: light),
                                              Color(hue: b.hue, saturation: b.saturation, brightness: light)]),
                            startPoint: CGPoint(x: rect.midX, y: rect.midY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                        if arrows && s > 6 {
                            // A small arrow pointing away from the origin.
                            var arrow = Path()
                            let u = CGPoint(x: cos(dot.angle), y: sin(dot.angle)), n = CGPoint(x: -u.y, y: u.x), k = s * 0.22
                            arrow.move(to: CGPoint(x: dot.center.x + u.x * k * 1.3, y: dot.center.y + u.y * k * 1.3))
                            arrow.addLine(to: CGPoint(x: dot.center.x - u.x * k + n.x * k, y: dot.center.y - u.y * k + n.y * k))
                            arrow.addLine(to: CGPoint(x: dot.center.x - u.x * k - n.x * k, y: dot.center.y - u.y * k - n.y * k))
                            arrow.closeSubpath()
                            c.fill(arrow, with: .color(.black.opacity(0.35)))
                        }
                    }
                }
            })
        }
    }
}
