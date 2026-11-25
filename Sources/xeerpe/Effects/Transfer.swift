import SwiftUI

extension Xeerpe {
    /// Deterministic 0..<1 noise for particle `i`, stream `k`.
    static func unit(_ i: Int, _ k: Int) -> Double {
        splitMix(UInt64(bitPattern: Int64(i &* 7919 &+ k &* 104_729)) &+ 0x9E37_79B9_7F4A_7C15)
    }

    /// Where particle `i` of `n` is at `progress` (0...1) of a transfer from
    /// `from` to `to`: it starts at a fixed point of the source, waits its
    /// turn (particles leave over the first half), flies a curved path
    /// bulging by `arc` of the distance, and lands at a fixed point of the
    /// target. It fades in when it leaves and out when it lands.
    static func transferParticle(_ i: Int, of n: Int, progress: Double, from: CGRect, to: CGRect, arc: Double)
        -> (position: CGPoint, alpha: Double, size: Double) {
        let p0 = CGPoint(x: from.minX + unit(i, 1) * from.width, y: from.minY + unit(i, 2) * from.height)
        let p2 = CGPoint(x: to.minX + unit(i, 3) * to.width, y: to.minY + unit(i, 4) * to.height)
        let delay = unit(i, 5) * 0.5
        let raw = (min(max(progress.isFinite ? progress : 0, 0), 1) - delay) / 0.5
        let s = min(max(raw, 0), 1)
        let e = s * s * (3 - 2 * s)
        let mid = CGPoint(x: (p0.x + p2.x) / 2, y: (p0.y + p2.y) / 2)
        let d = CGPoint(x: p2.x - p0.x, y: p2.y - p0.y)
        let len = max(hypot(d.x, d.y), 0.001)
        // Bulge sideways (perpendicular to the flight), each particle a bit differently.
        let bulge = arc * len * (0.6 + 0.8 * unit(i, 6))
        let c = CGPoint(x: mid.x + d.y / len * bulge, y: mid.y - d.x / len * bulge)
        let u = 1 - e
        let pos = CGPoint(x: u * u * p0.x + 2 * u * e * c.x + e * e * p2.x, y: u * u * p0.y + 2 * u * e * c.y + e * e * p2.y)
        return (pos, s > 0 && s < 1 ? sin(.pi * s) : 0, 1 + 2.2 * unit(i, 7))
    }

    /// How far the source has dissolved and the target has formed: the
    /// source goes over the first half, the target over the second.
    static func transferPhases(_ progress: Double) -> (out: Double, in: Double) {
        let p = clampUnit(progress)
        return (clampUnit(p * 1.6), clampUnit(p * 1.6 - 0.6))
    }
}

struct XeerpeTransferAnchors {
    var source: Anchor<CGRect>?
    var target: Anchor<CGRect>?
}

struct XeerpeTransferKey: PreferenceKey {
    static var defaultValue: XeerpeTransferAnchors { XeerpeTransferAnchors() }
    static func reduce(value: inout XeerpeTransferAnchors, nextValue: () -> XeerpeTransferAnchors) {
        let n = nextValue()
        value.source = n.source ?? value.source
        value.target = n.target ?? value.target
    }
}

extension XeerpeEffect {
    /// Marks the view particles leave from in a transfer. It turns to dust
    /// over the first part of `progress`.
    public static func transferSource(progress: XeerpeValue, angle: Double = 0) -> XeerpeEffect {
        XeerpeEffect(name: "transferSource", slot: .mask, claims: [.reveal], inputs: progress.inputs) { view, ctx in
            let out = Xeerpe.transferPhases(progress.value(in: ctx)).out
            return AnyView(XeerpeRevealView(content: view, progress: 1 - out, style: .dust(angle: angle + 180), glow: .white)
                .anchorPreference(key: XeerpeTransferKey.self, value: .bounds) { XeerpeTransferAnchors(source: $0, target: nil) })
        }
    }

    /// Marks the view particles land on. It forms from dust over the last
    /// part of `progress`.
    public static func transferTarget(progress: XeerpeValue, angle: Double = 0) -> XeerpeEffect {
        XeerpeEffect(name: "transferTarget", slot: .mask, claims: [.reveal], inputs: progress.inputs) { view, ctx in
            let into = Xeerpe.transferPhases(progress.value(in: ctx)).in
            return AnyView(XeerpeRevealView(content: view, progress: into, style: .dust(angle: angle), glow: .white)
                .anchorPreference(key: XeerpeTransferKey.self, value: .bounds) { XeerpeTransferAnchors(source: nil, target: $0) })
        }
    }

    /// Put on a view that contains both a `transferSource` and a
    /// `transferTarget`: draws `count` particles in `colors` flying from one
    /// to the other as `progress` goes from 0 to 1. Everything follows
    /// `progress` alone, so it can be scrubbed, reversed, or driven on two
    /// devices by the same shared value.
    public static func transfer(progress: XeerpeValue, colors: [Color] = [.white, .yellow, .orange],
                                count: Int = 260, arc: Double = 0.25) -> XeerpeEffect {
        let palette = colors.isEmpty ? [Color.white] : colors
        return XeerpeEffect(name: "transfer", slot: .overlay, inputs: progress.inputs) { view, ctx in
            let p = progress.value(in: ctx)
            return AnyView(view.overlayPreferenceValue(XeerpeTransferKey.self) { anchors in
                GeometryReader { g in
                    if let s = anchors.source, let t = anchors.target, p > 0, p < 1 {
                        let from = g[s], to = g[t]
                        Canvas { c, _ in
                            c.addFilter(.blur(radius: 0.4))
                            c.blendMode = .plusLighter
                            var batch = XeerpeParticleBatch()
                            for i in 0..<max(count, 0) {
                                let q = Xeerpe.transferParticle(i, of: count, progress: p, from: from, to: to, arc: arc)
                                guard q.alpha > 0.01 else { continue }
                                batch.add(dot: q.position, radius: q.size, color: i, alpha: q.alpha)
                            }
                            batch.draw(in: &c, palette: palette)
                        }
                        .allowsHitTesting(false)
                    }
                }
            })
        }
    }
}
