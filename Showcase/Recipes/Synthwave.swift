#if os(macOS)
import SwiftUI
import xeerpe

// A whole scene built as an effect of its own, with the public
// `XeerpeEffect` initializer: a background slot, a claim, and `.time` as its
// only input, so it runs frames only while it scrolls.
enum Synthwave {
    /// A value in 0..<1, always the same for one `n`.
    static func hash(_ n: Int) -> Double {
        let x = sin(Double(n) * 12.9898) * 43758.5453
        return x - x.rounded(.down)
    }

    /// Screen heights of the floor grid's cross lines for a floor running
    /// from `horizon` down to `bottom`. Line `k` lies at depth `k + 1 - phase`
    /// and is drawn at `horizon + (bottom - horizon) / depth`, so the lines
    /// crowd toward the horizon and, as `phase` goes from 0 to 1, each moves
    /// down to where the one before it was. Lines below `bottom` are left out.
    static func rows(phase: Double, horizon: Double, bottom: Double, count: Int = 18) -> [Double] {
        let p = phase - phase.rounded(.down)
        return (0..<max(count, 0)).compactMap { k in
            let y = horizon + (bottom - horizon) / (Double(k) + 1 - p)
            return y <= bottom ? y : nil
        }
    }

    /// Draws a synthwave horizon filling `size`: a night-to-magenta sky with
    /// faint stars, a striped sun half set behind a ridge of mountains, and a
    /// glowing floor grid in perspective, scrolled by `phase`.
    static func draw(_ c: inout GraphicsContext, size: CGSize, phase: Double, sun: [Color], grid: Color) {
        let w = size.width, h = size.height, hz = h * 0.62
        c.fill(Path(CGRect(x: 0, y: 0, width: w, height: hz)), with: .linearGradient(
            Gradient(stops: [.init(color: Color(red: 0.05, green: 0.02, blue: 0.16), location: 0),
                             .init(color: Color(red: 0.3, green: 0.05, blue: 0.42), location: 0.6),
                             .init(color: Color(red: 0.95, green: 0.32, blue: 0.55), location: 1)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: hz)))

        var stars = Path()
        for i in 0..<46 {
            let p = CGPoint(x: hash(2 * i + 7), y: hash(2 * i + 8))
            guard p.y < 0.75 else { continue }
            let r = 0.4 + 0.8 * p.x.truncatingRemainder(dividingBy: 0.1) * 10
            stars.addEllipse(in: CGRect(x: p.x * w - r / 2, y: p.y * hz * 0.6 - r / 2, width: r, height: r))
        }
        c.fill(stars, with: .color(.white.opacity(0.55)))

        let r = min(w * 0.24, hz * 0.62), center = CGPoint(x: w / 2, y: hz - r * 0.45)
        var glow = c
        glow.blendMode = .plusLighter
        glow.fill(Path(ellipseIn: CGRect(x: center.x - r * 2, y: center.y - r * 2, width: r * 4, height: r * 4)),
                  with: .radialGradient(Gradient(colors: [(sun.last ?? .pink).opacity(0.5), .clear]), center: center, startRadius: r * 0.6, endRadius: r * 2))
        c.drawLayer { l in
            l.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                   with: .linearGradient(Gradient(colors: sun), startPoint: CGPoint(x: 0, y: center.y - r), endPoint: CGPoint(x: 0, y: center.y + r)))
            // Gaps across the lower half, thicker as they go down.
            l.blendMode = .destinationOut
            var gaps = Path()
            for i in 0..<6 {
                let y = center.y + r * (0.06 + 0.16 * Double(i)), t = r * (0.03 + 0.02 * Double(i))
                gaps.addRect(CGRect(x: center.x - r, y: y, width: r * 2, height: t))
            }
            l.fill(gaps, with: .color(.black))
        }

        var ridge = Path()
        ridge.move(to: CGPoint(x: 0, y: hz))
        let peaks = 16
        for i in 0...peaks {
            let x = w * Double(i) / Double(peaks)
            // Lower toward the middle so the sun shows over the ridge.
            let side = min(abs(x - w / 2) / (w / 2) * 1.6, 1)
            ridge.addLine(to: CGPoint(x: x, y: hz - h * (0.015 + 0.11 * hash(i * 3 + 11)) * side))
        }
        ridge.addLine(to: CGPoint(x: w, y: hz))
        ridge.closeSubpath()
        c.fill(ridge, with: .color(Color(red: 0.12, green: 0.02, blue: 0.2)))
        c.stroke(ridge, with: .color(grid.opacity(0.55)), lineWidth: 1)

        c.fill(Path(CGRect(x: 0, y: hz, width: w, height: h - hz)), with: .linearGradient(
            Gradient(colors: [Color(red: 0.1, green: 0, blue: 0.18), Color(red: 0.02, green: 0, blue: 0.06)]),
            startPoint: CGPoint(x: 0, y: hz), endPoint: CGPoint(x: 0, y: h)))

        var lines = Path()
        for i in -14...14 {
            let xb = w / 2 + Double(i) * w * 0.14
            lines.move(to: CGPoint(x: w / 2 + (xb - w / 2) * 0.04, y: hz))
            lines.addLine(to: CGPoint(x: xb, y: h))
        }
        for y in rows(phase: phase, horizon: hz, bottom: h) {
            lines.move(to: CGPoint(x: 0, y: y))
            lines.addLine(to: CGPoint(x: w, y: y))
        }
        let shade = GraphicsContext.Shading.linearGradient(Gradient(colors: [grid.opacity(0.1), grid]),
                                                          startPoint: CGPoint(x: 0, y: hz), endPoint: CGPoint(x: 0, y: h))
        var halo = c
        halo.addFilter(.blur(radius: 3))
        halo.stroke(lines, with: shade, lineWidth: 3.5)
        c.stroke(lines, with: shade, lineWidth: 1.2)
        var horizon = Path()
        horizon.move(to: CGPoint(x: 0, y: hz))
        horizon.addLine(to: CGPoint(x: w, y: hz))
        halo.stroke(horizon, with: .color(grid), lineWidth: 4)
        c.stroke(horizon, with: .color(.white.opacity(0.9)), lineWidth: 1)
    }
}

extension XeerpeEffect {
    /// A synthwave horizon behind the content: a striped sun setting behind
    /// mountains over a glowing grid that scrolls toward the viewer. `sun`
    /// runs top to bottom; `speed` 1 brings a grid line closer every 1.7 s,
    /// 0 holds it still. Holds still under Reduce Motion.
    static func synthwave(speed: Double = 1,
                                 sun: [Color] = [Color(red: 1, green: 0.88, blue: 0.3), Color(red: 1, green: 0.22, blue: 0.6)],
                                 grid: Color = Color(red: 1, green: 0.25, blue: 0.85)) -> XeerpeEffect {
        let colors = sun.isEmpty ? [Color.orange] : sun
        let s = speed.isFinite ? speed : 0
        return XeerpeEffect(name: "synthwave", slot: .background, claims: [.backgroundFill], inputs: s != 0 ? .time : []) { view, ctx in
            let phase = ctx.reduceMotion ? 0 : ctx.time * s * 0.6
            return AnyView(view.background {
                Canvas { c, size in Synthwave.draw(&c, size: size, phase: phase, sun: colors, grid: grid) }
                    .clipped()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            })
        }
    }
}

// The chain form lets the effect start a builder line: `.xeerpe { .synthwave() }`.
extension XeerpeChain {
    static func synthwave(speed: Double = 1) -> XeerpeChain { XeerpeChain([.synthwave(speed: speed)]) }
}
#endif
