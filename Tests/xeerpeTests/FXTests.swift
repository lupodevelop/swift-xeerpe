import SwiftUI
import Testing
@testable import xeerpe

@MainActor
private func image(_ v: some View) throws -> (bytes: [UInt8], row: Int) {
    try #require(render(v, nil))
}

/// Alpha at (x, y) of `content` through `effect`, padded by 30.
@MainActor
private func paddedAlpha(_ content: some View, _ effect: XeerpeEffect, _ ctx: XeerpeContext, _ points: [(Int, Int)]) throws -> [UInt8] {
    let p = try image(XeerpeChain([effect]).render(AnyView(content), context: ctx).padding(30))
    return points.map { pixel(p, $0.0, $0.1)[3] }
}

@MainActor
@Suite struct GooeyTests {
    /// Two discs in one path (one view: offscreen renders sample siblings wrong).
    private func discs(gap: Double) -> some View {
        Path { p in
            p.addEllipse(in: CGRect(x: 10, y: 10, width: 40, height: 40))
            p.addEllipse(in: CGRect(x: 50 + gap, y: 10, width: 40, height: 40))
        }
        .fill(Color.orange).frame(width: 100 + gap, height: 60)
    }

    @Test func nearShapesMergeFarShapesDoNot() throws {
        let near = try image(XeerpeChain([.gooey(radius: 12)]).render(AnyView(discs(gap: 6))))
        let plainNear = try image(discs(gap: 6))
        #expect(pixel(plainNear, 53, 30)[3] == 0)
        #expect(pixel(near, 53, 30)[3] > 200)
        let far = try image(XeerpeChain([.gooey(radius: 12)]).render(AnyView(discs(gap: 60))))
        #expect(pixel(far, 80, 30)[3] == 0)
        #expect(pixel(far, 30, 30)[3] > 200)
    }
}

@Suite struct TextRiseMathTests {
    @Test func startsHiddenEndsShownInOrder() {
        for _ in 0..<200 {
            let n = Int.random(in: 1...40), i = Int.random(in: 0..<n), j = Int.random(in: 0..<n)
            let p = Double.random(in: 0...1), q = Double.random(in: 0...1), s = Double.random(in: 0.5...6)
            #expect(Xeerpe.riseAmount(index: i, count: n, progress: 0, spread: s) == 0)
            #expect(Xeerpe.riseAmount(index: i, count: n, progress: 1, spread: s) == 1)
            #expect(Xeerpe.riseAmount(index: i, count: n, progress: max(p, q), spread: s) >= Xeerpe.riseAmount(index: i, count: n, progress: min(p, q), spread: s))
            #expect(Xeerpe.riseAmount(index: min(i, j), count: n, progress: p, spread: s) >= Xeerpe.riseAmount(index: max(i, j), count: n, progress: p, spread: s))
        }
    }

    @Test func nonFiniteProgressIsHidden() {
        #expect(Xeerpe.riseAmount(index: 0, count: 3, progress: .nan, spread: 2) == 0)
    }
}

@MainActor
@Suite struct SmokeAndSparkTests {
    private var block: some View { Color.blue.frame(width: 120, height: 60) }

    @Test func smokeRisesAboveAndOnlyThere() throws {
        var seen = false
        for t in stride(from: 0.5, to: 4, by: 0.5) where !seen {
            let a = try paddedAlpha(block, .smoke(), XeerpeContext(time: t), (40..<140).map { ($0, 20) })
            seen = a.contains { $0 > 0 }
        }
        #expect(seen)
        #expect(try paddedAlpha(block, .smoke(), XeerpeContext(time: 2), [(2, 80), (177, 80)]) == [0, 0])
    }

    @Test func smokeOffAtZeroAndUnderReduceMotion() throws {
        let plain = try image(block)
        #expect(try #require(render(block, .smoke(0), XeerpeContext(time: 2))).bytes == plain.bytes)
        #expect(try #require(render(block, .smoke(), XeerpeContext(time: 2, reduceMotion: true))).bytes == plain.bytes)
    }

    @Test func sparksBurstAfterATapThenStop() throws {
        let plain = try image(block)
        let tap = XeerpeTap(location: CGPoint(x: 60, y: 30), time: 1)
        #expect(try #require(render(block, .sparks(), XeerpeContext(time: 5))).bytes == plain.bytes)
        let burst = try #require(render(block, .sparks(), XeerpeContext(time: 1.15, tap: tap)))
        #expect(burst.bytes != plain.bytes)
        #expect(try #require(render(block, .sparks(), XeerpeContext(time: 4, tap: tap))).bytes == plain.bytes)
        #expect(XeerpeEffect.sparks().inputs.contains(.tap))
    }
}

@MainActor
@Suite struct GenieTests {
    private var block: some View { Color.green.frame(width: 120, height: 80) }

    @Test func endpoints() throws {
        let plain = try image(block)
        #expect(try #require(render(block, .genie(progress: 0))).bytes == plain.bytes)
        let gone = try #require(render(block, .genie(progress: 1)))
        #expect((0..<80).allSatisfy { y in (0..<120).allSatisfy { pixel(gone, $0, y)[3] == 0 } })
    }

    /// Half way to the bottom center: the top has emptied, and low rows have
    /// pinched toward the target, clear at the sides, full at the center.
    @Test func halfWaySqueezesTowardTheTarget() throws {
        let p = try #require(render(block, .genie(progress: 0.5, to: .bottom)))
        #expect(pixel(p, 60, 2)[3] == 0)
        #expect(pixel(p, 60, 76)[3] > 200)
        #expect(pixel(p, 3, 76)[3] == 0)
    }
}

@MainActor
@Suite struct VHSRisoTests {
    private var bars: some View {
        LinearGradient(stops: [.init(color: .white, location: 0.5), .init(color: .black, location: 0.5)], startPoint: .leading, endPoint: .trailing)
            .frame(width: 120, height: 60)
    }

    @Test func colorBleedSmearsChromaSideways() throws {
        let red = LinearGradient(stops: [.init(color: .red, location: 0.5), .init(color: .blue, location: 0.5)], startPoint: .leading, endPoint: .trailing)
            .frame(width: 120, height: 60)
        let plain = try image(red)
        let p = try #require(render(red, .colorBleed(8)))
        // Red smears into the blue half: just past the edge it gains red.
        #expect(Int(pixel(p, 63, 30)[0]) > Int(pixel(plain, 63, 30)[0]) + 40)
        #expect(zip(pixel(p, 10, 30), pixel(plain, 10, 30)).allSatisfy { abs(Int($0) - Int($1)) <= 2 })
        // Off-state bytes on a solid color: gradients dither differently each render.
        let solid = Color.red.frame(width: 120, height: 60)
        #expect(try #require(render(solid, .colorBleed(0))).bytes == (try image(solid)).bytes)
    }

    @Test func vhsIsAnEditableChainThatMoves() {
        let c = XeerpeChain.vhs()
        #expect(c.effects.map(\.name).contains("colorBleed"))
        #expect(c.effects.map(\.name).contains("tracking"))
        #expect(c.inputs.contains(.time))
        #expect(!c.without(.tracking).effects.map(\.name).contains("tracking"))
    }

    @Test func trackingOffUnderReduceMotion() throws {
        let solid = Color.purple.frame(width: 120, height: 60)
        #expect(try #require(render(solid, .tracking(), XeerpeContext(time: 2, reduceMotion: true))).bytes == (try image(solid)).bytes)
    }

    /// Two inks on paper: white stays paper, black is both inks, and the
    /// inks are offset so an edge shows a fringe of one ink alone.
    @Test func risoPrintsTwoOffsetInks() throws {
        let p = try #require(render(bars, .riso([.pink, .blue], offset: 3, grain: 0)))
        let paper = pixel(p, 20, 30), both = pixel(p, 100, 30)
        #expect(paper.map(Int.init).allSatisfy { $0 > 230 })
        #expect(Int(both[0]) + Int(both[1]) + Int(both[2]) < 250)
        let fringe = (55..<66).map { pixel(p, $0, 30) }
        #expect(fringe.contains { $0 != paper && $0 != both })
    }
}

@MainActor
@Suite struct FXNoSpillTests {
    private var block: some View { Color.purple.frame(width: 120, height: 60) }

    /// Padded by 30, content spans x 30...150: the side margins stay clear.
    @Test func sampledEffectsStayInsideTheirFrame() throws {
        for e in [XeerpeEffect.colorBleed(8), .tracking(6), .riso(offset: 6)] {
            #expect(try paddedAlpha(block, e, XeerpeContext(time: 1.3), [(26, 60), (154, 60)]) == [0, 0], "\(e.name)")
        }
    }
}
