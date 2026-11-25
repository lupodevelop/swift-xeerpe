import SwiftUI
import Testing
@testable import xeerpe

@MainActor
@Suite struct LayerMathTests {
    @Test func starsAreDeterministicInRangeAndSeedDependent() {
        for _ in 0..<40 {
            let count = Int.random(in: 0...200), seed = Int.random(in: 0...10_000)
            let a = Xeerpe.starPoints(count: count, seed: seed)
            #expect(a.count == count)
            #expect(a == Xeerpe.starPoints(count: count, seed: seed))
            #expect(a.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        }
        #expect(Xeerpe.starPoints(count: 30, seed: 1) != Xeerpe.starPoints(count: 30, seed: 2))
    }

    @Test func stopsAreClampedAndSortedByPosition() {
        for _ in 0..<50 {
            let stops = (0..<Int.random(in: 1...8)).map { _ in XeerpeStop(UInt32.random(in: 0...UInt32.max), Double.random(in: -0.5...1.5)) }
            let n = Xeerpe.normalizedStops(stops)
            #expect(n.count == stops.count)
            #expect(n.map(\.at) == n.map(\.at).sorted())
            #expect(n.allSatisfy { (0...1).contains($0.at) })
        }
    }

    @Test func rgbaDecodesChannelsInOrder() {
        for _ in 0..<50 {
            let r = UInt32.random(in: 0...255), g = UInt32.random(in: 0...255), b = UInt32.random(in: 0...255), a = UInt32.random(in: 0...255)
            let c = Xeerpe.channels(rgba: r << 24 | g << 16 | b << 8 | a)
            #expect([c.r, c.g, c.b, c.a] == [Double(r) / 255, Double(g) / 255, Double(b) / 255, Double(a) / 255])
        }
    }

    @Test func cssAngleZeroPointsUpAndNinetyPointsRight() {
        let up = Xeerpe.cssAxis(degrees: 0), right = Xeerpe.cssAxis(degrees: 90)
        #expect(abs(up.start.y - 1) < 1e-9 && abs(up.end.y) < 1e-9)
        #expect(abs(right.start.x) < 1e-9 && abs(right.end.x - 1) < 1e-9)
    }

    @Test func layerKindsSplitIntoFillsAndOverlays() {
        #expect(XeerpeLayer.base(0).isFill && XeerpeLayer.stops([], css: 0).isFill)
        #expect(!XeerpeLayer.grain(1).isFill && !XeerpeLayer.vignette(color: 0, intensity: 0.5, spread: 0.3).isFill)
    }
}

@MainActor
@Suite struct CatalogTests {
    @Test func idsAreUniqueAndEveryCategoryHasPresets() {
        let ids = XeerpeCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        for c in XeerpeCategory.allCases { #expect(!XeerpeCatalog.presets(in: c).isEmpty, Comment(rawValue: c.rawValue)) }
    }

    @Test func everyPresetHasContentAndSaneParameters() {
        for p in XeerpeCatalog.all {
            let name = Comment(rawValue: p.id)
            #expect(p.category == .liquid || !p.layers.isEmpty, name)   // shader presets are style builders
            for layer in p.layers {
                switch layer {
                case .stops(let s, let css, let span):
                    #expect(!s.isEmpty && css.isFinite && span >= 1, name)
                case .blob(let x, let y, _, _, let f, let t, _, _):
                    #expect(x.isFinite && y.isFinite && f >= 0 && t >= f, name)
                case .vignette(_, let i, let s): #expect((0...1).contains(i) && (0...1).contains(s), name)
                case .grid(_, let size, _, let o), .dots(_, let size, _, let o): #expect(size > 0 && (0...1).contains(o), name)
                case .stars(_, let n, _, _, let o): #expect(n >= 0 && (0...1).contains(o), name)
                case .grain(let i): #expect(i >= 0, name)
                default: break
                }
            }
            for m in p.motion {
                switch m { case .breathe(let t), .aurora(let t), .drift(let t), .shimmer(let t): #expect(t > 0, name) }
            }
        }
    }

    @Test func presetStylesBuildWithoutConflicts() {
        for p in XeerpeCatalog.all { #expect(p.style().conflicts.isEmpty, Comment(rawValue: p.id)) }
    }

    @Test func motionDeclaresTimeInputAndStillPresetsDoNot() {
        for p in XeerpeCatalog.all {
            #expect(p.style().inputs.contains(.time) == !p.motion.isEmpty || p.category == .liquid, Comment(rawValue: p.id))
        }
    }

    @Test func lookupAndSearchFindPresetsByIdCategoryAndTag() {
        for p in XeerpeCatalog.all.prefix(40) {
            #expect(XeerpeCatalog[p.id]?.id == p.id)
            #expect(XeerpeCatalog.search(p.id).contains { $0.id == p.id })
        }
        #expect(XeerpeCatalog["definitely-not-a-preset"] == nil)
        #expect(XeerpeCatalog.search("").count == XeerpeCatalog.all.count)
    }
}

#if os(macOS)
@MainActor
func rgbaAt(_ view: some View, size: CGFloat = 100, x: Int, y: Int) -> [UInt8] {
    let r = ImageRenderer(content: view.frame(width: size, height: size)); r.scale = 1
    for _ in 0..<3 { _ = r.cgImage; RunLoop.current.run(until: Date().addingTimeInterval(0.03)) }
    let img = r.cgImage!
    var px = [UInt8](repeating: 0, count: 4)
    let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: -x, y: -(img.height - 1 - y), width: img.width, height: img.height))
    return px
}

@MainActor
@Suite struct SurfacePixelTests {
    func surface(_ layers: [XeerpeLayer], in shape: some Shape = Rectangle()) -> some View {
        Color.clear.xeerpe(XeerpeChain([.surface(layers, in: shape)]))
    }

    @Test func stopsRunFromFirstToLastColorAlongTheAngle() {
        let v = surface([.stops([XeerpeStop(0xff0000ff, 0), XeerpeStop(0x0000ffff, 1)], css: 90)])
        let l = rgbaAt(v, x: 2, y: 50), r = rgbaAt(v, x: 97, y: 50)
        #expect(l[0] > 230 && l[2] < 25)
        #expect(r[2] > 230 && r[0] < 25)
    }

    @Test func firstListedFillIsOnTop() {
        let v = surface([.base(0x00ff00ff), .base(0xff0000ff)])   // green listed first
        let p = rgbaAt(v, x: 50, y: 50)
        #expect(p[1] > 230 && p[0] < 25)
    }

    @Test func surfaceIsClippedToItsShape() {
        let v = surface([.base(0x336699ff), .grain(1), .vignette(color: 0x000000ff, intensity: 0.5, spread: 0.4)], in: Circle())
        #expect(rgbaAt(v, x: 2, y: 2)[3] == 0)
        #expect(rgbaAt(v, x: 50, y: 50)[3] > 250)
    }

    @Test func vignetteDarkensTheCornersAndLeavesTheCenter() {
        let v = surface([.base(0xffffffff), .vignette(color: 0x000000ff, intensity: 0.8, spread: 0.5)])
        let corner = rgbaAt(v, x: 2, y: 2), center = rgbaAt(v, x: 50, y: 50)
        #expect(Int(center[0]) - Int(corner[0]) > 60)
    }

    @Test func grainNeverChangesAlphaAndStaysNearTheBaseColor() {
        let v = surface([.base(0x808080ff), .grain(1.5)])
        for (x, y) in [(10, 10), (50, 50), (80, 30)] {
            let p = rgbaAt(v, x: x, y: y)
            #expect(p[3] == 255)
            #expect(abs(Int(p[0]) - 128) < 40)
        }
    }

    @Test func gridDrawsLinesAndLeavesTheCellsEmpty() {
        let v = surface([.grid(color: 0xffffffff, size: 20, line: 2, opacity: 1)])
        let onLine = (0..<20).map { rgbaAt(v, x: $0, y: 50)[3] }.max()!
        #expect(onLine > 200)
        #expect(rgbaAt(v, x: 10, y: 10)[3] == 0)
    }
}

@MainActor
@Suite struct TextFillTests {
    @Test func fillPaintsOnlyInsideTheContentsShape() {
        let glyph = Circle().frame(width: 80, height: 80)
        let v = glyph.xeerpeFill(XeerpeChain { .surface([.base(0xff0000ff)]) })
        #expect(rgbaAt(v, x: 50, y: 50)[0] > 230)
        #expect(rgbaAt(v, x: 3, y: 3)[3] == 0)
    }
}
#endif

@Suite struct GradientLineTests {
    /// Every corner must fall inside the gradient line, so no end color ever
    /// spreads as a flat panel, whatever the angle, the size, the span or how
    /// far a reaction slides it.
    @Test func cornersAlwaysProjectInsideTheGradient() {
        for _ in 0..<500 {
            let size = CGSize(width: .random(in: 20...600), height: .random(in: 20...600))
            let line = Xeerpe.cssLine(degrees: .random(in: -720...720), size: size,
                                      span: .random(in: 1...4), shift: .random(in: -1.5...1.5))
            let dx = line.end.x - line.start.x, dy = line.end.y - line.start.y
            let len2 = dx * dx + dy * dy
            for c in [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)] {
                let t = ((c.x - line.start.x) * dx + (c.y - line.start.y) * dy) / len2
                #expect(t >= -1e-9 && t <= 1 + 1e-9)
            }
        }
    }

    @Test func spanOneMatchesCSSCornerToCorner() {
        let line = Xeerpe.cssLine(degrees: 90, size: CGSize(width: 200, height: 100), span: 1, shift: 0)
        #expect(abs(line.start.x) < 1e-9 && abs(line.end.x - 200) < 1e-9 && abs(line.start.y - 50) < 1e-9)
    }
}
