import SwiftUI
import Testing
@testable import xeerpe

/// RGBA bytes of `content` rendered through `effect`, 1 point per pixel.
@MainActor
func render(_ content: some View, _ effect: XeerpeEffect?, _ ctx: XeerpeContext = XeerpeContext()) -> (bytes: [UInt8], row: Int)? {
    let view = effect.map { XeerpeChain([$0]).render(AnyView(content), context: ctx) } ?? AnyView(content)
    let r = ImageRenderer(content: view)
    r.scale = 1
    guard let cg = r.cgImage, let d = cg.dataProvider?.data, let b = CFDataGetBytePtr(d) else { return nil }
    return (Array(UnsafeBufferPointer(start: b, count: CFDataGetLength(d))), cg.bytesPerRow)
}

func pixel(_ p: (bytes: [UInt8], row: Int), _ x: Int, _ y: Int) -> [UInt8] {
    let i = y * p.row + x * 4
    return Array(p.bytes[i..<i + 4])
}

/// Black and white stripes 3 points wide. Solid colors, not a gradient:
/// gradients are dithered and differ between renders.
@MainActor
private var ramp: some View {
    HStack(spacing: 0) { ForEach(0..<40) { i in (i.isMultiple(of: 2) ? Color.black : Color.white).frame(width: 3) } }.frame(height: 40)
}

@MainActor
@Suite struct PixelateTests {
    @Test func pixelsInOneCellMatchAndNeighbouringCellsDiffer() throws {
        let p = try #require(render(ramp, .pixelate(10)))
        let plain = try #require(render(ramp, nil))
        #expect(pixel(plain, 41, 5) != pixel(plain, 44, 5))
        #expect(pixel(p, 41, 5) == pixel(p, 44, 5))
        #expect(pixel(p, 41, 5) == pixel(p, 48, 9))
        #expect(pixel(p, 41, 5) != pixel(p, 51, 5))
    }

    @Test func sizeOfOneOrLessLeavesTheContentAlone() throws {
        let plain = try #require(render(ramp, nil))
        for size in [1.0, 0, -4, .nan] {
            #expect(try #require(render(ramp, .pixelate(.constant(size)))).bytes == plain.bytes)
        }
    }

    @Test func constantSizeSchedulesNoFrames() {
        #expect(!XeerpeEffect.pixelate(8).inputs.contains(.time))
    }
}

@Suite struct GlitchBurstTests {
    /// Every value is 0...1, bursts happen, and they never start more than
    /// twice in any second, under the three-flashes-a-second limit.
    @Test func burstsAreBoundedAndRare() {
        let step = 0.005
        var starts: [Double] = []
        var was = false
        for i in 0..<Int(120 / step) {
            let t = Double(i) * step
            let b = Xeerpe.glitchBurst(at: t)
            #expect(b >= 0 && b <= 1)
            if b > 0 && !was { starts.append(t) }
            was = b > 0
        }
        #expect(starts.count > 20)
        for (i, s) in starts.enumerated() {
            #expect(starts[i...].prefix { $0 < s + 1 }.count <= 2)
        }
    }

    @Test func nonFiniteTimeIsCalm() {
        #expect(Xeerpe.glitchBurst(at: .nan) == 0)
        #expect(Xeerpe.glitchBurst(at: .infinity) == 0)
    }
}

@MainActor
@Suite struct GlitchPixelTests {
    private var bars: some View {
        VStack(spacing: 0) { ForEach(0..<8) { i in (i.isMultiple(of: 2) ? Color.red : Color.blue) } }
            .overlay { HStack(spacing: 0) { Color.clear; Color.white.frame(width: 20); Color.clear } }
            .frame(width: 120, height: 80)
    }

    private var burstTime: Double {
        stride(from: 0.0, to: 60, by: 0.01).first { Xeerpe.glitchBurst(at: $0) > 0.5 } ?? 0
    }

    @Test func zeroAmountLeavesTheContentAlone() throws {
        let plain = try #require(render(bars, nil))
        let out = try #require(render(bars, .glitch(0), XeerpeContext(time: burstTime)))
        #expect(out.bytes == plain.bytes)
    }

    @Test func aBurstChangesTheContent() throws {
        let plain = try #require(render(bars, nil))
        let out = try #require(render(bars, .glitch(1, shift: 24), XeerpeContext(time: burstTime)))
        #expect(out.bytes != plain.bytes)
    }

    @Test func reduceMotionTurnsItOff() throws {
        let plain = try #require(render(bars, nil))
        let out = try #require(render(bars, .glitch(1), XeerpeContext(time: burstTime, reduceMotion: true)))
        #expect(out.bytes == plain.bytes)
    }
}

@MainActor
@Suite struct MatrixTests {
    private var box: some View { Color.clear.frame(width: 140, height: 140) }

    @Test func greenInsideTransparentOutsideTheShape() throws {
        let p = try #require(render(box, .matrix(in: Circle()), XeerpeContext(time: 3)))
        #expect(pixel(p, 1, 1)[3] == 0)
        var greenest = 0
        for y in stride(from: 30, to: 110, by: 2) {
            for x in stride(from: 30, to: 110, by: 2) {
                let c = pixel(p, x, y).map(Int.init)
                if c[1] > c[0] + 40 && c[1] > c[2] + 40 { greenest += 1 }
            }
        }
        #expect(greenest > 20)
    }

    @Test func itMovesUnlessReduceMotion() throws {
        let a = try #require(render(box, .matrix(), XeerpeContext(time: 1)))
        let b = try #require(render(box, .matrix(), XeerpeContext(time: 2.5)))
        #expect(a.bytes != b.bytes)
        let c = try #require(render(box, .matrix(), XeerpeContext(time: 1, reduceMotion: true)))
        let d = try #require(render(box, .matrix(), XeerpeContext(time: 2.5, reduceMotion: true)))
        #expect(c.bytes == d.bytes)
    }
}

@MainActor
@Suite struct NoSpillTests {
    private var bars: some View {
        VStack(spacing: 0) { ForEach(0..<8) { i in (i.isMultiple(of: 2) ? Color.red : Color.blue) } }.frame(width: 120, height: 80)
    }

    /// The shaders run in a sampling margin around the view; padding makes
    /// anything drawn there visible.
    private func margin(_ effect: XeerpeEffect, time: Double) throws -> [UInt8] {
        let ctx = XeerpeContext(time: time)
        let r = ImageRenderer(content: XeerpeChain([effect]).render(AnyView(bars), context: ctx).padding(30))
        r.scale = 1
        let cg = try #require(r.cgImage)
        let b = try #require(CFDataGetBytePtr(cg.dataProvider?.data))
        return [10, 170].map { x in b[70 * cg.bytesPerRow + x * 4 + 3] }
    }

    @Test func glitchStaysInsideItsFrame() throws {
        let t = stride(from: 0.0, to: 60, by: 0.01).first { Xeerpe.glitchBurst(at: $0) > 0.5 } ?? 0
        #expect(try margin(.glitch(1, shift: 24), time: t) == [0, 0])
    }

    @Test func pixelateStaysInsideItsFrame() throws {
        #expect(try margin(.pixelate(12), time: 0) == [0, 0])
    }

    @Test func halationAndAsciiStayInsideTheirFrame() throws {
        #expect(try margin(.halation(radius: 20, threshold: 0, intensity: 1), time: 0) == [0, 0])
        #expect(try margin(.ascii(cell: 12), time: 0) == [0, 0])
    }
}
