import SwiftUI
import Testing
@testable import xeerpe

@Suite struct StreamTests {
    /// Sampled points come only from opaque pixels.
    @Test func samplesOnlyOpaquePixels() {
        for _ in 0..<20 {
            let w = Int.random(in: 4...60), h = Int.random(in: 4...60)
            var alpha = [UInt8](repeating: 0, count: w * h)
            for k in alpha.indices where Bool.random() { alpha[k] = 255 }
            let pts = Xeerpe.samplePoints(alpha: alpha, width: w, height: h, count: Int.random(in: 1...500))
            for p in pts {
                let x = Int(p.x), y = Int(p.y)
                #expect(alpha[y * w + x] > 127)
            }
            #expect(pts.isEmpty == !alpha.contains(255))
        }
    }

    /// Outward: a particle starts on its point and ends past the edge;
    /// inward the reverse. Invisible at both ends.
    @Test func particlesRunBetweenShapeAndEdge() {
        let size = CGSize(width: 200, height: 80)
        for edge in [Edge.top, .bottom, .leading, .trailing] {
            for i in 0..<50 {
                let s = CGPoint(x: .random(in: 0...200), y: .random(in: 0...80))
                let a = Xeerpe.streamParticle(i, from: s, in: size, toward: edge, reach: 300, progress: 0, inward: false)
                let b = Xeerpe.streamParticle(i, from: s, in: size, toward: edge, reach: 300, progress: 1, inward: false)
                #expect(abs(a.position.x - s.x) < 1e-6 && abs(a.position.y - s.y) < 1e-6)
                #expect(a.alpha == 0 && b.alpha == 0)
                switch edge {
                case .top: #expect(b.position.y <= -299)
                case .bottom: #expect(b.position.y >= 80 + 299)
                case .leading: #expect(b.position.x <= -299)
                case .trailing: #expect(b.position.x >= 200 + 299)
                }
                let c = Xeerpe.streamParticle(i, from: s, in: size, toward: edge, reach: 300, progress: 1, inward: true)
                #expect(abs(c.position.x - s.x) < 1e-6 && abs(c.position.y - s.y) < 1e-6)
            }
        }
    }
}

@Suite struct ParticleBatchTests {
    /// Every opacity is drawn within half a step of itself.
    @Test func stepsStayClose() {
        for _ in 0..<500 {
            let a = Double.random(in: 0...1)
            #expect(abs(XeerpeParticleBatch.alpha(step: XeerpeParticleBatch.step(a)) - a) <= 0.5 / Double(XeerpeParticleBatch.steps) + 1e-9)
        }
        #expect(XeerpeParticleBatch.step(.nan) == 0 && XeerpeParticleBatch.step(7) == XeerpeParticleBatch.steps - 1)
    }
}
