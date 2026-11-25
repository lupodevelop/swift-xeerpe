import SwiftUI
import Testing
@testable import xeerpe

/// Renders `content` through `effect` with the given settings and returns
/// the RGBA bytes of the image, row-major, 1 point per pixel.
@MainActor
private func pixels(_ content: some View, _ effect: XeerpeEffect, reduceTransparency: Bool) -> (bytes: [UInt8], row: Int)? {
    let ctx = XeerpeContext(reduceTransparency: reduceTransparency)
    let r = ImageRenderer(content: XeerpeChain([effect]).render(AnyView(content), context: ctx))
    r.scale = 1
    guard let cg = r.cgImage, let d = cg.dataProvider?.data, let b = CFDataGetBytePtr(d) else { return nil }
    return (Array(UnsafeBufferPointer(start: b, count: CFDataGetLength(d))), cg.bytesPerRow)
}

@MainActor
@Suite struct ReduceTransparencyTests {
    private var halves: some View { HStack(spacing: 0) { Color.black; Color.white }.frame(width: 120, height: 60) }

    /// Hidden by privacy, the two halves become one opaque cover instead of
    /// a blur that lets the edge show through.
    @Test func privacyCoversInsteadOfBlurring() throws {
        let p = try #require(pixels(halves, .privacy(1.0), reduceTransparency: true))
        let left = 30 * p.row + 10 * 4, right = 30 * p.row + 110 * 4
        #expect(p.bytes[left..<left + 4] == p.bytes[right..<right + 4])
        #expect(p.bytes[left + 3] == 255)
    }

    /// Swept fully, the content goes dark without any blur mixing the halves.
    @Test func blurSweepDimsInsteadOfBlurring() throws {
        let p = try #require(pixels(halves, .blurSweep(progress: 1, maxBlur: 20, darken: 0), reduceTransparency: true))
        let right = 30 * p.row + 110 * 4
        #expect(p.bytes[right] < 30)
        let normal = try #require(pixels(halves, .blurSweep(progress: 1, maxBlur: 20, darken: 0), reduceTransparency: false))
        #expect(normal.bytes[right] > 200)
    }

    /// No light spills outside the content: bloom adds nothing around it.
    @Test func bloomSpillsNothing() throws {
        let dot = Color.white.frame(width: 20, height: 20).frame(width: 80, height: 80)
        let off = try #require(pixels(dot, .bloom(radius: 12, intensity: 1), reduceTransparency: true))
        let on = try #require(pixels(dot, .bloom(radius: 12, intensity: 1), reduceTransparency: false))
        let near = 40 * off.row + 54 * 4 + 3
        #expect(off.bytes[near] == 0)
        #expect(on.bytes[near] > 0)
    }

    /// The edge glow keeps a crisp line on the border and drops the soft
    /// bands that bleed over the content.
    @Test func edgeGlowKeepsOnlyTheLine() throws {
        let box = Color.clear.frame(width: 120, height: 120)
        let glow = XeerpeEffect.edgeGlow(intensity: 1, in: Rectangle())
        let off = try #require(pixels(box, glow, reduceTransparency: true))
        let on = try #require(pixels(box, glow, reduceTransparency: false))
        let inside = 60 * off.row + 20 * 4 + 3, edge = 60 * off.row + 1 * 4 + 3
        #expect(off.bytes[inside] == 0)
        #expect(on.bytes[inside] > 0)
        #expect(off.bytes[edge] > 0)
    }

    /// On a black card the glare is the only light: with it off, every
    /// pixel stays black. Drawing on an opaque base also keeps the check off
    /// renderer memory that nothing painted.
    @Test func glareDrawsNothing() throws {
        let card = Color.black.frame(width: 80, height: 80)
        let off = try #require(pixels(card, .glare(.constant(.zero), intensity: 1), reduceTransparency: true))
        let on = try #require(pixels(card, .glare(.constant(.zero), intensity: 1), reduceTransparency: false))
        // Rows can be padded past the image width: read only its pixels.
        let light = { (p: (bytes: [UInt8], row: Int)) in
            (0..<80).flatMap { y in (0..<80).map { x in (0..<3).map { p.bytes[y * p.row + x * 4 + $0] }.max()! } }
        }
        #expect(light(off).allSatisfy { $0 == 0 })
        #expect(light(on).contains { $0 > 0 })
    }
}

@Suite struct LowPowerTests {
    @Test func lowPowerRunsFewerFrames() {
        #expect(Xeerpe.frameInterval(lowPower: true) > Xeerpe.frameInterval(lowPower: false))
    }

    @MainActor @Test func lowPowerSignalFollowsTheContext() {
        var ctx = XeerpeContext()
        #expect(XeerpeValue.lowPower.value(in: ctx) == 0)
        ctx.isLowPower = true
        #expect(XeerpeValue.lowPower.value(in: ctx) == 1)
    }
}
