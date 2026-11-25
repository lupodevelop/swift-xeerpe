import SwiftUI
import Testing
@testable import xeerpe

@Suite struct BlurSweepMathTests {
    @Test func sharpAtZeroBlurredAtOne() {
        for _ in 0..<200 {
            let s = Double.random(in: 0...1), band = Double.random(in: 0.01...0.6)
            #expect(Xeerpe.sweepAmount(s, progress: 0, band: band) < 1e-9)
            #expect(Xeerpe.sweepAmount(s, progress: 1, band: band) > 1 - 1e-9)
        }
    }

    /// Behind the front is at least as blurred as ahead of it, and moving
    /// the front forward never makes a point sharper.
    @Test func monotoneInPositionAndProgress() {
        for _ in 0..<200 {
            let a = Double.random(in: 0...1), b = Double.random(in: 0...1), p = Double.random(in: 0...1), q = Double.random(in: 0...1)
            let band = Double.random(in: 0.01...0.6)
            #expect(Xeerpe.sweepAmount(min(a, b), progress: p, band: band) >= Xeerpe.sweepAmount(max(a, b), progress: p, band: band) - 1e-12)
            #expect(Xeerpe.sweepAmount(a, progress: max(p, q), band: band) >= Xeerpe.sweepAmount(a, progress: min(p, q), band: band) - 1e-12)
        }
    }
}

@MainActor
@Suite struct BlurSweepPixelTests {
    /// Fully swept, a black and white edge turns gray: the blur is real.
    @Test func sweptContentIsReallyBlurred() {
        let content = HStack(spacing: 0) { Color.black; Color.white }.frame(width: 120, height: 60)
        let r = ImageRenderer(content: content.xeerpe { .blurSweep(progress: 1, maxBlur: 20, darken: 0) })
        r.scale = 1
        guard let cg = r.cgImage, let d = cg.dataProvider?.data, let b = CFDataGetBytePtr(d) else { Issue.record("no image"); return }
        let mid = 30 * cg.bytesPerRow + 62 * 4
        #expect(b[mid] > 40 && b[mid] < 215)
    }
}
