import SwiftUI
import Testing
@testable import xeerpe

@MainActor
@Suite struct SignalTests {
    @Test func literalsAreConstants() {
        let s: XeerpeSignal<Double> = 3
        let f: XeerpeSignal<Double> = 0.25
        #expect(s.inputs.isEmpty && f.inputs.isEmpty)
        #expect(s.value(in: XeerpeContext(time: .random(in: 0...100))) == 3)
        #expect(f.value(in: XeerpeContext(isHovering: true)) == 0.25)
    }

    @Test func interactionSignalsSwitchBetweenEndpoints() {
        for _ in 0..<50 {
            let a = Double.random(in: -5...5), b = Double.random(in: -5...5)
            let hover = XeerpeSignal<Double>.hover(from: a, to: b)
            let press = XeerpeSignal<Double>.press(from: a, to: b)
            let focus = XeerpeSignal<Double>.focus(from: a, to: b)
            #expect(hover.value(in: XeerpeContext()) == a)
            #expect(hover.value(in: XeerpeContext(isHovering: true)) == b)
            #expect(press.value(in: XeerpeContext(isPressed: true)) == b)
            #expect(press.value(in: XeerpeContext(isHovering: true)) == a)
            #expect(focus.value(in: XeerpeContext(isFocused: true)) == b)
            #expect(hover.inputs == .hover && press.inputs == .press && focus.inputs == .focus)
        }
    }

    @Test func sineTimeSignalStaysInRangeAndIsPeriodic() {
        for _ in 0..<100 {
            let from = Double.random(in: -3...3), to = Double.random(in: -3...3)
            let period = Double.random(in: 0.5...10)
            let s = XeerpeSignal<Double>.time(period: period, from: from, to: to)
            let t = Double.random(in: 0...1000)
            let v = s.value(in: XeerpeContext(time: t))
            #expect(v >= min(from, to) - 1e-9 && v <= max(from, to) + 1e-9)
            let again = s.value(in: XeerpeContext(time: t + 3 * period))
            #expect(abs(v - again) < 1e-6)
            #expect(s.inputs == .time)
        }
    }

    @Test func loopWaveRisesLinearlyThenWraps() {
        let s = XeerpeSignal<Double>.time(period: 4, from: 0, to: 360, wave: .loop)
        #expect(abs(s.value(in: XeerpeContext(time: 1)) - 90) < 1e-9)
        #expect(abs(s.value(in: XeerpeContext(time: 5)) - 90) < 1e-9)
        #expect(abs(s.value(in: XeerpeContext(time: 3.999)) - 359.91) < 1e-6 + 0.1)
    }

    @Test func reduceMotionFreezesTimeSignalAtStart() {
        let s = XeerpeSignal<Double>.time(period: 2, from: 7, to: 9)
        for _ in 0..<20 {
            let ctx = XeerpeContext(time: .random(in: 0...50), reduceMotion: true)
            #expect(s.value(in: ctx) == 7)
        }
    }

    @Test func degeneratePeriodDoesNotProduceNaN() {
        for p in [0.0, -1, .nan, .infinity] {
            let v = XeerpeSignal<Double>.time(period: p, from: 1, to: 2).value(in: XeerpeContext(time: 5))
            #expect(v.isFinite)
        }
    }

    @Test func mapAndCombineUnionInputsAndApplyExplicitPolicy() {
        let h = XeerpeSignal<Double>.hover(from: 1, to: 2)
        let t = XeerpeSignal<Double>.time(period: 2, from: 0, to: 10)
        let m = h.map { $0 * 10 }
        #expect(m.value(in: XeerpeContext(isHovering: true)) == 20)
        let c = XeerpeSignal.combine(h, t) { $0 + $1 }
        #expect(c.inputs == [.hover, .time])
        #expect(c.value(in: XeerpeContext(time: 1, isHovering: true)) == 2 + 10)
    }

    @Test func bindingReadsLiveValue() {
        var stored = 0.3
        let b = Binding(get: { stored }, set: { stored = $0 })
        let s = XeerpeSignal<Double>.binding(b)
        #expect(s.value(in: XeerpeContext()) == 0.3)
        stored = 0.8
        #expect(s.value(in: XeerpeContext()) == 0.8)
        #expect(s.inputs.isEmpty)
    }

    @Test func chainInputsAreUnionOfEffects() {
        let chain = XeerpeChain.opacity(.hover(from: 0.5, to: 1)).scale(.time(period: 3, from: 1, to: 1.05)).blur(2)
        #expect(chain.inputs == [.hover, .time])
        #expect(XeerpeChain.glow(.red).blur(1).inputs.isEmpty)
    }

    @Test func effectsResolveSignalsAtRenderTime() {
        var captured: [Double] = []
        let probe = XeerpeEffect(name: "probe", slot: .content, inputs: .hover) { view, ctx in
            captured.append(XeerpeSignal<Double>.hover(from: 0, to: 1).value(in: ctx))
            return view
        }
        let chain = XeerpeChain([probe])
        _ = chain.render(AnyView(EmptyView()), context: XeerpeContext())
        _ = chain.render(AnyView(EmptyView()), context: XeerpeContext(isHovering: true))
        #expect(captured == [0, 1])
    }
}

@Suite struct GeometryMathTests {
    @Test func gradientPointsAreOppositeAndCentered() {
        for _ in 0..<100 {
            let a = Double.random(in: -720...720)
            let (s, e) = Xeerpe.gradientPoints(angleDegrees: a)
            #expect(abs((s.x + e.x) / 2 - 0.5) < 1e-9 && abs((s.y + e.y) / 2 - 0.5) < 1e-9)
            #expect(abs(hypot(e.x - s.x, e.y - s.y) - 1) < 1e-9)
        }
    }

    @Test func shimmerStopsAreMonotonicAndInUnitRange() {
        for _ in 0..<200 {
            let phase = Double.random(in: -1...2), width = Double.random(in: 0...1)
            let l = Xeerpe.shimmerLocations(phase: phase, width: width)
            #expect(l.allSatisfy { (0...1).contains($0) })
            #expect(l == l.sorted())
        }
    }
}
