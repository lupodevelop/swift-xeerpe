import SwiftUI

extension Xeerpe {
    /// Up to `count` points (pixel coordinates) spread evenly over the
    /// pixels of an alpha mask that are more than half opaque.
    static func samplePoints(alpha: [UInt8], width: Int, height: Int, count: Int) -> [CGPoint] {
        var solid: [Int] = []
        for k in alpha.indices where alpha[k] > 127 { solid.append(k) }
        guard !solid.isEmpty, count > 0 else { return [] }
        let step = max(Double(solid.count) / Double(count), 1)
        var out: [CGPoint] = []
        var f = 0.0, i = 0
        while Int(f) < solid.count && out.count < count {
            let k = solid[Int(f)]
            out.append(CGPoint(x: Double(k % width) + unit(i, 11) * 0.98, y: Double(k / width) + unit(i, 12) * 0.98))
            f += step; i += 1
        }
        return out
    }

    /// Particle `i`, born at `from` inside a view of `size`, streaming
    /// straight toward `edge` and `reach` points past it as `progress` goes
    /// 0 to 1 (or from there back to `from` when `inward`). Particles leave
    /// at different moments, so together they form continuous streams; the
    /// streams fan out a little and every particle wavers slightly.
    static func streamParticle(_ i: Int, from s: CGPoint, in size: CGSize, toward edge: Edge, reach: Double,
                               progress: Double, inward: Bool) -> (position: CGPoint, alpha: Double, size: Double) {
        let dir: CGPoint, along: Double, toEdge: Double
        switch edge {
        case .top: dir = CGPoint(x: 0, y: -1); along = s.x - size.width / 2; toEdge = s.y
        case .bottom: dir = CGPoint(x: 0, y: 1); along = s.x - size.width / 2; toEdge = size.height - s.y
        case .leading: dir = CGPoint(x: -1, y: 0); along = s.y - size.height / 2; toEdge = s.x
        case .trailing: dir = CGPoint(x: 1, y: 0); along = s.y - size.height / 2; toEdge = size.width - s.x
        }
        let normal = CGPoint(x: -dir.y, y: dir.x)
        let dist = toEdge + reach
        let fan = along * 0.18 + (unit(i, 13) - 0.5) * 8
        let delay = unit(i, 14) * 0.55
        let raw = (min(max(progress.isFinite ? progress : 0, 0), 1) - delay) / 0.45
        var t = min(max(raw, 0), 1)
        if inward { t = 1 - min(max(((progress.isFinite ? progress : 0) - (0.55 - delay)) / 0.45, 0), 1) }
        let e = t * t * (3 - 2 * t)
        let waver = sin(t * .pi) * (unit(i, 15) - 0.5) * 5
        let side = fan * e + waver
        let pos = CGPoint(x: s.x + dir.x * dist * e + normal.x * side, y: s.y + dir.y * dist * e + normal.y * side)
        let alpha = t > 0 && t < 1 ? min(t * 8, 1) * (1 - pow(t, 3)) * (0.25 + 0.6 * unit(i, 16)) : 0
        return (pos, alpha, 0.3 + 0.45 * unit(i, 17))
    }
}

/// The particles of a stream. The shape is sampled after layout, in a task:
/// an image renderer used while a body is being computed draws nothing.
struct XeerpeStreamCanvas: View {
    let content: AnyView
    let progress: Double
    let edge: Edge
    let reach: Double
    let inward: Bool
    let count: Int
    let palette: [Color]
    @State private var size: CGSize = .zero
    @State private var points: [CGPoint] = []

    var body: some View {
        let ext = CGRect(x: edge == .leading ? -reach : 0, y: edge == .top ? -reach : 0,
                         width: size.width + (edge == .leading || edge == .trailing ? reach : 0),
                         height: size.height + (edge == .top || edge == .bottom ? reach : 0))
        Color.clear
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .task(id: size) { points = sample(size) }
            .overlay(alignment: .topLeading) {
                if progress > 0 && progress < 1 && !points.isEmpty {
                    Canvas { c, _ in
                        c.translateBy(x: -ext.minX, y: -ext.minY)
                        c.blendMode = .plusLighter
                        var batch = XeerpeParticleBatch()
                        for (i, s) in points.enumerated() {
                            let q = Xeerpe.streamParticle(i, from: s, in: size, toward: edge, reach: reach, progress: progress, inward: inward)
                            guard q.alpha > 0.02 else { continue }
                            batch.add(square: q.position, radius: q.size, color: i, alpha: q.alpha)
                        }
                        batch.draw(in: &c, palette: palette)
                    }
                    .frame(width: ext.width, height: ext.height)
                    .offset(x: ext.minX, y: ext.minY)
                }
            }
            .allowsHitTesting(false)
    }

    private func sample(_ size: CGSize) -> [CGPoint] {
        guard size.width > 0, size.height > 0 else { return [] }
        let r = ImageRenderer(content: content.frame(width: size.width, height: size.height))
        r.scale = 1
        guard let cg = r.cgImage, cg.bitsPerPixel == 32, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return [] }
        let w = cg.width, h = cg.height, row = cg.bytesPerRow
        // Alpha is the first or the last byte of a pixel, depending on the layout.
        let first = cg.alphaInfo == .premultipliedFirst || cg.alphaInfo == .first
        var alpha = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w { alpha[y * w + x] = bytes[y * row + x * 4 + (first ? 0 : 3)] } }
        return Xeerpe.samplePoints(alpha: alpha, width: w, height: h, count: count)
            .map { CGPoint(x: $0.x * size.width / Double(w), y: $0.y * size.height / Double(h)) }
    }
}

extension View {
    /// Turns the view into a stream of fine particles flowing toward `edge`
    /// and `reach` points past it as `progress` goes 0 to 1, while the view
    /// itself dissolves; with `inward` the particles flow in from the edge
    /// and the view forms from them. Particles are born on the view's own
    /// opaque pixels, so text streams from its letters. A view modifier, not
    /// a chain effect: it needs the view itself to sample its pixels. The
    /// shape is sampled when the size changes; if the content changes at the
    /// same size, give the view a new `.id`.
    public func xeerpeStream(progress: some XeerpeValueConvertible, toward edge: Edge = .top, reach: Double = 300, inward: Bool = false,
                             count: Int = 1800, colors: [Color] = [.white, Color(white: 0.85), Color(red: 0.85, green: 0.9, blue: 1)]) -> some View {
        let palette = colors.isEmpty ? [Color.white] : colors
        let angle: Double = switch edge { case .top: 270; case .bottom: 90; case .leading: 180; case .trailing: 0 }
        let me = AnyView(self), progress = progress.xeerpeValue
        return xeerpe {
            XeerpeChain.then(XeerpeEffect(name: "stream", slot: .mask, claims: [.reveal], inputs: progress.inputs) { view, ctx in
                let p = Xeerpe.clampUnit(progress.value(in: ctx))
                // The view goes over the first part when leaving, comes over the last when arriving.
                let shown = inward ? Xeerpe.clampUnit((p - 0.45) / 0.55) : 1 - Xeerpe.clampUnit(p / 0.6)
                return AnyView(XeerpeRevealView(content: view, progress: shown, style: .dust(angle: inward ? angle + 180 : angle), glow: .white)
                    .overlay { XeerpeStreamCanvas(content: me, progress: p, edge: edge, reach: reach, inward: inward, count: count, palette: palette) })
            })
        }
    }
}
