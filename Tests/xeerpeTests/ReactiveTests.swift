import SwiftUI
import Testing
@testable import xeerpe

@MainActor
@Suite struct VectorSignalTests {
    @Test func vectorSourcesReadTheirOwnContextFieldAndDeclareTheirInput() {
        for _ in 0..<40 {
            let v = CGPoint(x: Double.random(in: -1...1), y: Double.random(in: -1...1))
            #expect(XeerpeVector.tilt.value(in: XeerpeContext(tilt: v)) == v)
            #expect(XeerpeVector.drag.value(in: XeerpeContext(drag: v)) == v)
            #expect(XeerpeVector.touch.value(in: XeerpeContext(touch: v)) == v)
        }
        #expect(XeerpeVector.touch.value(in: XeerpeContext()) == .zero)
        #expect(XeerpeVector.tilt.inputs == .tilt && XeerpeVector.drag.inputs == .drag && XeerpeVector.touch.inputs == .touch)
    }

    @Test func projectionsAndRemapFeedAnyScalarParameter() {
        for _ in 0..<60 {
            let v = CGPoint(x: Double.random(in: -1...1), y: Double.random(in: -1...1))
            let ctx = XeerpeContext(tilt: v)
            #expect(abs(XeerpeVector.tilt.x.value(in: ctx) - Double(v.x)) < 1e-12)
            #expect(abs(XeerpeVector.tilt.y.value(in: ctx) - Double(v.y)) < 1e-12)
            let r = XeerpeVector.tilt.x.remap(-1...1, to: 10, 30).value(in: ctx)
            #expect(abs(r - (10 + (Double(v.x) + 1) / 2 * 20)) < 1e-9)
        }
        let out = XeerpeValue.constant(5).remap(-1...1, to: 0, 1).value(in: XeerpeContext())
        #expect(out == 1)
        #expect(XeerpeValue.constant(.nan).mapped(to: 2, 3).value(in: XeerpeContext()) == 2)
    }

    @Test func normalizedVectorsAreClampedToUnitRange() {
        for _ in 0..<60 {
            let size = CGSize(width: .random(in: 10...500), height: .random(in: 10...500))
            let p = CGPoint(x: .random(in: -400...900), y: .random(in: -400...900))
            let n = Xeerpe.normalizedTouch(p, in: size)
            #expect((-1...1).contains(n.x) && (-1...1).contains(n.y))
            let d = Xeerpe.normalizedDrag(CGSize(width: p.x, height: p.y), in: size)
            #expect((-1...1).contains(d.x) && (-1...1).contains(d.y))
        }
        #expect(Xeerpe.normalizedTouch(CGPoint(x: 50, y: 25), in: CGSize(width: 100, height: 50)) == .zero)
    }

    @Test func smootherApproachesTargetAndNeverOvershoots() {
        let s = XeerpeSmoother()
        var last = s.step(CGPoint(x: 0, y: 0), at: 0)
        for i in 1...60 {
            let v = s.step(CGPoint(x: 1, y: -1), at: Double(i) / 60)
            #expect(v.x >= last.x && v.x <= 1 && v.y <= last.y && v.y >= -1)
            last = v
        }
        #expect(abs(last.x - 1) < 0.01)
    }
}

@MainActor
@Suite struct ReactivePresetTests {
    @Test func everyPresetHasABaseAndAReactiveVersion() {
        for p in XeerpeCatalog.all {
            let base = p.style().inputs
            #expect(!base.contains(.tilt) && !base.contains(.drag), Comment(rawValue: p.id))
            #expect(p.reactive(to: .tilt).inputs.contains(.tilt), Comment(rawValue: p.id))
            #expect(p.reactive(to: .drag).inputs.contains(.drag), Comment(rawValue: p.id))
            #expect(p.reactive(to: .touch).conflicts.isEmpty, Comment(rawValue: p.id))
        }
    }

    @Test func reactionIsZeroAtRestAndBoundedAtFullDeflection() {
        for _ in 0..<50 {
            let i = Int.random(in: 0...6)
            let rest = Xeerpe.parallax(CGPoint.zero, depthIndex: i, strength: 1)
            #expect(rest == .zero)
            let full = Xeerpe.parallax(CGPoint(x: 1, y: -1), depthIndex: i, strength: 1)
            #expect(abs(full.x) > 0 && abs(full.x) <= 0.2 && abs(full.y) <= 0.2)
        }
    }
}

@MainActor
@Suite struct DuoMathTests {
    @Test func atRestNothingIsBlurredOrDarkened() {
        for _ in 0..<50 {
            let f = Xeerpe.duoFactors(edge: .random(in: 0...1), progress: 0, maxBlur: 72)
            #expect(f.radius == 0 && f.darken == 0)
        }
    }

    @Test func blurAndDarknessGrowAcrossTheSurfaceAndWithProgress() {
        for p in stride(from: 0.1, through: 1.0, by: 0.1) {
            var last = (radius: -1.0, darken: -1.0)
            for e in stride(from: 0.0, through: 1.0, by: 0.05) {
                let f = Xeerpe.duoFactors(edge: e, progress: p, maxBlur: 72)
                #expect(f.radius >= last.radius && f.darken >= last.darken)
                #expect(f.radius <= 72 && (0...1).contains(f.darken))
                last = f
            }
        }
        #expect(Xeerpe.duoFactors(edge: 0.1, progress: 1, maxBlur: 72).darken == 0)   // first 20% never darkens
        #expect(Xeerpe.duoFactors(edge: 1, progress: 1, maxBlur: 72).radius == 72)
        #expect(Xeerpe.duoFactors(edge: 1, progress: 1, maxBlur: 72).darken == 1)
    }

    @Test func duoChainHoldsOneEffect() {
        let s = XeerpeChain.duo(progress: 0.5, from: .trailing, fold: 20)
        #expect(s.effects.map(\.name) == ["duo"])
    }

    @Test func duoDeclaresOnlyItsProgressInputs() {
        #expect(XeerpeEffect.duo(progress: XeerpeVector.drag.x.remap(-1...1, to: 0, 1)).inputs == .drag)
        #expect(XeerpeEffect.duo(progress: 0.3).inputs.isEmpty)
        #expect(XeerpeEffect.duo(progress: 0.3).claims == [.duo])
    }
}

#if os(macOS)
@MainActor
@Suite struct DuoPixelTests {
    func render(_ p: Double, from edge: XeerpeEdge = .leading) -> some View {
        // A real card has a background; without one, the seams between the
        // rectangles are not fully opaque and the blur would show them.
        let red = Color(.sRGB, red: 1, green: 0, blue: 0)
        let stripes = HStack(spacing: 0) { ForEach(0..<10) { Rectangle().fill($0.isMultiple(of: 2) ? Color.white : red) } }.background(red)
        return XeerpeChain.duo(progress: p, from: edge)
            .render(AnyView(stripes.frame(width: 100, height: 100)), context: XeerpeContext())
    }

    @Test func farEdgeEndsDarkWhileTheHingeEdgeStaysSharp() {
        let near = rgbaAt(render(1), x: 2, y: 50), far = rgbaAt(render(1), x: 97, y: 50)
        #expect(near[0] > 230)
        #expect(Int(far[0]) + Int(far[1]) + Int(far[2]) < 40)
        #expect(far[3] > 250)
    }

    @Test func blurStaysInsideTheContentsShape() {
        let card = Color.blue.frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 30)).padding(10)
        let v = XeerpeChain.duo(progress: 1, maxBlur: 40).render(AnyView(card), context: XeerpeContext())
        #expect(rgbaAt(v, x: 95, y: 50)[3] == 0)   // margin, right of the card
        #expect(rgbaAt(v, x: 88, y: 12)[3] == 0)   // rounded corner, far side
        #expect(rgbaAt(v, x: 50, y: 50)[3] > 250)
    }

    @Test func zeroProgressLeavesTheContentUntouched() {
        for x in [5, 35, 65, 95] {
            let a = rgbaAt(render(0), x: x, y: 50)
            let stripe = (x / 10).isMultiple(of: 2)
            #expect(stripe ? a[1] > 230 : a[1] < 25)
        }
    }
}
#endif
