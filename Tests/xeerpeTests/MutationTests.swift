import SwiftUI
import Testing
@testable import xeerpe

@MainActor
@Suite struct MixTests {
    func rgba(_ c: Color) -> [Float] {
        let r = c.resolve(in: EnvironmentValues())
        return [r.linearRed, r.linearGreen, r.linearBlue, r.opacity]
    }

    @Test func doubleMixInterpolatesAndClamps() {
        for _ in 0..<100 {
            let a = Double.random(in: -5...5), b = Double.random(in: -5...5), t = Double.random(in: 0...1)
            #expect(abs(Double.mix(a, b, t) - (a + (b - a) * t)) < 1e-9)
            #expect(Double.mix(a, b, -3) == a && Double.mix(a, b, 9) == b)
            #expect(Double.mix(a, b, .nan) == a)
        }
    }

    @Test func colorMixHitsEndpointsAndMidpoint() {
        let a = Color(.sRGB, red: 0.1, green: 0.4, blue: 0.9, opacity: 1)
        let b = Color(.sRGB, red: 0.8, green: 0.2, blue: 0.0, opacity: 0.5)
        let ra = rgba(a), rb = rgba(b)
        for (x, y) in zip(rgba(Color.mix(a, b, 0)), ra) { #expect(abs(x - y) < 1e-4) }
        for (x, y) in zip(rgba(Color.mix(a, b, 1)), rb) { #expect(abs(x - y) < 1e-4) }
        // A perceptual blend need not stay between the endpoints channel by
        // channel, so the midpoint is checked by distance.
        func dist(_ x: [Float], _ y: [Float]) -> Float { zip(x, y).map { ($0 - $1) * ($0 - $1) }.reduce(0, +).squareRoot() }
        let mid = rgba(Color.mix(a, b, 0.5)), span = dist(ra, rb)
        #expect(dist(mid, ra) > 0.2 * span && dist(mid, ra) < 0.8 * span)
        #expect(dist(mid, rb) > 0.2 * span && dist(mid, rb) < 0.8 * span)
    }

    /// A blend of adaptive colors is resolved where it is drawn, so it takes
    /// that view's color scheme.
    @Test func colorMixKeepsAdaptiveColorsAdaptive() {
        var dark = EnvironmentValues()
        dark.colorScheme = .dark
        #expect(Color.mix(.primary, .primary, 0.5).resolve(in: dark).red > 0.9)
    }

    @Test func arrayMixIsElementwise() {
        #expect([Double].mix([0, 10], [10, 20], 0.5) == [5, 15])
    }

    @Test func keyframesHitEveryStopAndStayBetweenNeighbours() {
        for _ in 0..<50 {
            let stops = (0..<Int.random(in: 2...6)).map { _ in Double.random(in: -10...10) }
            for (i, s) in stops.enumerated() {
                let t = Double(i) / Double(stops.count - 1)
                let sig = XeerpeSignal<Double>.keyframes(stops, phase: .constant(t))
                #expect(abs(sig.value(in: XeerpeContext()) - s) < 1e-9)
            }
            let t = Double.random(in: 0...1)
            let v = XeerpeSignal<Double>.keyframes(stops, phase: .constant(t)).value(in: XeerpeContext())
            #expect(v >= stops.min()! - 1e-9 && v <= stops.max()! + 1e-9)
        }
    }

    @Test func keyframesClampPhaseAndHandleSingleStop() {
        let k = XeerpeSignal<Double>.keyframes([1, 2, 3], phase: .constant(7))
        #expect(k.value(in: XeerpeContext()) == 3)
        #expect(XeerpeSignal<Double>.keyframes([4], phase: .constant(0.5)).value(in: XeerpeContext()) == 4)
        #expect(XeerpeSignal<Double>.keyframes([1, 2], phase: .constant(.nan)).value(in: XeerpeContext()) == 1)
    }

    @Test func keyframesInheritPhaseInputs() {
        let k = XeerpeSignal<Double>.keyframes([0, 1], phase: .hover(from: 0, to: 1))
        #expect(k.inputs == .hover)
    }

    @Test func cycleReturnsToItsFirstStopEveryPeriod() {
        let c = XeerpeSignal<Double>.cycle([3, 9, 5], period: 6)
        for _ in 0..<30 {
            let t = Double.random(in: 0...100)
            #expect(abs(c.value(in: XeerpeContext(time: t)) - c.value(in: XeerpeContext(time: t + 6))) < 1e-6)
        }
        #expect(abs(c.value(in: XeerpeContext(time: 0)) - 3) < 1e-9)
        #expect(c.value(in: XeerpeContext(time: 3, reduceMotion: true)) == 3)
    }

    @Test func sharedPhaseMakesEffectsMutateTogether() {
        let life = XeerpeSignal<Double>.time(period: 10, wave: .loop)
        let a = XeerpeSignal<Double>.keyframes([0, 100], phase: life)
        let b = XeerpeSignal<Double>.keyframes([5, 6], phase: life)
        let ctx = XeerpeContext(time: 2.5)
        #expect(abs(a.value(in: ctx) / 100 - (b.value(in: ctx) - 5)) < 1e-9)
    }
}

#if os(macOS)
@MainActor
@Suite struct SuperellipseTests {
    func alpha(_ n: Double, x: Int, y: Int) -> UInt8 {
        let v = Color.clear.xeerpe(XeerpeChain([.gradient(.aurora, in: Superellipse(exponent: n))]))
        return ShapeTests().alpha(v, x: x, y: y)
    }

    @Test func exponentTwoIsACircle() {
        #expect(alpha(2, x: 3, y: 3) == 0)
        #expect(alpha(2, x: 50, y: 50) > 200)
    }

    @Test func largeExponentApproachesTheRectangle() {
        #expect(alpha(20, x: 4, y: 4) > 200)
    }

    @Test func exponentOneIsADiamond() {
        #expect(alpha(1, x: 20, y: 20) == 0)
        #expect(alpha(1, x: 40, y: 40) > 200)
    }

    @Test func shapeSignalMutatesTheClip() {
        let circle = Color.clear.xeerpe(XeerpeChain([.gradient(.aurora, in: .superellipse(.constant(2)))]))
        let rect = Color.clear.xeerpe(XeerpeChain([.gradient(.aurora, in: .superellipse(.constant(20)))]))
        #expect(ShapeTests().alpha(circle, x: 3, y: 3) == 0)
        #expect(ShapeTests().alpha(rect, x: 4, y: 4) > 200)
    }
}
#endif

#if os(macOS)
@MainActor
@Suite struct ShaderTests {
    func render<V: View>(_ v: V) -> CGImage? {
        let r = ImageRenderer(content: v.frame(width: 120, height: 120)); r.scale = 1; return r.cgImage
    }
    func pixel(_ img: CGImage, _ x: Int, _ y: Int) -> [UInt8] {
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: -x, y: -(img.height - 1 - y), width: img.width, height: img.height))
        return px
    }

    @Test func liquidFillsOpaqueAndVariesAcrossTheSurface() {
        let img = render(Color.clear.xeerpe { .liquid() })
        #expect(img != nil)
        guard let img else { return }
        let samples = [(10, 10), (60, 60), (110, 20), (30, 100), (100, 100)].map { pixel(img, $0.0, $0.1) }
        #expect(samples.allSatisfy { $0[3] > 250 })
        #expect(Set(samples.map { $0.prefix(3).map(String.init).joined(separator: ",") }).count > 2)
    }

    @Test func liquidIsClippedToItsShape() {
        let img = render(Color.clear.xeerpe { .liquid(in: Circle()) })!
        #expect(pixel(img, 2, 2)[3] == 0)
        #expect(pixel(img, 60, 60)[3] > 250)
    }

    @Test func lensAndRippleAreInertWithoutInput() {
        let plain = render(Color.red)!, withFx = render(Color.red.xeerpe { .lens().ripple() })!
        for (x, y) in [(5, 5), (60, 60), (100, 90)] { #expect(pixel(plain, x, y) == pixel(withFx, x, y)) }
    }

    @Test func shaderEffectsDeclareOnlyTheInputsTheyRead() {
        #expect(XeerpeEffect.lens().inputs == .pointer)
        #expect(XeerpeEffect.ripple().inputs == .tap)
        #expect(XeerpeEffect.liquid().inputs == [.time, .pointer])
    }
}
#endif

#if os(macOS)
@MainActor
@Suite struct LensArtifactTests {
    func alpha(_ view: some View, x: Int, y: Int) -> UInt8 {
        // The first renders of a layer shader can come back as an opaque
        // placeholder while the pipeline compiles, so render until it settles.
        let r = ImageRenderer(content: view.frame(width: 100, height: 100)); r.scale = 1
        for _ in 0..<6 { _ = r.cgImage; RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        let img = r.cgImage!
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: -x, y: -(img.height - 1 - y), width: img.width, height: img.height))
        return px[3]
    }
    func lensed(_ content: some View, at p: CGPoint) -> some View {
        XeerpeChain.lens(radius: 70).render(AnyView(content.frame(width: 100, height: 100)), context: XeerpeContext(pointer: p))
    }

    @Test func lensKeepsTheCardsRoundedCornersTransparent() {
        // Real content (an opaque rounded card) with the lens over its corner.
        let card = Color.blue.frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 30)).padding(10)
        let v = lensed(card, at: CGPoint(x: 12, y: 12))
        #expect(alpha(v, x: 11, y: 11) == 0)
        #expect(alpha(v, x: 50, y: 50) > 250)
    }

    @Test func lensDoesNotPaintOutsideTheContentsOwnShape() {
        // A circle of content; the lens sits near the empty corner.
        let v = lensed(Circle().fill(Color.red).padding(10), at: CGPoint(x: 10, y: 10))
        #expect(alpha(v, x: 3, y: 3) == 0)
        #expect(alpha(v, x: 14, y: 6) == 0)
    }
}
#endif
