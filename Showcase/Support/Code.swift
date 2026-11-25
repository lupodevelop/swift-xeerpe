#if os(macOS)
import SwiftUI

/// A code sample with xeerpe's API in color and everything else dimmed, so
/// it is clear which part is the library and which is plain SwiftUI.
struct CodeView: View {
    let source: String
    init(_ source: String) { self.source = source }

    static let api: Set<String> = [
        "xeerpe", "xeerpeFill", "xeerpeStream", "preset", "mapped", "max", "min", "then", "adding", "replacing", "emboss",
        "starfield", "viewAngle", "blurSweep", "aura", "phases", "dotField", "duo", "scratch", "spoiler", "feedback",
        "privacy", "loading", "reveal", "liquid", "lens", "ripple", "glow", "edgeGlow", "bloom", "beat", "tilt3D", "glare",
        "card", "scale", "shimmer", "breathe", "focusReveal", "hoverReveal", "inkReveal", "torch", "reactive", "style",
        "phaseTime", "progress", "entered", "steps", "result", "remap", "binding", "inactive", "hover", "press", "combine",
        "run", "cancel", "surface", "fluid", "iris", "wipe", "aurora", "pond", "magnifier", "glassPill", "lava", "tilt",
        "touch", "drag", "presence", "opacity", "blur", "without", "phase", "fluidReveal", "irisReveal", "wipeReveal",
        "map", "pixelate", "glitch", "matrix", "burn", "embers", "scanlines", "phosphor", "barrel",
        "vignette", "crt", "dither", "gameBoy", "toon", "halftone", "anime", "manga", "comic", "celShaded", "tilt3D", "gooey", "xeerpeTextRise", "smoke", "sparks", "genie", "xeerpeGenie", "colorBleed", "tracking", "vhs", "riso", "risograph", "bevel", "brushed", "foil", "sparkle", "guilloche",
        "pearl", "metalCard", "jewel", "gradient", "pulse", "glare", "glass", "dotField", "duo",
        "scan", "grain", "transferSource", "transferTarget", "transfer", "holo", "superellipse", "dust", "crossing", "time",
    ]

    var body: some View {
        // Lines never wrap: long ones scroll sideways, so the code keeps its shape.
        ScrollView(.horizontal, showsIndicators: false) {
            Text(highlighted).font(.system(size: 11, design: .monospaced)).lineSpacing(2)
                .textSelection(.enabled)
                .fixedSize()
                .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06)))
    }

    private var highlighted: AttributedString {
        var out = AttributedString(source)
        out.foregroundColor = .white.opacity(0.5)
        func paint(_ pattern: Regex<Substring>, _ color: Color, when: (Substring) -> Bool = { _ in true }) {
            for m in source.matches(of: pattern) where when(source[m.range]) {
                if let r = Range(m.range, in: out) { out[r].foregroundColor = color }
            }
        }
        let ident = /[A-Za-z_][A-Za-z0-9_]*/
        paint(ident, Color(red: 0.45, green: 0.85, blue: 1)) { Self.api.contains(String($0)) }
        paint(/Xeerpe[A-Za-z]*/, Color(red: 0.75, green: 0.6, blue: 1))
        paint(/"[^"\n]*"/, Color(red: 1, green: 0.7, blue: 0.45))
        paint(/\/\/[^\n]*/, .white.opacity(0.3))
        return out
    }
}
#endif
