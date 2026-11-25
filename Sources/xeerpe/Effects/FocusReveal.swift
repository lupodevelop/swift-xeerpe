import SwiftUI

extension XeerpeEffect {
    /// Interactive reveal: the content is blurred and dimmed, and turns clear
    /// in a circle under the pointer or finger. The circle follows with a
    /// little lag and grows and shrinks as the pointer enters and leaves.
    /// `radius` is in points (by default it grows to 130 with presence);
    /// `blur` and `softness` are in points, `darken` 0...1. `turbulence`
    /// 0...1 makes the edge wander like ink. Controls stay interactive.
    public static func focusReveal(
        radius: XeerpeValue = XeerpeValue.presence.remap(0...1, to: 0, 130),
        blur: Double = 22,
        darken: Double = 0.55,
        softness: Double = 36,
        turbulence: Double = 0
    ) -> XeerpeEffect {
        XeerpeEffect(name: "focusReveal", slot: .content, claims: [.reveal], inputs: radius.inputs.union(.touch)) { view, ctx in
            let r = Xeerpe.clampNonNegative(radius.value(in: ctx))
            let w = ctx.size.width, h = ctx.size.height
            let center = CGPoint(x: (ctx.focus.x + 1) / 2 * w, y: (ctx.focus.y + 1) / 2 * h)
            #if os(watchOS)
            // No shaders on watchOS: dim everything outside the circle.
            return AnyView(view.overlay(
                RadialGradient(colors: [.clear, .black.opacity(darken)], center: UnitPoint(x: (ctx.focus.x + 1) / 2, y: (ctx.focus.y + 1) / 2),
                               startRadius: max(r - softness, 0), endRadius: r + softness)
                    .allowsHitTesting(false)))
            #else
            return AnyView(view.layerEffect(
                XeerpeShaders.library.xeerpeFocus(
                    .boundingRect, .float2(center), .float(Float(r)), .float(Float(max(softness, 0))),
                    .float(Float(max(blur, 0))), .float(Float(Xeerpe.clampUnit(darken))), .float(Float(Xeerpe.clampUnit(turbulence)))),
                maxSampleOffset: CGSize(width: blur, height: blur)))
            #endif
        }
    }
}

/// Interactive reveal presets.
extension XeerpeChain {
    /// Blurred and dimmed; clear where the pointer or finger is.
    public static func hoverReveal(radius: Double = 130, blur: Double = 22) -> XeerpeChain {
        .focusReveal(radius: XeerpeValue.presence.remap(0...1, to: 0, radius), blur: blur)
    }

    /// Like `hoverReveal`, with an edge that wanders like ink in water.
    public static func inkReveal(radius: Double = 140, blur: Double = 26) -> XeerpeChain {
        .focusReveal(radius: XeerpeValue.presence.remap(0...1, to: 0, radius), blur: blur,
                      darken: 0.6, softness: 30, turbulence: 0.55)
    }

    /// Dark, not blurred: a light that follows the pointer or finger.
    public static func torch(radius: Double = 110) -> XeerpeChain {
        .focusReveal(radius: XeerpeValue.presence.remap(0...1, to: 0, radius), blur: 0,
                      darken: 0.88, softness: 60)
    }
}
