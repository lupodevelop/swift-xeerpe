import SwiftUI
import Testing
@testable import xeerpe

#if os(macOS)
@MainActor
func alphaAt(_ view: some View, size: CGFloat = 100, x: Int, y: Int) -> UInt8 {
    let r = ImageRenderer(content: view.frame(width: size, height: size)); r.scale = 1
    for _ in 0..<3 { _ = r.cgImage; RunLoop.current.run(until: Date().addingTimeInterval(0.03)) }
    let img = r.cgImage!
    var px = [UInt8](repeating: 0, count: 4)
    let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: -x, y: -(img.height - 1 - y), width: img.width, height: img.height))
    return px[3]
}
#endif

@MainActor
@Suite struct RevealPolicyTests {
    @Test func controlsAreInertWhileNearlyHidden() {
        #expect(!Xeerpe.revealIsInteractive(0))
        #expect(!Xeerpe.revealIsInteractive(0.05))
        #expect(Xeerpe.revealIsInteractive(0.5))
        #expect(Xeerpe.revealIsInteractive(1))
        #expect(!Xeerpe.revealIsInteractive(.nan))
    }

    @Test func revealDeclaresItsPropertyAndOnlyProgressInputs() {
        let e = XeerpeEffect.reveal(.fluid(), progress: .hover(from: 0, to: 1))
        #expect(e.claims == [.reveal])
        #expect(e.inputs == .hover)
        #expect(XeerpeEffect.reveal(.iris(), progress: 0.4).inputs.isEmpty)
    }

    @Test func revealPresetsTakeProgressAndStayEditable() {
        for s in [XeerpeChain.fluidReveal(progress: 0.5), .irisReveal(progress: 0.5), .wipeReveal(progress: 0.5)] {
            #expect(s.effects.map(\.name) == ["reveal"])
            #expect(s.conflicts.isEmpty)
        }
        #expect(XeerpeChain.fluidReveal(progress: 0.5).without(.reveal).effects.isEmpty)
    }

    @Test func transitionAdapterIsAPublicSwiftUITransition() {
        _ = Text("x").transition(.xeerpe(.fluid()))
        _ = Text("x").transition(XeerpeTransition(style: .wipe(), glow: .cyan))
    }
}

#if os(macOS)
@MainActor
@Suite struct RevealPixelTests {
    func view(_ style: XeerpeReveal, _ p: Double) -> some View {
        XeerpeChain.reveal(style, progress: p, glow: .clear)
            .render(AnyView(Color.red.frame(width: 100, height: 100)), context: XeerpeContext())
    }
    let probes = [(5, 5), (50, 50), (95, 95), (5, 95), (95, 5)]

    @Test func everyStyleIsFullyHiddenAtZeroAndFullyVisibleAtOne() {
        for style in [XeerpeReveal.wipe(), .wipe(angle: 135), .iris(), .iris(from: .topLeading), .fluid(), .fluid(from: .bottom)] {
            for (x, y) in probes {
                #expect(alphaAt(view(style, 0), x: x, y: y) == 0)
                #expect(alphaAt(view(style, 1), x: x, y: y) > 250)
            }
        }
    }

    @Test func wipeMovesLeftToRight() {
        let v = view(.wipe(angle: 0, softness: 0.05), 0.5)
        #expect(alphaAt(v, x: 10, y: 50) > 250)
        #expect(alphaAt(v, x: 90, y: 50) == 0)
    }

    @Test func irisGrowsFromItsOrigin() {
        let v = view(.iris(from: .center, softness: 0.05), 0.4)
        #expect(alphaAt(v, x: 50, y: 50) > 250)
        #expect(alphaAt(v, x: 3, y: 3) == 0)
    }

    @Test func coverageNeverShrinksAsProgressGrows() {
        for style in [XeerpeReveal.wipe(), .iris(), .fluid()] {
            var last = -1.0
            for p in stride(from: 0.0, through: 1.0, by: 0.2) {
                let v = view(style, p)
                var sum = 0.0
                for x in stride(from: 5, to: 100, by: 15) { for y in stride(from: 5, to: 100, by: 15) { sum += Double(alphaAt(v, x: x, y: y)) } }
                #expect(sum >= last - 1)
                last = sum
            }
        }
    }
}
#endif
