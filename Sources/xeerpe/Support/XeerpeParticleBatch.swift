import SwiftUI

/// Collects particles into one path per palette color and alpha step, so a
/// frame of thousands of particles is a few dozen fills instead of one per
/// particle. Alpha is rounded to 16 steps, an error under 1/32.
struct XeerpeParticleBatch {
    static let steps = 16
    private var paths: [Int: Path] = [:]

    /// Particle `color` uses palette entry `color % palette.count`.
    mutating func add(square c: CGPoint, radius r: Double, color: Int, alpha: Double) {
        paths[key(color, alpha), default: Path()].addRect(CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    mutating func add(dot c: CGPoint, radius r: Double, color: Int, alpha: Double) {
        paths[key(color, alpha), default: Path()].addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    func draw(in ctx: inout GraphicsContext, palette: [Color]) {
        guard !palette.isEmpty else { return }
        for (k, path) in paths {
            ctx.fill(path, with: .color(palette[(k / Self.steps) % palette.count].opacity(Self.alpha(step: k % Self.steps))))
        }
    }

    /// The opacity a step is drawn with: the middle of its range.
    static func alpha(step: Int) -> Double { (Double(step) + 0.5) / Double(steps) }
    /// The step an opacity falls in.
    static func step(_ alpha: Double) -> Int { min(max(Int(Xeerpe.clampUnit(alpha) * Double(steps)), 0), steps - 1) }

    private func key(_ color: Int, _ alpha: Double) -> Int { max(color, 0) * Self.steps + Self.step(alpha) }
}
