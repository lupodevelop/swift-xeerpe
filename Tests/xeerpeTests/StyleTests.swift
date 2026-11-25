import SwiftUI
import Testing
@testable import xeerpe

/// Distinct RGBA values in `p`, ignoring fully transparent pixels.
private func colors(_ p: (bytes: [UInt8], row: Int), width: Int, height: Int) -> Set<[UInt8]> {
    var out: Set<[UInt8]> = []
    for y in 0..<height { for x in 0..<width { let c = pixel(p, x, y); if c[3] > 0 { out.insert(c) } } }
    return out
}

/// Margin pixels: renders `effect` over `content` padded by 30 and returns
/// the alpha at (x, y) of the padded image.
@MainActor
private func alpha(_ content: some View, _ effect: XeerpeEffect, _ ctx: XeerpeContext = XeerpeContext(), at points: [(Int, Int)]) throws -> [UInt8] {
    let r = ImageRenderer(content: XeerpeChain([effect]).render(AnyView(content), context: ctx).padding(30))
    r.scale = 1
    let cg = try #require(r.cgImage)
    let b = try #require(CFDataGetBytePtr(cg.dataProvider?.data))
    return points.map { b[$0.1 * cg.bytesPerRow + $0.0 * 4 + 3] }
}

@MainActor
private var block: some View { Color(red: 0.2, green: 0.5, blue: 0.9).frame(width: 120, height: 80) }

@MainActor
@Suite struct BurnTests {
    @Test func zeroIsUntouchedOneIsGone() throws {
        let plain = try #require(render(block, nil))
        #expect(try #require(render(block, .burn(progress: 0))).bytes == plain.bytes)
        let gone = try #require(render(block, .burn(progress: 1)))
        #expect(colors(gone, width: 120, height: 80).isEmpty)
    }

    /// Fire climbs from the bottom: half way, the bottom is gone and the top is intact.
    @Test func burnsFromTheBottomUp() throws {
        let plain = try #require(render(block, nil))
        let p = try #require(render(block, .burn(progress: 0.5)))
        #expect(pixel(p, 60, 78)[3] == 0)
        #expect(pixel(p, 60, 2) == pixel(plain, 60, 2))
    }

    @Test func staticProgressSchedulesNoFrames() {
        #expect(!XeerpeEffect.burn(progress: 0.5).inputs.contains(.time))
    }
}

@MainActor
@Suite struct EmberTests {
    private var t: Double { 2.3 }

    @Test func sparksRiseAboveTheContent() throws {
        // The top 30 rows of the padded image are above the content.
        var found = false
        for time in stride(from: 1.0, to: 4, by: 0.37) where !found {
            let a = try alpha(block, .embers(), XeerpeContext(time: time), at: (30..<150).flatMap { x in (8..<30).map { (x, $0) } })
            found = a.contains { $0 > 0 }
        }
        #expect(found)
    }

    @Test func nothingFarAboveOrToTheSide() throws {
        let a = try alpha(block, .embers(height: 20), XeerpeContext(time: t), at: [(2, 70), (177, 70), (90, 2)])
        #expect(a == [0, 0, 0])
    }

    /// Sparks start only at edges: with a short climb, the middle of a
    /// solid block, far from its top and bottom, never gets one.
    @Test func solidInteriorDoesNotEmit() throws {
        let plain = try #require(render(block, nil))
        for time in stride(from: 1.0, to: 3, by: 0.29) {
            let p = try #require(render(block, .embers(height: 12), XeerpeContext(time: time)))
            for y in 30..<50 { for x in 0..<120 { #expect(pixel(p, x, y) == pixel(plain, x, y)) } }
        }
    }

    @Test func offAtZeroAndUnderReduceMotion() throws {
        let plain = try #require(render(block, nil))
        #expect(try #require(render(block, .embers(0), XeerpeContext(time: t))).bytes == plain.bytes)
        #expect(try #require(render(block, .embers(), XeerpeContext(time: t, reduceMotion: true))).bytes == plain.bytes)
    }
}

@MainActor
@Suite struct CRTTests {
    private var white: some View { Color.white.frame(width: 120, height: 80) }

    @Test func scanlinesDarkenEveryOtherBand() throws {
        let p = try #require(render(white, .scanlines(spacing: 4, intensity: 0.6)))
        let rows = (0..<8).map { Int(pixel(p, 60, 40 + $0)[0]) }
        #expect(rows.max()! - rows.min()! > 60)
        #expect(try #require(render(white, .scanlines(intensity: 0))).bytes == (try #require(render(white, nil))).bytes)
    }

    @Test func staticScanlinesScheduleNoFrames() {
        #expect(!XeerpeEffect.scanlines().inputs.contains(.time))
        #expect(XeerpeEffect.scanlines(roll: 1).inputs.contains(.time))
    }

    @Test func barrelClearsTheCornersAndKeepsTheCenter() throws {
        let plain = try #require(render(white, nil))
        let p = try #require(render(white, .barrel(0.3)))
        #expect(pixel(p, 0, 0)[3] == 0)
        #expect(zip(pixel(p, 60, 40), pixel(plain, 60, 40)).allSatisfy { abs(Int($0) - Int($1)) <= 2 })
        #expect(try #require(render(white, .barrel(0))).bytes == plain.bytes)
    }

    @Test func phosphorSplitsColumnsIntoRGB() throws {
        let p = try #require(render(white, .phosphor(size: 2, intensity: 1)))
        let r = pixel(p, 0, 10), g = pixel(p, 2, 10), b = pixel(p, 4, 10)
        #expect(r[0] > r[2] && g[1] > g[0] && b[2] > b[0])
    }

    @Test func vignetteDarkensCornersNotCenter() throws {
        let plain = try #require(render(white, nil))
        let p = try #require(render(white, .vignette(0.8)))
        #expect(Int(pixel(p, 1, 1)[0]) < Int(pixel(p, 60, 40)[0]) - 40)
        #expect(zip(pixel(p, 60, 40), pixel(plain, 60, 40)).allSatisfy { abs(Int($0) - Int($1)) <= 2 })
    }

    @Test func crtIsAnEditableChain() {
        let c = XeerpeChain.crt()
        #expect(c.effects.map(\.name).contains("barrel"))
        #expect(!c.without(.vignette).effects.map(\.name).contains("vignette"))
        #expect(!c.inputs.contains(.time))
        #expect(XeerpeChain.crt(roll: 1).inputs.contains(.time))
    }
}

@MainActor
@Suite struct DitherTests {
    private var steps: some View {
        HStack(spacing: 0) { ForEach(0..<12) { i in Color(white: Double(i) / 11) } }.frame(width: 120, height: 40)
    }

    @Test func mapsToAtMostFourColors() throws {
        let p = try #require(render(steps, .dither(.gameBoy)))
        #expect(colors(p, width: 120, height: 40).count <= 4)
    }

    @Test func midGrayIsDitheredBetweenTwo() throws {
        let p = try #require(render(Color(white: 0.45).frame(width: 40, height: 40), .dither(.gameBoy)))
        #expect(colors(p, width: 40, height: 40).count >= 2)
    }

    /// With the same pixel size, the dither grid lines up with pixelate's blocks.
    @Test func alignsWithPixelate() throws {
        let v = XeerpeChain([.pixelate(3), .dither(.gameBoy, pixel: 3)]).render(AnyView(steps))
        let p = try #require(render(v, nil))
        for bx in stride(from: 0, to: 117, by: 3) {
            let c = pixel(p, bx, 9)
            #expect(pixel(p, bx + 2, 9) == c && pixel(p, bx + 1, 11) == c)
        }
    }

    @Test func gameBoyPresetChains() {
        #expect(XeerpeChain.gameBoy().effects.map(\.name) == ["pixelate", "dither"])
    }
}

@MainActor
@Suite struct ToonTests {
    private var disc: some View { Circle().fill(Color(red: 1, green: 0.6, blue: 0.2)).frame(width: 80, height: 80) }

    /// Padded by 30: the disc spans 30...110, its edge at x = 30 on row 70.
    @Test func outlineDrawnOutsideTheShapeOnly() throws {
        let a = try alpha(disc, .toon(outline: .black, width: 4), at: [(28, 70), (22, 70)])
        #expect(a[0] > 200)
        #expect(a[1] == 0)
    }

    @Test func bandsLimitTheShades() throws {
        let steps = HStack(spacing: 0) { ForEach(0..<12) { i in Color(white: Double(i) / 11) } }.frame(width: 120, height: 40)
        let p = try #require(render(steps, .toon(levels: 3, width: 0, ink: 0)))
        #expect(colors(p, width: 120, height: 40).count <= 4)
    }
}

@MainActor
@Suite struct ComicTests {
    private func solid(_ c: Color) -> some View { c.frame(width: 60, height: 60) }

    private func all(_ p: (bytes: [UInt8], row: Int)) -> [[Int]] {
        (0..<60).flatMap { y in (0..<60).map { x in pixel(p, x, y).map(Int.init) } }
    }

    @Test func monoHalftoneIsPaperOnWhiteAndInkOnBlack() throws {
        let w = all(try #require(render(solid(.white), .halftone(size: 6))))
        #expect(w.allSatisfy { $0[0] > 240 })
        let b = all(try #require(render(solid(.black), .halftone(size: 6))))
        #expect(b.filter { $0[0] < 40 }.count > b.count * 9 / 10)
    }

    /// Darker gray, bigger dots; both inks show on a mid gray; and the
    /// result is gray whatever the input hue.
    @Test func monoDotsGrowWithDarkness() throws {
        func ink(_ g: Double) throws -> Int { all(try #require(render(solid(Color(white: g)), .halftone(size: 6)))).filter { $0[0] < 128 }.count }
        let light = try ink(0.75), dark = try ink(0.3)
        #expect(light > 0 && dark > light && dark < 3600)
        let red = all(try #require(render(solid(.red), .halftone(size: 6))))
        #expect(red.allSatisfy { abs($0[0] - $0[1]) < 8 && abs($0[1] - $0[2]) < 8 })
    }

    /// Red is magenta and yellow dots on white paper: no cyan, so the red
    /// channel stays high everywhere, while green and blue drop in the dots.
    @Test func coloredHalftoneSeparatesInks() throws {
        let p = all(try #require(render(solid(.red), .halftone(size: 6, colored: true))))
        #expect(p.allSatisfy { $0[0] > 200 })
        #expect(p.contains { $0[1] < 100 } && p.contains { $0[2] < 100 })
        #expect(p.contains { $0[1] > 200 && $0[2] > 200 })
    }

    @Test func vividSaturates() throws {
        let muted = Color(red: 0.6, green: 0.45, blue: 0.45)
        let a = pixel(try #require(render(solid(muted), .toon(levels: 0, width: 0, ink: 0))), 30, 30).map(Int.init)
        let b = pixel(try #require(render(solid(muted), .toon(levels: 0, width: 0, ink: 0, vivid: 1))), 30, 30).map(Int.init)
        #expect(b[0] - b[1] > a[0] - a[1] + 20)
    }

    /// Ink falls where shade jumps inside the content, not on flat areas.
    /// One view with a hard stop, not two views side by side: offscreen,
    /// ImageRenderer gives a layer shader wrong samples across sibling views.
    @Test func inkOnShadeEdges() throws {
        let halves = LinearGradient(stops: [.init(color: Color(white: 0.9), location: 0.5), .init(color: Color(white: 0.3), location: 0.5)],
                                    startPoint: .leading, endPoint: .trailing).frame(width: 80, height: 40)
        let on = try #require(render(halves, .toon(levels: 0, width: 0, ink: 0.2)))
        let off = try #require(render(halves, .toon(levels: 0, width: 0, ink: 0)))
        #expect(pixel(on, 40, 20)[0] < 40 && pixel(on, 10, 20)[0] > 200)
        #expect(pixel(off, 40, 20)[0] > 60)
    }

    @Test func presetsChain() {
        #expect(XeerpeChain.anime().effects.map(\.name).contains("toon"))
        #expect(XeerpeChain.manga().effects.map(\.name) == ["toon", "halftone"])
        #expect(XeerpeChain.comic().effects.map(\.name) == ["toon", "halftone"])
        #expect(XeerpeChain.celShaded().effects.map(\.name).contains("toon"))
    }
}
