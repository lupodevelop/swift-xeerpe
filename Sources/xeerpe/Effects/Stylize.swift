import SwiftUI

extension XeerpeEffect {
    /// Maps the content's brightness onto the first `tones` colors of
    /// `palette` (2...4), darkest first, with a 4x4 ordered dither between
    /// them. Two tones is 1-bit: `.dither([.black, .white], tones: 2)`. Each
    /// dither cell is `pixel` points; give it the same size as a `pixelate`
    /// before it and the two grids line up. Not drawn on watchOS.
    public static func dither(_ palette: XeerpePalette = .gameBoy, pixel: Double = 1, tones: Int = 4) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("dither", claims: [.dither])
        #else
        let c = palette.colors, p = pixel.isFinite ? max(pixel, 1) : 1, n = Float(min(max(tones, 2), 4))
        return .shader("dither", claims: [.dither]) { _ in
            .color(XeerpeShaders.library.xeerpeDither(.boundingRect, .float(p), .float(n), .color(c[0]), .color(c[1]), .color(c[2]), .color(c[3])))
        }
        #endif
    }

    /// A cartoon look: colors pushed `vivid` (0 keeps them, 1 doubles the
    /// saturation); brightness in `levels` flat bands, the darkest at
    /// 1/`levels` so shadows keep their color (fewer than 2 keeps the
    /// shading); an `outline` `width` points thick around the content's
    /// shape; and ink lines in `outline` inside where brightness jumps by
    /// more than `ink` (0 turns them off). Not drawn on watchOS.
    public static func toon(levels: Int = 4, outline: Color = .black, width: Double = 3, ink: Double = 0.2, vivid: Double = 0) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("toon", claims: [.toon])
        #else
        let w = width.isFinite ? max(width, 0) : 0
        let i = ink.isFinite ? max(ink, 0) : 0, v = vivid.isFinite ? max(vivid, 0) : 0
        return .shader("toon", claims: [.toon]) { _ in
            .layer(XeerpeShaders.library.xeerpeToon(.boundingRect, .float(Float(levels)), .color(outline), .float(w), .float(i), .float(v)),
                   maxSampleOffset: CGSize(width: w + 2, height: w + 2))
        }
        #endif
    }

    /// A printed screen of dots `size` points apart. Mono, the default, is
    /// manga screentone: `ink` dots on `paper`, bigger where the content is
    /// darker, on a grid turned `angle` degrees. Colored is a comic print:
    /// cyan, magenta, yellow and black dots, each on its own turned grid,
    /// never covering the paper fully, so even solid colors read as dots.
    /// Not drawn on watchOS.
    public static func halftone(size: Double = 5, angle: Double = 45, ink: Color = .black, paper: Color = .white, colored: Bool = false) -> XeerpeEffect {
        #if os(watchOS)
        .passthrough("halftone", claims: [.halftone])
        #else
        let s = size.isFinite ? max(size, 2) : 5, a = (angle.isFinite ? angle : 45) * .pi / 180
        return .shader("halftone", claims: [.halftone]) { _ in
            .color(XeerpeShaders.library.xeerpeHalftone(.float(s), .float(a), .color(ink), .color(paper), .float(colored ? 1 : 0)))
        }
        #endif
    }
}
