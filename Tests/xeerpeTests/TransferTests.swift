import SwiftUI
import Testing
@testable import xeerpe

@Suite struct TransferMathTests {
    func rect() -> CGRect { CGRect(x: .random(in: -300...300), y: .random(in: -300...300), width: .random(in: 10...200), height: .random(in: 10...200)) }

    /// Before its turn a particle sits in the source, after it in the target,
    /// and it is invisible at both ends of its flight.
    @Test func particlesLeaveTheSourceAndLandInTheTarget() {
        for _ in 0..<40 {
            let a = rect(), b = rect(), n = Int.random(in: 1...300)
            for i in 0..<n {
                let start = Xeerpe.transferParticle(i, of: n, progress: 0, from: a, to: b, arc: 0.3)
                let end = Xeerpe.transferParticle(i, of: n, progress: 1, from: a, to: b, arc: 0.3)
                #expect(a.insetBy(dx: -1e-6, dy: -1e-6).contains(start.position))
                #expect(b.insetBy(dx: -1e-6, dy: -1e-6).contains(end.position))
                #expect(start.alpha == 0 && end.alpha == 0)
            }
        }
    }

    @Test func everyParticleFliesAtSomePoint() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 60), b = CGRect(x: 400, y: 0, width: 100, height: 60)
        let n = 200
        for i in 0..<n {
            let peak = (1..<100).map { Xeerpe.transferParticle(i, of: n, progress: Double($0) / 100, from: a, to: b, arc: 0.3).alpha }.max()!
            #expect(peak > 0.5)
        }
    }

    @Test func sameInputsSamePositions() {
        let a = rect(), b = rect(), p = Double.random(in: 0...1)
        #expect(Xeerpe.transferParticle(7, of: 50, progress: p, from: a, to: b, arc: 0.2).position
                == Xeerpe.transferParticle(7, of: 50, progress: p, from: a, to: b, arc: 0.2).position)
    }

    @Test func sendingAndArrivingSplitTheProgress() {
        for _ in 0..<100 {
            let p = Double.random(in: -1...2)
            let (out, inn) = Xeerpe.transferPhases(p)
            #expect((0...1).contains(out) && (0...1).contains(inn))
            #expect(out >= inn)
        }
        #expect(Xeerpe.transferPhases(0) == (0, 0))
        #expect(Xeerpe.transferPhases(1) == (1, 1))
    }
}
