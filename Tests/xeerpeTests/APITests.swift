import SwiftUI
import Testing
@testable import xeerpe

@MainActor
@Suite struct ValueConvertibleTests {
    private let ctx = XeerpeContext()

    @Test func plainValuesReadAsThemselves() {
        for _ in 0..<100 {
            let d = Double.random(in: -1000...1000), i = Int.random(in: -1000...1000), b = Bool.random()
            #expect(d.xeerpeValue.value(in: ctx) == d)
            #expect(i.xeerpeValue.value(in: ctx) == Double(i))
            #expect(CGFloat(d).xeerpeValue.value(in: ctx) == d)
            #expect(b.xeerpeValue.value(in: ctx) == (b ? 1 : 0))
            #expect(b.xeerpeValue.inputs.isEmpty)
        }
    }

    @Test func arithmeticMatchesDoubles() {
        for _ in 0..<100 {
            let a = Double.random(in: -50...50), b = Double.random(in: -50...50)
            let va = XeerpeValue.constant(a), vb = XeerpeValue.constant(b)
            #expect((va + vb).value(in: ctx) == a + b)
            #expect((va + b).value(in: ctx) == a + b)
            #expect((a + vb).value(in: ctx) == a + b)
            #expect((va - vb).value(in: ctx) == a - b)
            #expect((va - b).value(in: ctx) == a - b)
            #expect((a - vb).value(in: ctx) == a - b)
            #expect((va * vb).value(in: ctx) == a * b)
            #expect((va * b).value(in: ctx) == a * b)
            #expect((a * vb).value(in: ctx) == a * b)
            #expect(XeerpeValue.max(a, vb).value(in: ctx) == max(a, b))
            #expect(XeerpeValue.min(va, b).value(in: ctx) == min(a, b))
        }
    }

    /// A combined value listens to what each side listens to, and nothing else.
    @Test func combinedValuesKeepBothInputs() {
        let hover = XeerpeValue.hover(from: 0, to: 1), press = XeerpeValue.press(from: 0, to: 1)
        #expect((hover + press).inputs == [.hover, .press])
        #expect((hover * 2).inputs == .hover)
        #expect(XeerpeValue.max(hover, true).inputs == .hover)
        var c = XeerpeContext()
        c.isHovering = true
        #expect(XeerpeValue.max(hover * 0.4, press).value(in: c) == 0.4)
        c.isPressed = true
        #expect(XeerpeValue.max(hover * 0.4, press).value(in: c) == 1)
    }

    @Test func mappedSpansTheRangeEitherWay() {
        for _ in 0..<100 {
            let t = Double.random(in: 0...1), a = Double.random(in: -10...10), b = Double.random(in: -10...10)
            let v = XeerpeValue.constant(t).mapped(to: a, b).value(in: ctx)
            #expect(abs(v - (a + (b - a) * t)) < 1e-9)
            #expect(abs(XeerpeValue.constant(t + 1.5).mapped(to: a, b).value(in: ctx) - b) < 1e-9)
            #expect(abs(XeerpeValue.constant(-t - 0.5).mapped(to: a, b).value(in: ctx) - a) < 1e-9)
        }
    }
}

@MainActor
@Suite struct ChainFormTests {
    /// The static form starts a chain and the method form continues it;
    /// both append the same effect.
    @Test func staticAndMethodFormsAppendTheSameEffect() {
        let a = XeerpeChain.bloom().blurSweep(progress: 0.5).privacy(true)
        let b = XeerpeChain.privacy(true)
        #expect(a.effects.map(\.name) == ["bloom", "blurSweep", "privacy"])
        #expect(b.effects.map(\.name) == ["privacy"])
    }

    @Test func plainValuesAndSignalsBothReachTheEffect() {
        let amount = Double.random(in: 0.2...0.8)
        #expect(!XeerpeChain.edgeGlow(intensity: amount).inputs.contains(.hover))
        #expect(XeerpeChain.edgeGlow(intensity: .hover(from: 0, to: amount)).inputs.contains(.hover))
    }

    @Test func chainsNestInBuilders() {
        let base = XeerpeChain { .bloom().glow(.cyan) }
        let full = XeerpeChain {
            .then(base)
            .scale(1.1)
        }
        #expect(full.effects.map(\.name) == base.effects.map(\.name) + ["scale"])
    }
}

@MainActor
@Suite struct TypedPresetTests {
    /// Any data preset, reacting or not, becomes one surface; only the
    /// reacting form listens to the signal.
    @Test func presetReactsOnlyWhenAsked() {
        let data = XeerpeCatalog.all.filter { !$0.layers.isEmpty }
        for _ in 0..<20 {
            let p = data.randomElement()!
            let still = XeerpeChain.preset(p), moving = XeerpeChain.preset(p, reacting: .touch)
            #expect(still.effects.map(\.name) == ["surface"])
            #expect(!still.inputs.contains(.touch))
            #expect(moving.inputs.contains(.touch))
        }
    }

    @Test func everyCatalogIdHasOneMember() {
        let ids = XeerpeCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        for id in ids.shuffled().prefix(20) { #expect(XeerpePreset.named(id).id == id) }
    }
}
