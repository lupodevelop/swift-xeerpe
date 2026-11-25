#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import xeerpe

@MainActor
@Suite struct ShapeTests {
    /// Alpha of the pixel at (x, y) of a 100x100 render of `view`.
    func alpha<V: View>(_ view: V, x: Int, y: Int) -> UInt8 {
        let r = ImageRenderer(content: view.frame(width: 100, height: 100))
        r.scale = 1
        guard let img = r.cgImage else { return 255 }
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: -x, y: -(img.height - 1 - y), width: img.width, height: img.height))
        return px[3]
    }

    @Test func gradientWithoutShapeFillsTheRectangle() {
        let v = Color.clear.xeerpe(XeerpeChain([.gradient(.aurora)]))
        #expect(alpha(v, x: 1, y: 1) > 200)
        #expect(alpha(v, x: 50, y: 50) > 200)
    }

    @Test func gradientIsClippedToTheGivenShape() {
        let v = Color.clear.xeerpe(XeerpeChain([.gradient(.aurora, in: Circle())]))
        #expect(alpha(v, x: 1, y: 1) == 0)
        #expect(alpha(v, x: 98, y: 98) == 0)
        #expect(alpha(v, x: 50, y: 50) > 200)
    }

    @Test func glowAfterShapedGradientFollowsTheShape() {
        let v = Color.clear.padding(20)
            .xeerpe { .gradient(.aurora, in: Circle()).glow(.red, radius: 6) }
        // Corner of the padded frame is far from the circle: no shadow there.
        #expect(alpha(v, x: 1, y: 1) == 0)
    }
}
#endif

#if os(macOS)
@MainActor
@Suite struct FillAndGlassTests {
    func alpha<V: View>(_ view: V, x: Int, y: Int) -> UInt8 {
        ShapeTests().alpha(view, x: x, y: y)
    }

    @Test func fillColorsOnlyTheContentsOwnPixels() {
        let glyph = Circle().fill(Color.white).padding(10)
        let v = glyph.xeerpe(XeerpeChain([.fill(.aurora)]))
        #expect(alpha(v, x: 1, y: 1) == 0)
        #expect(alpha(v, x: 50, y: 50) > 200)
    }

    @Test func glassDeclaresSurfaceClaimAndFallsBackToAViewEverywhere() {
        let e = XeerpeEffect.glass(.regular, tint: .blue, interactive: true, in: Circle())
        #expect(e.slot == .background)
        #expect(e.claims == [.surface])
        #expect(XeerpeEffect.glass().claims == [.surface])
    }

    @Test func glassAndFrostedConflictBecauseBothOwnTheSurface() {
        #expect(XeerpeChain.glass().glass().conflicts.count == 1)
    }
}
#endif
