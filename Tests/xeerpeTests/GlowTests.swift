import SwiftUI
import Testing
@testable import xeerpe

@Suite struct GlowMathTests {
    /// The flare walks the border of the rect: every point lies on an edge,
    /// and a full turn comes back to the start.
    @Test func flareStaysOnTheBorder() {
        for _ in 0..<200 {
            let r = CGRect(x: 0, y: 0, width: .random(in: 1...500), height: .random(in: 1...500))
            let t = Double.random(in: -5...5)
            let p = Xeerpe.perimeterPoint(t, in: r)
            let onX = abs(p.x - r.minX) < 1e-6 || abs(p.x - r.maxX) < 1e-6
            let onY = abs(p.y - r.minY) < 1e-6 || abs(p.y - r.maxY) < 1e-6
            #expect(onX || onY)
            #expect(r.insetBy(dx: -1e-6, dy: -1e-6).contains(p))
            let q = Xeerpe.perimeterPoint(t + 1, in: r)
            #expect(abs(p.x - q.x) < 1e-6 && abs(p.y - q.y) < 1e-6)
        }
    }

    /// Equal steps of t cover equal lengths of border.
    @Test func flareMovesAtConstantSpeed() {
        let r = CGRect(x: 0, y: 0, width: 300, height: 100)
        let n = 400
        var steps: [Double] = []
        for i in 0..<n {
            let a = Xeerpe.perimeterPoint(Double(i) / Double(n), in: r), b = Xeerpe.perimeterPoint(Double(i + 1) / Double(n), in: r)
            steps.append(abs(a.x - b.x) + abs(a.y - b.y))
        }
        let len = 2 * (r.width + r.height) / Double(n)
        #expect(steps.allSatisfy { abs($0 - len) < 1e-6 })
    }

    @MainActor @Test func effectsReadTheirSignals() {
        let e = XeerpeEffect.edgeGlow(intensity: .hover(from: 0, to: 1))
        #expect(e.inputs.isSuperset(of: [.time, .hover]))
        #expect(XeerpeEffect.bloom(radius: .press(from: 4, to: 20)).inputs.contains(.press))
        #expect(XeerpeGlow.intelligence.count >= 4)
    }
}

@Suite struct BlobTests {
    /// The outline stays inside the rect at any time and amount, and it moves.
    @Test func staysInsideAndMoves() {
        for _ in 0..<50 {
            let r = CGRect(x: 0, y: 0, width: .random(in: 20...300), height: .random(in: 20...300))
            let amount = Double.random(in: 0...0.3), t = Double.random(in: 0...100)
            let b = XeerpeBlob(t: t, amount: amount).path(in: r).boundingRect
            #expect(r.insetBy(dx: -0.5, dy: -0.5).contains(b))
            if amount > 0.02 {
                let other = XeerpeBlob(t: t + 1.5, amount: amount).path(in: r)
                #expect(other.boundingRect != b || other.description != XeerpeBlob(t: t, amount: amount).path(in: r).description)
            }
        }
    }
}
