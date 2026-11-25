import SwiftUI
import Testing
@testable import xeerpe

@MainActor
private func shot(_ v: some View, _ e: XeerpeEffect?, tilt: CGPoint = .zero) throws -> (bytes: [UInt8], row: Int) {
    try #require(render(v, e, XeerpeContext(tilt: tilt)))
}

private func lum(_ c: [UInt8]) -> Int { (Int(c[0]) * 3 + Int(c[1]) * 6 + Int(c[2])) / 10 }

@MainActor
@Suite struct BevelTests {
    private var slab: some View { Color(white: 0.45).frame(width: 100, height: 60) }

    @Test func edgesFacingTheLightBrightenTheOthersDarken() throws {
        let plain = try shot(slab, nil)
        let lit = try shot(slab, .bevel(width: 8), tilt: CGPoint(x: 0, y: -1))
        #expect(lum(pixel(lit, 50, 2)) > lum(pixel(plain, 50, 2)) + 30)
        #expect(lum(pixel(lit, 50, 57)) < lum(pixel(plain, 50, 57)) - 15)
        let flipped = try shot(slab, .bevel(width: 8), tilt: CGPoint(x: 0, y: 1))
        #expect(lum(pixel(flipped, 50, 57)) > lum(pixel(flipped, 50, 2)))
        #expect(abs(lum(pixel(lit, 50, 30)) - lum(pixel(plain, 50, 30))) <= 2)
    }

    @Test func staysInsideItsFrame() throws {
        let p = try #require(render(XeerpeChain([.bevel(width: 8)]).render(AnyView(slab), context: XeerpeContext()).padding(20), nil))
        #expect(pixel(p, 10, 50)[3] == 0 && pixel(p, 130, 50)[3] == 0)
    }
}

@MainActor
@Suite struct BrushedTests {
    private var plate: some View { Color(white: 0.5).frame(width: 120, height: 80) }

    /// Horizontal grain: brightness changes far more down a column than
    /// along a row.
    @Test func linearGrainRunsAlongRows() throws {
        let p = try shot(plate, .brushed())
        let row = (10..<110).map { lum(pixel(p, $0, 40)) }, col = (5..<75).map { lum(pixel(p, 60, $0)) }
        func spread(_ v: [Int]) -> Int { zip(v, v.dropFirst()).map { abs($0 - $1) }.reduce(0, +) }
        #expect(spread(col) > spread(row) * 2)
    }

    @Test func highlightFollowsTheTilt() throws {
        func brightestRow(_ t: CGPoint) throws -> Int {
            let p = try shot(plate, .brushed(intensity: 0.8), tilt: t)
            return (0..<80).max { a, b in
                (0..<120).map { lum(pixel(p, $0, a)) }.reduce(0, +) < (0..<120).map { lum(pixel(p, $0, b)) }.reduce(0, +)
            }!
        }
        #expect(try brightestRow(CGPoint(x: 0, y: -0.8)) < brightestRow(CGPoint(x: 0, y: 0.8)))
    }
}

@MainActor
@Suite struct FoilTests {
    private var logo: some View { Circle().fill(Color.blue).frame(width: 80, height: 80) }

    @Test func goldWhateverTheInkAndOnlyOnTheInk() throws {
        let p = try shot(logo, .foil())
        // Most of the disc is gold; the sheen whitens a diagonal band of it.
        let disc = (20..<60).flatMap { y in (20..<60).map { x in pixel(p, x, y).map(Int.init) } }
        #expect(disc.filter { $0[0] > $0[2] + 30 }.count > disc.count / 2)
        #expect(pixel(p, 2, 2)[3] == 0)
        let q = try shot(logo, .foil(), tilt: CGPoint(x: 0.9, y: 0.9))
        #expect(p.bytes != q.bytes)
    }
}

@MainActor
@Suite struct SparkleTests {
    private var gem: some View { Color(red: 0.1, green: 0.3, blue: 0.6).frame(width: 120, height: 80) }

    @Test func glintsAppearAndMoveWithTheTilt() throws {
        let plain = try shot(gem, nil)
        let a = try shot(gem, .sparkle(), tilt: CGPoint(x: 0.3, y: -0.2))
        let b = try shot(gem, .sparkle(), tilt: CGPoint(x: -0.6, y: 0.5))
        let bright = { (p: (bytes: [UInt8], row: Int)) in (0..<80).flatMap { y in (0..<120).map { x in lum(pixel(p, x, y)) } }.filter { $0 > lum(pixel(plain, 0, 0)) + 120 }.count }
        #expect(bright(a) > 0 && bright(b) > 0)
        #expect(a.bytes != b.bytes)
    }

    @Test func nothingOnClearPixels() throws {
        let p = try shot(Circle().fill(Color.blue).frame(width: 80, height: 80), .sparkle(density: 1))
        #expect(pixel(p, 1, 1)[3] == 0)
    }
}

@MainActor
@Suite struct GuillocheAndPearlTests {
    private var dark: some View { Color(white: 0.1).frame(width: 120, height: 80) }
    private var light: some View { Color(white: 0.9).frame(width: 120, height: 80) }

    @Test func guillocheDrawsFineLines() throws {
        let plain = try shot(dark, nil)
        let p = try shot(dark, .guilloche())
        let l = (0..<120).map { lum(pixel(p, $0, 40)) }
        #expect(l.max()! > lum(pixel(plain, 60, 40)) + 40)
        #expect(l.min()! <= lum(pixel(plain, 60, 40)) + 4)
        #expect(try shot(dark, .guilloche(intensity: 0)).bytes == plain.bytes)
    }

    @Test func pearlIsIridescentAndTurnsWithTheTilt() throws {
        let p = try shot(light, .pearl())
        let hues = Set((0..<12).map { i -> Int in let c = pixel(p, i * 10, 40); return Int(c[0] > c[2] ? 1 : 0) + Int(c[1] > c[0] ? 2 : 0) })
        #expect(hues.count >= 2)
        #expect(try shot(light, .pearl(), tilt: CGPoint(x: 0.8, y: 0)).bytes != p.bytes)
        #expect(try shot(light, .pearl(intensity: 0)).bytes == (try shot(light, nil)).bytes)
    }
}

@Suite struct LuxuryPresetTests {
    @Test func jewelKeepsItsFinishesInTheBackdrop() {
        #expect(XeerpeChain.jewel().effects.map(\.name) == ["backdrop"])
    }
}

@MainActor
@Suite struct BackdropTests {
    /// A small black mark on a clear 100x60 view: the content.
    private var mark: some View { Color.black.frame(width: 20, height: 20).frame(width: 100, height: 60) }

    /// Finishes in a backdrop shape the surface behind the content and
    /// leave the content's own pixels exactly as they were.
    @Test func finishesStayBehindTheContent() throws {
        let p = try shot(mark, .backdrop { .gradient(.aurora).brushed(intensity: 1).bevel(width: 6) }, tilt: CGPoint(x: 0, y: -0.5))
        #expect(pixel(p, 50, 30) == [0, 0, 0, 255])
        #expect(pixel(p, 5, 5)[3] == 255)
        let plainGradient = try shot(Color.clear.frame(width: 100, height: 60), .gradient(.aurora))
        #expect(pixel(p, 50, 3) != pixel(plainGradient, 50, 3))
    }

    @Test func readsTheInputsOfItsChain() {
        #expect(XeerpeEffect.backdrop { .brushed(.tilt) }.inputs.contains(.tilt))
    }

    @Test func metalCardKeepsItsFinishesInTheBackdrop() {
        let c = XeerpeChain.metalCard()
        #expect(c.effects.map(\.name) == ["backdrop", "tilt3D"])
    }
}
