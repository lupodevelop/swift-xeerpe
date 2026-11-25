import SwiftUI
import Testing
@testable import xeerpe

@MainActor
@Suite struct PresetTests {
    var all: [(String, XeerpeChain)] {
        [("aurora", .aurora()), ("lava", .lava()), ("pond", .pond()), ("magnifier", .magnifier()), ("glassPill", .glassPill())]
    }

    @Test func presetsDeclareExactlyTheInputsTheyNeed() {
        #expect(XeerpeChain.aurora().inputs == [.time, .pointer])
        #expect(XeerpeChain.lava().inputs == [.time, .pointer, .tap])
        #expect(XeerpeChain.pond().inputs == [.time, .pointer, .tap])
        #expect(XeerpeChain.magnifier().inputs == [.time, .pointer])
        #expect(XeerpeChain.glassPill().inputs == .press)
    }

    @Test func presetsAreFreeOfConflictsAndNeverEmpty() {
        for (name, s) in all {
            #expect(!s.effects.isEmpty, Comment(rawValue: name))
            #expect(s.conflicts.isEmpty, Comment(rawValue: name))
        }
    }

    @Test func presetsStayEditable() {
        let s = XeerpeChain.pond().adding { .blur(2) }
        #expect(s.effects.map(\.name) == ["liquid", "ripple", "blur"])
        #expect(s.without(.distortion).effects.map(\.name) == ["liquid", "blur"])
    }

    @Test func paletteArrayLiteralAlwaysYieldsFourColors() {
        for n in 1...7 {
            let p: XeerpePalette = XeerpePalette(Array(repeating: Color.red, count: n))
            #expect(p.colors.count == 4)
        }
        #expect(XeerpePalette([]).colors.count == 4)
    }
}

#if os(macOS)
@MainActor
@Suite struct ReduceMotionTests {
    func sample(time: Double, reduceMotion: Bool) -> [UInt8] {
        let chain = XeerpeChain.liquid()
        let view = chain.render(AnyView(Color.clear.frame(width: 80, height: 80)),
                                context: XeerpeContext(time: time, reduceMotion: reduceMotion))
        let r = ImageRenderer(content: view); r.scale = 1
        let img = r.cgImage!
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: -40, y: -39, width: img.width, height: img.height))
        return px
    }

    @Test func liquidMovesWithTimeButFreezesUnderReduceMotion() {
        #expect(sample(time: 3, reduceMotion: false) != sample(time: 40, reduceMotion: false))
        #expect(sample(time: 3, reduceMotion: true) == sample(time: 40, reduceMotion: true))
    }
}
#endif
