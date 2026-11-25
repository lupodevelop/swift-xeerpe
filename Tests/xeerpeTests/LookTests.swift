import SwiftUI
import Testing
@testable import xeerpe

@MainActor
private func solid(_ color: Color, _ w: Double = 40, _ h: Double = 40) -> some View { color.frame(width: w, height: h) }

private func gray(_ v: Double) -> Color { Color(red: v, green: v, blue: v) }

/// Channels of a pixel as Ints, so differences do not overflow.
private func rgb(_ p: (bytes: [UInt8], row: Int), _ x: Int, _ y: Int) -> [Int] { pixel(p, x, y).map(Int.init) }

private func near(_ a: [Int], _ b: [Int], _ tolerance: Int = 3) -> Bool { zip(a, b).allSatisfy { abs($0 - $1) <= tolerance } }

/// Largest difference of any byte between two renders. Gradients are
/// dithered, so two renders of the same frame can differ by a step or two.
private func maxDiff(_ a: (bytes: [UInt8], row: Int), _ b: (bytes: [UInt8], row: Int)) -> Int {
    zip(a.bytes, b.bytes).map { abs(Int($0) - Int($1)) }.max() ?? 0
}

/// Opaque grey on the left half, clear on the right, in one layer. A view
/// that is clear everywhere is not used: offscreen it sometimes renders with
/// stray alpha under load, whatever the effect.
@MainActor
private var halfClear: some View {
    Canvas { c, size in c.fill(Path(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)), with: .color(gray(0.5))) }
        .frame(width: 60, height: 40)
}

/// Whether every pixel of the right half has zero alpha.
private func rightHalfClear(_ p: (bytes: [UInt8], row: Int)) -> Bool {
    (0..<40).allSatisfy { y in (32..<60).allSatisfy { x in pixel(p, x, y)[3] == 0 } }
}

@MainActor
@Suite struct GradeTests {
    @Test func neutralLeavesTheContentAlone() throws {
        for c in [Color.red, gray(0.3), Color(red: 0.2, green: 0.6, blue: 0.9)] {
            let plain = try #require(render(solid(c), nil))
            #expect(try #require(render(solid(c), .grade())).bytes == plain.bytes)
        }
    }

    @Test func saturationMinusOneIsGrey() throws {
        let p = rgb(try #require(render(solid(.red), .grade(saturation: -1))), 20, 20)
        #expect(abs(p[0] - p[1]) <= 2 && abs(p[1] - p[2]) <= 2)
    }

    @Test func contrastPushesTonesApart() throws {
        let dark = rgb(try #require(render(solid(gray(0.3)), nil)), 5, 5)[0]
        let light = rgb(try #require(render(solid(gray(0.7)), nil)), 5, 5)[0]
        #expect(rgb(try #require(render(solid(gray(0.3)), .grade(contrast: 0.5))), 5, 5)[0] < dark)
        #expect(rgb(try #require(render(solid(gray(0.7)), .grade(contrast: 0.5))), 5, 5)[0] > light)
        #expect(rgb(try #require(render(solid(gray(0.3)), .grade(contrast: -0.5))), 5, 5)[0] > dark)
    }

    @Test func warmthMovesRedAgainstBlue() throws {
        let warm = rgb(try #require(render(solid(gray(0.5)), .grade(warmth: 1))), 5, 5)
        let cool = rgb(try #require(render(solid(gray(0.5)), .grade(warmth: -1))), 5, 5)
        #expect(warm[0] > warm[2] && cool[2] > cool[0])
    }

    @Test func fadeLiftsBlack() throws {
        #expect(rgb(try #require(render(solid(.black), .grade(fade: 1))), 5, 5)[0] > 30)
    }

    /// Shadow tint reaches dark tones and not light ones; highlight tint the
    /// other way round. Its strength is the tint's opacity.
    @Test func splitToningFollowsTheTones() throws {
        let tint = Color(red: 0, green: 0.3, blue: 1)
        let dark = rgb(try #require(render(solid(gray(0.2)), .grade(shadows: tint))), 5, 5)
        #expect(dark[2] > dark[0] + 10)
        let light = rgb(try #require(render(solid(gray(0.9)), .grade(shadows: tint))), 5, 5)
        #expect(abs(light[2] - light[0]) <= 3)
        let lit = rgb(try #require(render(solid(gray(0.9)), .grade(highlights: tint))), 5, 5)
        #expect(lit[2] > lit[0] + 10)
        let half = rgb(try #require(render(solid(gray(0.2)), .grade(shadows: tint.opacity(0.4)))), 5, 5)
        #expect(half[2] - half[0] < dark[2] - dark[0] && half[2] > half[0])
    }

    /// Adaptive tints take the variant of the view's own color scheme:
    /// `.primary` is dark in light mode and light in dark mode.
    @Test func tintsFollowTheColorScheme() throws {
        func lit(_ scheme: ColorScheme) throws -> Int {
            let view = XeerpeChain { .grade(highlights: .primary.opacity(0.8)) }
                .render(AnyView(solid(gray(0.85)))).environment(\.colorScheme, scheme)
            return rgb(try #require(render(view, nil)), 5, 5)[0]
        }
        #expect(try lit(.dark) > lit(.light) + 20)
    }

    @Test func transparentStaysTransparent() throws {
        #expect(rightHalfClear(try #require(render(halfClear, .grade(fade: 1)))))
    }
}

@MainActor
@Suite struct GradientMapTests {
    let ramp = [Color(red: 0.1, green: 0, blue: 0.5), Color(red: 1, green: 0.2, blue: 0.1), Color(red: 1, green: 1, blue: 0.6)]

    @Test func blackAndWhiteTakeTheEndStops() throws {
        let b = rgb(try #require(render(solid(.black), .gradientMap(ramp))), 5, 5)
        let w = rgb(try #require(render(solid(.white), .gradientMap(ramp))), 5, 5)
        #expect(near(b, [26, 0, 128, 255], 4))
        #expect(near(w, [255, 255, 153, 255], 4))
    }

    @Test func midGreyTakesTheMiddleStop() throws {
        // Brightness 0.5 lies on the middle of three stops.
        let m = rgb(try #require(render(solid(gray(0.5)), .gradientMap(ramp))), 5, 5)
        #expect(m[0] > 200 && m[1] < 120 && m[2] < 80)
    }

    @Test func zeroAmountLeavesTheContentAlone() throws {
        let plain = try #require(render(solid(gray(0.4)), nil))
        #expect(try #require(render(solid(gray(0.4)), .gradientMap(ramp, amount: 0))).bytes == plain.bytes)
    }

    @Test func emptyColorsFallBackToBlackAndWhite() throws {
        let p = rgb(try #require(render(solid(.red), .gradientMap([]))), 5, 5)
        #expect(abs(p[0] - p[1]) <= 2 && p[0] > 40)
    }

    @Test func transparentStaysTransparent() throws {
        #expect(rightHalfClear(try #require(render(halfClear, .gradientMap(ramp)))))
    }
}

@MainActor
@Suite struct GrainTests {
    @Test func zeroLeavesTheContentAlone() throws {
        let plain = try #require(render(solid(gray(0.5)), nil))
        #expect(try #require(render(solid(gray(0.5)), .grain(0))).bytes == plain.bytes)
    }

    @Test func itVariesAroundTheOriginalTone() throws {
        let p = try #require(render(solid(gray(0.5)), .grain(0.6)))
        let values = (0..<40).map { rgb(p, $0, 10)[0] }
        #expect(Set(values).count > 5)
        let mean = Double(values.reduce(0, +)) / Double(values.count)
        #expect(abs(mean - 128) < 12)
    }

    @Test func itRunsUnlessReduceMotionOrStill() throws {
        let a = try #require(render(solid(gray(0.5)), .grain(0.5), XeerpeContext(time: 1)))
        let b = try #require(render(solid(gray(0.5)), .grain(0.5), XeerpeContext(time: 1.5)))
        #expect(a.bytes != b.bytes)
        let c = try #require(render(solid(gray(0.5)), .grain(0.5), XeerpeContext(time: 1, reduceMotion: true)))
        let d = try #require(render(solid(gray(0.5)), .grain(0.5), XeerpeContext(time: 1.5, reduceMotion: true)))
        #expect(c.bytes == d.bytes)
        #expect(!XeerpeEffect.grain(0.5, animated: false).inputs.contains(.time))
        #expect(XeerpeEffect.grain(0.5).inputs.contains(.time))
    }
}

@MainActor
@Suite struct HalationTests {
    /// A white square in the middle of black, drawn as one layer: offscreen
    /// renders give wrong samples across sibling views.
    private var light: some View {
        Canvas { c, _ in
            c.fill(Path(CGRect(x: 0, y: 0, width: 60, height: 60)), with: .color(.black))
            c.fill(Path(CGRect(x: 25, y: 25, width: 10, height: 10)), with: .color(.white))
        }
        .frame(width: 60, height: 60)
    }

    @Test func brightPartsBleedTheTintNearbyOnly() throws {
        let plain = try #require(render(light, nil))
        let p = try #require(render(light, .halation(radius: 10, intensity: 1)))
        let near = rgb(p, 38, 30)
        #expect(near[0] > near[1] + 10 && near[0] > near[2] + 10)
        #expect(pixel(p, 3, 3) == pixel(plain, 3, 3))
    }

    @Test func zeroIntensityLeavesTheContentAlone() throws {
        let plain = try #require(render(light, nil))
        #expect(try #require(render(light, .halation(intensity: 0))).bytes == plain.bytes)
    }

    /// A mid-grey square glows only when the threshold is below its
    /// brightness.
    @Test func onlyPartsAboveTheThresholdGlow() throws {
        let grey = Canvas { c, _ in
            c.fill(Path(CGRect(x: 0, y: 0, width: 60, height: 60)), with: .color(.black))
            c.fill(Path(CGRect(x: 25, y: 25, width: 10, height: 10)), with: .color(gray(0.5)))
        }
        .frame(width: 60, height: 60)
        let plain = try #require(render(grey, nil))
        let high = try #require(render(grey, .halation(radius: 10, threshold: 0.75, intensity: 1)))
        let low = try #require(render(grey, .halation(radius: 10, threshold: 0.1, intensity: 1)))
        #expect(pixel(high, 38, 30) == pixel(plain, 38, 30))
        #expect(rgb(low, 38, 30)[0] > rgb(plain, 38, 30)[0] + 10)
    }
}

@MainActor
@Suite struct LightLeakTests {
    @Test func theEdgesGlowMoreThanTheMiddle() throws {
        let plain = rgb(try #require(render(solid(gray(0.3), 120, 60), nil)), 60, 30)[0]
        let p = try #require(render(solid(gray(0.3), 120, 60), .lightLeak(intensity: 1), XeerpeContext(time: 0)))
        let edge = rgb(p, 1, 18), middle = rgb(p, 60, 30)
        #expect(edge[0] > middle[0] + 30)
        #expect(abs(middle[0] - plain) < 30)
        #expect(edge[0] > edge[2])
    }

    @Test func itHoldsStillUnderReduceMotion() throws {
        let a = try #require(render(solid(gray(0.3), 120, 60), .lightLeak(), XeerpeContext(time: 1, reduceMotion: true)))
        let b = try #require(render(solid(gray(0.3), 120, 60), .lightLeak(), XeerpeContext(time: 9, reduceMotion: true)))
        #expect(a.bytes == b.bytes)
        let c = try #require(render(solid(gray(0.3), 120, 60), .lightLeak(), XeerpeContext(time: 9)))
        #expect(a.bytes != c.bytes)
    }

    @Test func transparentStaysTransparent() throws {
        #expect(rightHalfClear(try #require(render(halfClear, .lightLeak(intensity: 1)))))
    }
}

@MainActor
@Suite struct OneBitDitherTests {
    let ink = Color(red: 0.1, green: 0.1, blue: 0.2), paper = Color(red: 0.9, green: 0.9, blue: 0.8)

    private func colors(_ v: Double) throws -> Set<[UInt8]> {
        let p = try #require(render(solid(gray(v), 16, 16), .dither([ink, paper], tones: 2)))
        return Set((0..<16).flatMap { y in (0..<16).map { x in pixel(p, x, y) } })
    }

    @Test func twoTonesUseOnlyInkAndPaper() throws {
        let black = try colors(0), white = try colors(1), mid = try colors(0.5)
        #expect(black.count == 1 && white.count == 1 && black != white)
        #expect(mid == black.union(white))
    }
}

@MainActor
@Suite struct AsciiTests {
    private func inked(_ c: Color) throws -> Int {
        let p = try #require(render(solid(c, 40, 40), .ascii(cell: 10, ink: .white, paper: .black)))
        return (0..<40).flatMap { y in (0..<40).map { x in pixel(p, x, y)[0] } }.filter { $0 > 128 }.count
    }

    @Test func brighterCellsTakeMoreInk() throws {
        let black = try inked(.black), mid = try inked(gray(0.5)), white = try inked(.white)
        #expect(black == 0)
        #expect(mid > 0 && white > mid)
        #expect(white < 40 * 40)
    }

    @Test func coloredUsesTheCellsColor() throws {
        let p = try #require(render(solid(Color(red: 1, green: 0, blue: 0), 40, 40), .ascii(cell: 10, colored: true)))
        let lit = (0..<40).flatMap { y in (0..<40).map { x in rgb(p, x, y) } }.filter { $0[0] > 128 }
        #expect(!lit.isEmpty && lit.allSatisfy { $0[1] < 60 && $0[2] < 60 })
    }

    @Test func transparentStaysTransparent() throws {
        // Cells of 7 put the edge at 30 inside a cell (28...35): that cell is
        // drawn at partial alpha, every cell past it stays clear.
        let p = try #require(render(halfClear, .ascii(cell: 7)))
        #expect(pixel(p, 31, 10)[3] > 0 && pixel(p, 31, 10)[3] < 255)
        #expect((0..<40).allSatisfy { y in (35..<60).allSatisfy { x in pixel(p, x, y)[3] == 0 } })
    }
}

@Suite struct FlickerTests {
    /// Dips are 0...1, happen, and never start more than twice in a second.
    @Test func dipsAreBoundedAndRare() {
        let step = 0.005
        var starts: [Double] = []
        var was = false
        for i in 0..<Int(200 / step) {
            let t = Double(i) * step
            let d = Xeerpe.flickerDip(at: t)
            #expect(d >= 0 && d <= 1)
            if d > 0 && !was { starts.append(t) }
            was = d > 0
        }
        #expect(starts.count > 30)
        for (i, s) in starts.enumerated() {
            #expect(starts[i...].prefix { $0 < s + 1 }.count <= 2)
        }
    }

    @Test func nonFiniteTimeIsSteady() {
        #expect(Xeerpe.flickerDip(at: .nan) == 0)
        #expect(Xeerpe.flickerDip(at: -.infinity) == 0)
    }

    @MainActor
    @Test func reduceMotionKeepsItSteady() throws {
        let t = stride(from: 0.0, to: 60, by: 0.01).first { Xeerpe.flickerDip(at: $0) > 0.5 } ?? 0
        let plain = try #require(render(solid(.white), nil))
        let dipped = try #require(render(solid(.white), .flicker(1), XeerpeContext(time: t)))
        #expect(dipped.bytes != plain.bytes)
        let still = try #require(render(solid(.white), .flicker(1), XeerpeContext(time: t, reduceMotion: true)))
        #expect(still.bytes == plain.bytes)
    }
}

@MainActor
@Suite struct CardFinishTests {
    @Test func holoAtZeroLeavesTheContentAlone() throws {
        let plain = try #require(render(solid(gray(0.4)), nil))
        #expect(try #require(render(solid(gray(0.4)), .holo(intensity: 0))).bytes == plain.bytes)
        #expect(try #require(render(solid(gray(0.4)), .holo())).bytes != plain.bytes)
    }

    /// Chrome replaces the color but keeps the shape; its sky is lighter than
    /// the dark band at the horizon.
    @Test func chromeKeepsTheShapeAndMirrorsAHorizon() throws {
        let p = try #require(render(Color.black.frame(width: 20, height: 100).padding(.trailing, 20), .chrome(.constant(.zero))))
        #expect(pixel(p, 30, 50)[3] == 0)
        let top = rgb(p, 10, 5), horizon = rgb(p, 10, 56)
        #expect(top[0] > horizon[0] + 100)
        #expect(horizon[0] < 60 && horizon[2] < 60)
    }

    @Test func spotlightFollowsPresence() throws {
        var off = XeerpeContext(); off.focus = CGPoint(x: -0.5, y: 0)
        var on = off; on.presence = 1
        let box = solid(gray(0.2), 120, 60)
        let plain = try #require(render(box, nil))
        #expect(try #require(render(box, .spotlight(), off)).bytes == plain.bytes)
        let lit = try #require(render(box, .spotlight(), on))
        #expect(rgb(lit, 30, 30)[0] > rgb(lit, 110, 30)[0] + 5)
    }

    @Test func borderBeamMovesUnlessReduceMotion() throws {
        let box = solid(.black, 120, 60)
        let a = try #require(render(box, .borderBeam(), XeerpeContext(time: 0.5)))
        let b = try #require(render(box, .borderBeam(), XeerpeContext(time: 1.5)))
        #expect(maxDiff(a, b) > 60)
        let c = try #require(render(box, .borderBeam(), XeerpeContext(time: 0.5, reduceMotion: true)))
        let d = try #require(render(box, .borderBeam(), XeerpeContext(time: 1.5, reduceMotion: true)))
        #expect(maxDiff(c, d) <= 4)
        // Only the border is lit: the middle stays black.
        #expect(rgb(a, 60, 30)[0] < 5)
    }
}

@MainActor
@Suite struct IdleFrameTests {
    /// A moving film effect that a constant switches off asks for no frames.
    @Test func switchedOffFilmEffectsScheduleNoFrames() {
        #expect(XeerpeEffect.grain(0).inputs.isEmpty)
        #expect(XeerpeEffect.lightLeak(intensity: 0).inputs.isEmpty)
        #expect(XeerpeEffect.grain(0.3).inputs.contains(.time))
        #expect(XeerpeEffect.lightLeak(intensity: 0.3).inputs.contains(.time))
        #expect(XeerpeEffect.grain(.hover(from: 0, to: 0.5)).inputs.isSuperset(of: [.time, .hover]))
    }
}

@MainActor
@Suite struct LookPresetTests {
    var all: [(String, XeerpeChain)] {
        [("cinematic", .cinematic()), ("polaroid", .polaroid()), ("film", .film()), ("noir", .noir()), ("duotone", .duotone()),
         ("holoCard", .holoCard()), ("chromeLogo", .chromeLogo())]
    }

    @Test func presetsAreFreeOfConflictsAndNeverEmpty() {
        for (name, s) in all {
            #expect(!s.effects.isEmpty, Comment(rawValue: name))
            #expect(s.conflicts.isEmpty, Comment(rawValue: name))
        }
    }

    @Test func onlyMovingPresetsScheduleFrames() {
        for (name, s) in all {
            let moving = ["polaroid", "film", "noir"].contains(name)
            #expect(s.inputs.contains(.time) == moving, Comment(rawValue: name))
        }
        #expect(XeerpeChain.film(leak: false).effects.count == XeerpeChain.film().effects.count - 1)
    }
}
