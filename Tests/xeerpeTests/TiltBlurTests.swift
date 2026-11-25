import SwiftUI
import Testing
@testable import xeerpe

@Suite struct ViewAngleTests {
    /// Below `start` the view stays clear; past it the blur grows with the
    /// tilt and reaches full at the strongest tilt.
    @Test func amountGrowsWithTilt() {
        #expect(Xeerpe.viewAngle(.zero, start: 0.2).amount == 0)
        var last = -1.0
        for k in 0...100 {
            let v = CGPoint(x: Double(k) / 100, y: 0)
            let a = Xeerpe.viewAngle(v, start: 0.2).amount
            #expect((0...1).contains(a))
            #expect(a >= last)
            last = a
        }
        #expect(Xeerpe.viewAngle(CGPoint(x: 0.15, y: 0), start: 0.2).amount == 0)
        #expect(Xeerpe.viewAngle(CGPoint(x: 1, y: 0), start: 0.2).amount == 1)
    }

    /// The blur comes from the side tilted away: tilting right sweeps from
    /// the left edge, so the sweep angle points along the tilt.
    @Test func sweepFollowsTheTiltDirection() {
        for _ in 0..<100 {
            let a = Double.random(in: -Double.pi...Double.pi)
            let v = CGPoint(x: cos(a) * 0.8, y: sin(a) * 0.8)
            let deg = Xeerpe.viewAngle(v, start: 0.1).degrees * .pi / 180
            #expect(abs(cos(deg) - cos(a)) < 1e-9 && abs(sin(deg) - sin(a)) < 1e-9)
        }
    }
}

@Suite struct StarfieldTests {
    /// Stars wrap around: at any time and tilt every star is inside the view.
    @Test func starsStayInside() {
        for _ in 0..<20 {
            let size = CGSize(width: .random(in: 50...400), height: .random(in: 50...400))
            let t = Double.random(in: 0...1000), v = CGPoint(x: .random(in: -1...1), y: .random(in: -1...1))
            for i in 0..<200 {
                let s = Xeerpe.star(i, time: t, tilt: v, in: size, speed: 1)
                #expect(s.position.x >= 0 && s.position.x <= size.width && s.position.y >= 0 && s.position.y <= size.height)
                #expect((0...1).contains(s.brightness))
            }
        }
    }
}
