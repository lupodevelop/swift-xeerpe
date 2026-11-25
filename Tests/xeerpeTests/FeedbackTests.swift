import SwiftUI
import Testing
@testable import xeerpe

@Suite struct FeedbackTriggerTests {
    @Test func anyChangeFiresUnlessRisingOnly() {
        for _ in 0..<100 {
            let a = Int.random(in: -5...5), b = Int.random(in: -5...5)
            #expect(Xeerpe.fires(from: a, to: b, risingOnly: false) == (a != b))
            #expect(Xeerpe.fires(from: a, to: b, risingOnly: true) == (b > a))
        }
    }

    /// A value sweeping 0...1 crosses `count` detents: one per step.
    @Test func stepsCountDetents() {
        for _ in 0..<20 {
            let n = Int.random(in: 1...24)
            var last = Xeerpe.detent(0, count: n), fired = 0
            for i in 1...1000 {
                let d = Xeerpe.detent(Double(i) / 1000, count: n)
                if d != last { fired += 1; last = d }
            }
            #expect(fired == n)
        }
        #expect(Xeerpe.detent(.nan, count: 4) == 0)
    }

    @MainActor @Test func triggersReadTheirInputs() {
        #expect(XeerpeTrigger.tap.signal.inputs.contains(.tap))
        #expect(XeerpeTrigger.press.signal.inputs.contains(.press))
        #expect(XeerpeTrigger.enter.signal.inputs.contains(.hover))
        #expect(XeerpeTrigger.steps(.time(period: 1), count: 3).signal.inputs.contains(.time))
        var ctx = XeerpeContext()
        let tap = XeerpeTrigger.tap.signal
        let before = tap.value(in: ctx)
        ctx.tap = XeerpeTap(location: .zero, time: 2.5)
        #expect(tap.value(in: ctx) != before)
    }
}

@MainActor
@Suite struct PrivacyTests {
    @Test func claimsBlurAndReadsItsSignal() {
        let e = XeerpeEffect.privacy(.hover(from: 1, to: 0))
        #expect(e.claims.contains(.blur))
        #expect(e.inputs.contains(.hover))
    }
}

@Suite struct InactiveSignalTests {
    @MainActor @Test func followsScenePhase() {
        var ctx = XeerpeContext()
        #expect(XeerpeValue.inactive.inputs.contains(.scene))
        #expect(XeerpeValue.inactive.value(in: ctx) == 0)
        ctx.isInactive = true
        #expect(XeerpeValue.inactive.value(in: ctx) == 1)
    }
}

@Suite struct BoolBindingTests {
    @MainActor @Test func readsOneOrZero() {
        var flag = false
        let s = XeerpeValue.binding(Binding(get: { flag }, set: { flag = $0 }))
        #expect(s.value(in: XeerpeContext()) == 0)
        flag = true
        #expect(s.value(in: XeerpeContext()) == 1)
    }
}

/// The shader hides a pixel fully when its distance (moved by up to half a
/// band of noise) is past radius + band, and shows it when before radius - band.
@Suite struct SpoilerFrontTests {
    func radius(_ p: Double, _ o: CGPoint, _ s: CGSize, _ band: Double) -> Double {
        Xeerpe.spoilerReach(from: o, in: s, band: band) * p - band * 2
    }

    @Test func coveredAtZeroAndClearAtOne() {
        for _ in 0..<100 {
            let s = CGSize(width: .random(in: 1...400), height: .random(in: 1...200))
            let o = CGPoint(x: .random(in: 0...s.width), y: .random(in: 0...s.height))
            let band = Double.random(in: 1...30)
            let far = [CGPoint.zero, CGPoint(x: s.width, y: 0), CGPoint(x: 0, y: s.height), CGPoint(x: s.width, y: s.height)]
                .map { hypot($0.x - o.x, $0.y - o.y) }.max()!
            #expect(radius(0, o, s, band) + band <= -band / 2)
            #expect(radius(1, o, s, band) - band >= far + band / 2)
        }
    }
}
