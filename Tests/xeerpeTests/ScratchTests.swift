import SwiftUI
import Testing
@testable import xeerpe

@Suite struct ScratchGridTests {
    let size = CGSize(width: 300, height: 200)

    func randomPoint() -> CGPoint {
        CGPoint(x: .random(in: -50...350), y: .random(in: -50...250))
    }

    @Test func startsCovered() {
        #expect(XeerpeScratchGrid().coverage == 0)
    }

    @Test func coverageNeverDecreasesAndStaysInUnitRange() {
        for _ in 0..<20 {
            var g = XeerpeScratchGrid()
            var last = 0.0
            for _ in 0..<30 {
                g.mark(from: randomPoint(), to: randomPoint(), radius: .random(in: 0...40), in: size)
                #expect(g.coverage >= last)
                #expect((0...1).contains(g.coverage))
                last = g.coverage
            }
        }
    }

    @Test func sweepingEveryRowClearsAll() {
        var g = XeerpeScratchGrid()
        let r = 12.0
        var y = 0.0
        while y <= size.height { g.mark(from: CGPoint(x: 0, y: y), to: CGPoint(x: size.width, y: y), radius: r, in: size); y += r }
        #expect(g.coverage == 1)
    }

    /// A dot marks only cells whose center is within the radius, so the
    /// scratched area tracks the brush area.
    @Test func dotCoverageTracksBrushArea() {
        for _ in 0..<20 {
            var g = XeerpeScratchGrid()
            let r = Double.random(in: 15...40)
            let p = CGPoint(x: .random(in: 60...240), y: .random(in: 60...140))
            g.mark(from: p, to: p, radius: r, in: size)
            let expected = Double.pi * r * r / (size.width * size.height)
            #expect(abs(g.coverage - expected) < expected * 0.5 + 0.01)
        }
    }

    @Test func strokeOutsideMarksNothing() {
        var g = XeerpeScratchGrid()
        g.mark(from: CGPoint(x: -100, y: -100), to: CGPoint(x: -100, y: 400), radius: 20, in: size)
        #expect(g.coverage == 0)
    }

    @Test func degenerateInputsAreSafe() {
        var g = XeerpeScratchGrid()
        g.mark(from: .zero, to: CGPoint(x: 10, y: 10), radius: .nan, in: size)
        g.mark(from: .zero, to: CGPoint(x: 10, y: 10), radius: 10, in: .zero)
        #expect(g.coverage == 0)
    }
}

@Suite struct TiltMathTests {
    @Test func restIsFlat() {
        #expect(Xeerpe.tiltRotation(.zero, angle: 20).degrees == 0)
    }

    @Test func angleGrowsWithDeflectionAndIsCapped() {
        for _ in 0..<50 {
            let v = CGPoint(x: .random(in: -3...3), y: .random(in: -3...3))
            let a = Double.random(in: 1...30)
            let t = Xeerpe.tiltRotation(v, angle: a)
            let len = min(Double(hypot(v.x, v.y)), 1)
            #expect(abs(t.degrees - a * len) < 1e-9)
            // The axis is perpendicular to the vector, so the side the
            // vector points to comes forward.
            #expect(abs(Double(t.axis.x * v.x + t.axis.y * v.y)) < 1e-9)
        }
    }
}
