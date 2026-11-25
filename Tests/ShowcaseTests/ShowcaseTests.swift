import SwiftUI
import Testing
@testable import xeerpe
@testable import xeerpe_preview

@MainActor
private func render(_ content: some View, _ effect: XeerpeEffect, _ ctx: XeerpeContext) -> [UInt8]? {
    let r = ImageRenderer(content: XeerpeChain([effect]).render(AnyView(content), context: ctx))
    r.scale = 1
    guard let cg = r.cgImage, let d = cg.dataProvider?.data, let b = CFDataGetBytePtr(d) else { return nil }
    return Array(UnsafeBufferPointer(start: b, count: CFDataGetLength(d)))
}

/// Largest difference of any byte between two renders. Gradients are
/// dithered, so two renders of the same frame can differ by a step or two.
private func maxDiff(_ a: [UInt8], _ b: [UInt8]) -> Int { zip(a, b).map { abs(Int($0) - Int($1)) }.max() ?? 0 }

@Suite struct SynthwaveTests {
    @Test func rowsCrowdTowardTheHorizonAndScrollDown() throws {
        let a = Synthwave.rows(phase: 0, horizon: 100, bottom: 300)
        #expect(a.allSatisfy { $0 > 100 && $0 <= 300 })
        let gaps = zip(a, a.dropFirst()).map { $0 - $1 }
        #expect(gaps.allSatisfy { $0 > 0 })
        #expect(zip(gaps, gaps.dropFirst()).allSatisfy { $0 > $1 })
        let b = Synthwave.rows(phase: 0.3, horizon: 100, bottom: 300)
        #expect(b[0] > a[1] && b[0] < a[0])
        // Lines come toward the viewer: the farthest one moves down.
        let farA = try #require(a.last), farB = try #require(b.last)
        #expect(farB > farA)
        #expect(Synthwave.rows(phase: 1, horizon: 100, bottom: 300) == a)
    }

    @MainActor
    @Test func itMovesUnlessReduceMotionOrStill() throws {
        let box = Color.clear.frame(width: 160, height: 100)
        let a = try #require(render(box, .synthwave(), XeerpeContext(time: 0.2)))
        let b = try #require(render(box, .synthwave(), XeerpeContext(time: 0.9)))
        #expect(maxDiff(a, b) > 60)
        let c = try #require(render(box, .synthwave(), XeerpeContext(time: 0.2, reduceMotion: true)))
        let d = try #require(render(box, .synthwave(), XeerpeContext(time: 0.9, reduceMotion: true)))
        #expect(maxDiff(c, d) <= 4)
        #expect(XeerpeEffect.synthwave(speed: 0).inputs.isEmpty)
    }
}

/// The showcase recipes are compositions of library effects: none of them
/// may claim a property twice, and only the moving ones run frames.
@Suite struct RecipeTests {
    var all: [(String, XeerpeChain)] {
        [("oneBit", .oneBit()), ("nightVision", .nightVision()), ("thermal", .thermal()), ("terminal", .terminal()), ("neonSign", .neonSign())]
    }

    @Test func recipesAreFreeOfConflictsAndNeverEmpty() {
        for (name, s) in all {
            #expect(!s.effects.isEmpty, Comment(rawValue: name))
            #expect(s.conflicts.isEmpty, Comment(rawValue: name))
        }
    }

    @Test func onlyMovingRecipesScheduleFrames() {
        for (name, s) in all {
            #expect(s.inputs.contains(.time) == ["nightVision", "neonSign"].contains(name), Comment(rawValue: name))
        }
        #expect(!XeerpeChain.neonSign(flicker: 0).inputs.contains(.time))
    }
}

/// The scanner is the showcase's own Metal shader, written with
/// `XeerpeEffect.shader`: what the line has passed is black and white, the
/// rest keeps its color.
@MainActor
@Suite struct ScannerTests {
    @Test func scannedPartIsGreyAndTheRestKeepsItsColor() throws {
        let box = Color(red: 0.9, green: 0.4, blue: 0.1).frame(width: 40, height: 100)
        let r = ImageRenderer(content: XeerpeChain([.scan(0.5)]).render(AnyView(box), context: XeerpeContext()))
        r.scale = 1
        let cg = try #require(r.cgImage), data = try #require(cg.dataProvider?.data)
        let bytes = Array(UnsafeBufferPointer(start: CFDataGetBytePtr(data), count: CFDataGetLength(data)))
        func rgb(_ y: Int) -> [Int] { bytes[(y * cg.bytesPerRow + 80)..<(y * cg.bytesPerRow + 83)].map(Int.init) }
        let top = rgb(10), bottom = rgb(90)
        #expect(abs(top[0] - top[1]) <= 2 && abs(top[1] - top[2]) <= 2)
        #expect(bottom[0] > bottom[2] + 100)
        #expect(XeerpeEffect.scan(0).inputs.isEmpty)
    }

    /// At 0 the line has not started: no glow along the top edge.
    @Test func zeroLeavesTheContentAlone() throws {
        let box = Color(red: 0.9, green: 0.4, blue: 0.1).frame(width: 40, height: 100)
        func top(_ chain: XeerpeChain) throws -> [UInt8] {
            let r = ImageRenderer(content: chain.render(AnyView(box), context: XeerpeContext()))
            r.scale = 1
            let cg = try #require(r.cgImage), data = try #require(cg.dataProvider?.data)
            return Array(UnsafeBufferPointer(start: CFDataGetBytePtr(data), count: cg.bytesPerRow * 4))
        }
        #expect(try top(XeerpeChain([.scan(0)])) == top(XeerpeChain()))
    }
}

/// The before/after view lays both sides out in the same frame, so the same
/// content lines up across the split.
@MainActor
@Suite struct CompareTests {
    /// Bars at a quarter and three quarters of the width: they move if a
    /// side is laid out wider than the frame.
    var bars: some View {
        Canvas { c, size in
            for f in [0.25, 0.75] { c.fill(Path(CGRect(x: size.width * f - 2, y: 0, width: 4, height: size.height)), with: .color(.red)) }
        }
        .frame(height: 100)
    }

    func pixels(_ view: some View) throws -> (bytes: [UInt8], row: Int) {
        let r = ImageRenderer(content: view.frame(width: 200, height: 100))
        r.scale = 1
        let cg = try #require(r.cgImage), data = try #require(cg.dataProvider?.data)
        return (Array(UnsafeBufferPointer(start: CFDataGetBytePtr(data), count: CFDataGetLength(data))), cg.bytesPerRow)
    }

    @Test func sameContentLinesUpAcrossTheSplit() throws {
        let plain = try pixels(bars), split = try pixels(Compare(before: bars, after: bars))
        for x in [50, 150] {
            let i = 20 * plain.row + x * 4
            #expect(split.bytes[i..<i + 4] == plain.bytes[i..<i + 4])
        }
    }
}
