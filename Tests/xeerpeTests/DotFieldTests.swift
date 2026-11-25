import SwiftUI
import Testing
@testable import xeerpe

@Suite struct DotFieldTests {
    /// Rings of dots around the origin reach every corner of the view,
    /// and no dot is laid out wholly outside it.
    @Test func layoutCoversTheViewFromAnyOrigin() {
        for _ in 0..<20 {
            let size = CGSize(width: .random(in: 120...500), height: .random(in: 80...400))
            let origin = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height))
            let dots = Xeerpe.dotLayout(in: size, origin: origin)
            #expect(!dots.isEmpty)
            let bounds = CGRect(origin: .zero, size: size)
            #expect(dots.allSatisfy { bounds.insetBy(dx: -$0.size, dy: -$0.size).contains($0.center) })
            let far = [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
                .map { hypot($0.x - origin.x, $0.y - origin.y) }.max()!
            let reach = dots.map { hypot($0.center.x - origin.x, $0.center.y - origin.y) }.max()!
            #expect(reach >= far - 30)
        }
    }

    /// Hue grows with distance from the focus, inside the given range.
    @Test func hueFollowsDistance() {
        var last = -1.0
        for d in stride(from: 0.0, through: 900, by: 15) {
            let c = Xeerpe.dotColor(distance: d, reach: 500, hue: 0.2...0.8)
            #expect((0.2...0.8).contains(c.hue))
            #expect(c.hue >= last)
            #expect((0...1).contains(c.saturation))
            last = c.hue
        }
        #expect(Xeerpe.dotColor(distance: 2000, reach: 500, hue: 0.2...0.8).saturation < 0.05)
    }

    /// The wave swells dots at its ring and leaves the others alone.
    @Test func waveSwellsOnlyAtItsRing() {
        for _ in 0..<100 {
            let r = Double.random(in: 0...600)
            #expect(abs(Xeerpe.dotSwell(distance: r, ring: r) - 1) < 1e-9)
            #expect(Xeerpe.dotSwell(distance: r + 200, ring: r) < 0.01)
            #expect(Xeerpe.dotSwell(distance: r, ring: -1) == 0)
        }
    }
}
