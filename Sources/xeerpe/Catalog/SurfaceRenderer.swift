import SwiftUI

/// Draws a layer list in one Canvas pass, then runs grain and noise as a
/// shader over the result. With a reaction vector `react` (-1...1) the
/// surface responds: blobs and patterns move in parallax at different
/// depths, gradients turn and slide, a light follows the vector and the
/// vignette leans away. At rest (zero vector) it matches the base surface.
struct XeerpeSurfaceView: View {
    let layers: [XeerpeLayer]
    let motion: [XeerpeMotion]
    let time: Double
    var react: CGPoint = .zero
    var strength: Double = 0

    var body: some View {
        let canvas = Canvas { ctx, size in draw(&ctx, size) }
        #if os(watchOS)
        canvas
        #else
        canvas.modifier(PostPass(layers: layers))
        #endif
    }

    private func period(_ pick: (XeerpeMotion) -> Double?) -> Double? { motion.lazy.compactMap(pick).first }
    private var breathe: Double? { period { if case .breathe(let p) = $0 { p } else { nil } } }
    private var aurora: Double? { period { if case .aurora(let p) = $0 { p } else { nil } } }
    private var drift: Double? { period { if case .drift(let p) = $0 { p } else { nil } } }
    private var shimmer: Double? { period { if case .shimmer(let p) = $0 { p } else { nil } } }

    private func wave(_ period: Double, phase: Double = 0) -> Double { sin(2 * .pi * time / max(period, 0.001) + phase) }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        var blobIndex = 0
        for layer in layers.filter(\.isFill).reversed() {
            switch layer {
            case .base(let c):
                ctx.fill(Path(rect), with: .color(Xeerpe.color(rgba: c)))
            case .stops(let stops, let css, let span):
                // Drift and reaction slide the gradient only through its own
                // extra length, so a plain gradient (span 1) only turns when it
                // reacts and looks the same as the base at rest. Drift, part of
                // the preset itself, gets some length to move through.
                let len = drift != nil ? max(span, 1.3) : span
                let driftShift = drift.map { -cos(2 * .pi * time / max($0, 0.001)) } ?? 0
                let line = Xeerpe.cssLine(degrees: css + react.x * 10 * strength, size: size, span: len,
                                          shift: driftShift + react.y * strength)
                let g = Gradient(stops: Xeerpe.normalizedStops(stops).map { .init(color: Xeerpe.color(rgba: $0.rgba), location: $0.at) })
                ctx.fill(Path(rect), with: .linearGradient(g, startPoint: line.start, endPoint: line.end))
            case .blob(let x, let y, let from, let to, let fromAt, let toAt, let w, let h):
                var cx = x, cy = y, scale = 1.0
                if let p = aurora {
                    cx += 0.06 * wave(p, phase: Double(blobIndex) * 2.1)
                    cy += 0.05 * wave(p * 1.3, phase: Double(blobIndex) * 1.7 + 1)
                }
                if let p = breathe { scale += 0.07 * wave(p, phase: Double(blobIndex)) }
                let shift = Xeerpe.parallax(react, depthIndex: blobIndex, strength: strength)
                cx += shift.x; cy += shift.y
                blobIndex += 1
                let center = CGPoint(x: cx * size.width, y: cy * size.height)
                let far = Xeerpe.farthestCorner(from: center, in: size)
                let rx = (w.map { $0 * size.width } ?? far) * scale, ry = (h.map { $0 * size.height } ?? far) * scale
                radial(&ctx, center: center, rx: rx, ry: ry, size: size, stops: [
                    .init(color: Xeerpe.color(rgba: from), location: min(max(fromAt, 0), 1)),
                    .init(color: Xeerpe.color(rgba: to), location: min(max(toAt, fromAt), 1)),
                ])
            default: break
            }
        }
        if strength > 0 {
            let lit = min(Double(hypot(react.x, react.y)), 1) * 0.24 * strength
            if lit > 0.001 {
                var light = ctx
                light.blendMode = .plusLighter
                radial(&light, center: CGPoint(x: (0.5 + react.x * 0.45) * size.width, y: (0.5 + react.y * 0.45) * size.height),
                       rx: max(size.width, size.height) * 0.6, ry: max(size.width, size.height) * 0.6, size: size,
                       stops: [.init(color: .white.opacity(lit), location: 0), .init(color: .white.opacity(0), location: 1)])
            }
        }
        for (i, layer) in layers.enumerated() where !layer.isFill {
            // Patterns move in parallax; drawing them past the edges keeps the
            // border covered. The vignette moves its center instead, so it
            // still reaches every edge.
            var c = ctx
            let shift = Xeerpe.parallax(react, depthIndex: i + 2, strength: strength * 0.6)
            if case .vignette = layer {
                drawOverlay(&c, layer, size, center: CGPoint(x: (0.5 - react.x * 0.06 * strength) * size.width,
                                                            y: (0.5 - react.y * 0.06 * strength) * size.height))
            } else {
                c.translateBy(x: shift.x * size.width, y: shift.y * size.height)
                drawOverlay(&c, layer, size)
            }
        }
        if let p = shimmer {
            let phase = (time / max(p, 0.001)).truncatingRemainder(dividingBy: 1)
            let loc = Xeerpe.shimmerLocations(phase: phase * 1.4 - 0.2, width: 0.16)
            ctx.fill(Path(rect), with: .linearGradient(
                Gradient(stops: [.init(color: .clear, location: loc[0]), .init(color: .white.opacity(0.22), location: loc[1]), .init(color: .clear, location: loc[2])]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
        }
    }

    private func radial(_ ctx: inout GraphicsContext, center: CGPoint, rx: Double, ry: Double, size: CGSize, stops: [Gradient.Stop]) {
        guard rx > 0.01, ry > 0.01 else { return }
        var c = ctx
        c.translateBy(x: center.x, y: center.y)
        c.scaleBy(x: rx, y: ry)
        let area = CGRect(x: -center.x / rx, y: -center.y / ry, width: size.width / rx, height: size.height / ry)
        c.fill(Path(area), with: .radialGradient(Gradient(stops: stops), center: .zero, startRadius: 0, endRadius: 1))
    }

    private func drawOverlay(_ ctx: inout GraphicsContext, _ layer: XeerpeLayer, _ size: CGSize, center: CGPoint? = nil) {
        switch layer {
        case .vignette(let color, let intensity, let spread):
            let c = Xeerpe.channels(rgba: color)
            let tint = Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: min(max(intensity, 0), 1))
            let from = 1 - min(max(spread, 0), 1)
            let k = 2.0.squareRoot() / 2
            let c0 = center ?? CGPoint(x: size.width / 2, y: size.height / 2)
            // How many half-sizes the farthest edge lies from the moved center:
            // the ellipse scales by that factor so it still reaches it.
            let halfW = max(size.width / 2, 0.001), halfH = max(size.height / 2, 0.001)
            let reachX: Double = max(c0.x, size.width - c0.x) / halfW
            let reachY: Double = max(c0.y, size.height - c0.y) / halfH
            let reach = max(reachX, reachY)
            radial(&ctx, center: c0, rx: size.width * k * reach, ry: size.height * k * reach, size: size, stops: [
                .init(color: tint.opacity(0), location: from), .init(color: tint, location: 1)])
        case .grid(let color, let step, let line, let opacity):
            var path = Path()
            var x = -step * 4; while x <= size.width + step * 4 { path.move(to: CGPoint(x: x, y: -step * 4)); path.addLine(to: CGPoint(x: x, y: size.height + step * 4)); x += step }
            var y = -step * 4; while y <= size.height + step * 4 { path.move(to: CGPoint(x: -step * 4, y: y)); path.addLine(to: CGPoint(x: size.width + step * 4, y: y)); y += step }
            ctx.stroke(path, with: .color(Xeerpe.color(rgba: color).opacity(opacity)), lineWidth: line)
        // Dots, stars and rays: one path and one fill per layer, not one per shape.
        case .dots(let color, let step, let radius, let opacity):
            var path = Path()
            var x = step / 2 - step * 4
            while x < size.width + step * 4 {
                var y = step / 2 - step * 4
                while y < size.height + step * 4 {
                    path.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    y += step
                }
                x += step
            }
            ctx.fill(path, with: .color(Xeerpe.color(rgba: color).opacity(opacity)))
        case .stars(let color, let count, let seed, let radius, let opacity):
            var path = Path()
            for p in Xeerpe.starPoints(count: count, seed: seed) {
                path.addEllipse(in: CGRect(x: p.x * size.width - radius, y: p.y * size.height - radius, width: radius * 2, height: radius * 2))
            }
            ctx.fill(path, with: .color(Xeerpe.color(rgba: color).opacity(opacity)))
        case .rays(let color, let opacity, let count, let x, let y, let css):
            let origin = CGPoint(x: x * size.width, y: y * size.height)
            let reach = (size.width + size.height) * 2
            let start = (css - 90) * .pi / 180
            let step = 2 * .pi / Double(max(count, 1))
            var p = Path()
            for i in 0..<max(count, 0) {
                let a = start + step * Double(i)
                p.move(to: origin)
                p.addLine(to: CGPoint(x: origin.x + reach * cos(a), y: origin.y + reach * sin(a)))
                p.addLine(to: CGPoint(x: origin.x + reach * cos(a + step / 2), y: origin.y + reach * sin(a + step / 2)))
                p.closeSubpath()
            }
            ctx.fill(p, with: .color(Xeerpe.color(rgba: color).opacity(opacity)))
        default: break
        }
    }
}

#if !os(watchOS)
/// Grain and noise, as shaders, over whatever the canvas drew. Both keep the
/// alpha of the pixel, so nothing appears outside the drawn shape.
private struct PostPass: ViewModifier {
    let layers: [XeerpeLayer]
    func body(content: Content) -> some View {
        var v = AnyView(content)
        for l in layers {
            switch l {
            case .grain(let i):
                v = AnyView(v.colorEffect(XeerpeShaders.library.xeerpeGrain(.float(Float(min(max(i * 0.08, 0.01), 0.12))))))
            case .noise(let o, let s):
                v = AnyView(v.colorEffect(XeerpeShaders.library.xeerpeNoise(.float(Float(min(max(o, 0), 1))), .float(Float(max(s, 0.01))))))
            default: break
            }
        }
        return v
    }
}
#endif
