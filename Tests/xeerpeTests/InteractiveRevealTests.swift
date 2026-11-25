import SwiftUI
import Testing
@testable import xeerpe

@MainActor
@Suite struct FocusRevealMathTests {
    @Test func insideTheRadiusIsClearAndOutsideIsFullyHidden() {
        for _ in 0..<60 {
            let r = Double.random(in: 10...200), soft = Double.random(in: 1...40)
            #expect(Xeerpe.focusHidden(distance: max(r - soft - 1, 0), radius: r, softness: soft) == 0)
            #expect(Xeerpe.focusHidden(distance: r + soft + 1, radius: r, softness: soft) == 1)
        }
    }

    @Test func hiddenGrowsWithDistance() {
        var last = -1.0
        for d in stride(from: 0.0, through: 300, by: 5) {
            let h = Xeerpe.focusHidden(distance: d, radius: 120, softness: 30)
            #expect(h >= last && (0...1).contains(h))
            last = h
        }
    }

    @Test func presenceIsATouchDrivenScalar() {
        #expect(XeerpeValue.presence.inputs == .touch)
        #expect(XeerpeValue.presence.value(in: XeerpeContext(presence: 0.4)) == 0.4)
        #expect(XeerpeEffect.focusReveal().inputs.contains(.touch))
        #expect(XeerpeEffect.focusReveal().claims == [.reveal])
    }

    @Test func interactiveRevealPresetsAreSingleEffects() {
        for s in [XeerpeChain.hoverReveal(), .inkReveal(), .torch()] {
            #expect(s.effects.map(\.name) == ["focusReveal"])
            #expect(s.inputs.contains(.touch))
        }
    }
}

#if os(macOS)
@MainActor
@Suite struct FocusRevealPixelTests {
    let red = Color(.sRGB, red: 1, green: 0, blue: 0)

    func render(focus: CGPoint, presence: Double) -> some View {
        let card = ZStack { red; Rectangle().fill(.white).frame(width: 20) }.frame(width: 100, height: 100)
        let ctx = XeerpeContext(size: CGSize(width: 100, height: 100), focus: focus, presence: presence)
        return XeerpeChain.focusReveal(radius: XeerpeValue.presence.mapped(to: 0, 30), blur: 20, darken: 0.8, softness: 4)
            .render(AnyView(card), context: ctx)
    }

    @Test func underTheFingerTheContentIsSharpAndUntouched() {
        let p = rgbaAt(render(focus: .zero, presence: 1), x: 50, y: 50)
        #expect(p[0] > 240 && p[1] > 240)              // white bar, not blurred into red
    }

    @Test func awayFromTheFingerItIsDarkened() {
        let far = rgbaAt(render(focus: .zero, presence: 1), x: 5, y: 5)
        #expect(far[0] < 90 && far[3] > 250)
    }

    @Test func withNobodyThereEverythingIsHidden() {
        let center = rgbaAt(render(focus: .zero, presence: 0), x: 50, y: 50)
        #expect(Int(center[0]) + Int(center[1]) < 200)
    }
}

@MainActor
@Suite struct ReactiveEdgeTests {
    @Test func reactiveVignetteNeverLeavesAnUnshadedStrip() {
        let layers: [XeerpeLayer] = [.base(0xffffffff), .vignette(color: 0x000000ff, intensity: 0.9, spread: 0.6)]
        for v in [CGPoint(x: 1, y: 0), CGPoint(x: -1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: -1)] {
            let view = Color.clear.xeerpe(XeerpeChain([.surface(layers, react: .constant(v))]))
            let center = rgbaAt(view, x: 50, y: 50)[0]
            for (x, y) in [(1, 50), (98, 50), (50, 1), (50, 98)] {
                #expect(rgbaAt(view, x: x, y: y)[0] < center, "edge \(x),\(y) for \(v)")
            }
        }
    }
}
#endif

#if os(macOS)
/// Blur must actually spread color: next to a hard black/white edge a
/// blurred pixel is gray. Checking only darkness missed a blur that did nothing.
@MainActor
@Suite struct BlurIsRealTests {
    var edge: AnyView { AnyView(HStack(spacing: 0) { Color.black; Color.white }.frame(width: 100, height: 100)) }

    func gray(_ px: [UInt8]) -> Bool { (60...200).contains(Int(px[0])) }

    @Test func focusRevealBlursOutsideTheClearCircle() {
        let ctx = XeerpeContext(size: CGSize(width: 100, height: 100), focus: CGPoint(x: -1, y: -1), presence: 0)
        let v = XeerpeChain.focusReveal(blur: 20, darken: 0).render(edge, context: ctx)
        #expect(gray(rgbaAt(v, x: 47, y: 50)) || gray(rgbaAt(v, x: 53, y: 50)))
    }

    @Test func focusRevealLeavesTheCircleSharp() {
        let ctx = XeerpeContext(size: CGSize(width: 100, height: 100), focus: .zero, presence: 1)
        let v = XeerpeChain.focusReveal(radius: 40, blur: 20, darken: 0, softness: 4).render(edge, context: ctx)
        #expect(rgbaAt(v, x: 46, y: 50)[0] < 20 && rgbaAt(v, x: 54, y: 50)[0] > 235)
    }

    @Test func duoBlursTheFarSide() {
        let v = XeerpeChain.duo(progress: 1, from: .leading, maxBlur: 30)
            .render(AnyView(HStack(spacing: 0) { Color.black; Color.white; Color.black; Color.white }.background(Color.black).frame(width: 100, height: 100)), context: XeerpeContext())
        // Near the far edge the 25 px stripes blur into each other, then darken; compare to the same pixel unblurred at the
        // stripe boundary at x = 75: unblurred neighbours differ by 255, blurred they are close.
        let a = rgbaAt(v, x: 72, y: 50), b = rgbaAt(v, x: 78, y: 50)
        #expect(abs(Int(a[3]) - 255) < 5)
        #expect(abs(Int(a[0]) - Int(b[0])) < 40 || (a[0] < 20 && b[0] < 20))
    }
}
#endif
