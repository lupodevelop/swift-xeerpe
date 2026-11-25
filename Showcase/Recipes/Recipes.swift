#if os(macOS)
import SwiftUI
import xeerpe

// Novelty looks for the Looks tab. They are written only with xeerpe's public
// API, so an app that wants one can copy it as it is.
extension XeerpeChain {
    /// 1-bit: only `ink` and `paper`, the tones between drawn as an ordered
    /// dither of `pixel`-point dots, like an early Mac or a monochrome
    /// handheld.
    static func oneBit(ink: Color = Color(red: 0.2, green: 0.2, blue: 0.24),
                       paper: Color = Color(red: 0.93, green: 0.92, blue: 0.86), pixel: Double = 2) -> XeerpeChain {
        XeerpeChain { .grade(contrast: 0.2).dither([ink, paper], pixel: pixel, tones: 2) }
    }

    /// A night vision scope: phosphor green, noisy, with scanlines, a soft
    /// glow and dark edges.
    static func nightVision() -> XeerpeChain {
        XeerpeChain {
            .gradientMap([.black, Color(red: 0.01, green: 0.1, blue: 0.03), Color(red: 0.06, green: 0.4, blue: 0.1),
                          Color(red: 0.35, green: 0.95, blue: 0.4), Color(red: 0.9, green: 1, blue: 0.85)])
            .grain(0.4)
            .scanlines(spacing: 2, intensity: 0.2)
            .vignette(0.75)
            .bloom(radius: 6, intensity: 0.4)
        }
    }

    /// A thermal camera: soft, with cold areas deep blue and hot ones
    /// through magenta and orange to white.
    static func thermal() -> XeerpeChain {
        XeerpeChain {
            .blur(1.5)
            .gradientMap([Color(red: 0.02, green: 0, blue: 0.12), Color(red: 0.25, green: 0, blue: 0.55), Color(red: 0.78, green: 0.05, blue: 0.5),
                          Color(red: 1, green: 0.35, blue: 0.05), Color(red: 1, green: 0.82, blue: 0.1), Color(red: 1, green: 1, blue: 0.85)])
        }
    }

    /// A text terminal: the content as characters in `ink` on a dark screen,
    /// with a glow, scanlines and dark corners.
    static func terminal(cell: Double = 8, ink: Color = Color(red: 0.35, green: 1, blue: 0.5)) -> XeerpeChain {
        XeerpeChain {
            .ascii(cell: cell, ink: ink, paper: Color(red: 0.01, green: 0.04, blue: 0.02))
            .scanlines(spacing: 2, intensity: 0.2)
            .vignette(0.4)
            .bloom(radius: 6, intensity: 0.5)
        }
    }

    /// A neon tube: the content (bright text or an outline works best)
    /// glowing in `color` in three widths, flickering now and then when
    /// `flicker` is above 0.
    static func neonSign(_ color: Color = Color(red: 1, green: 0.25, blue: 0.6), flicker: Double = 0.6) -> XeerpeChain {
        let glow = XeerpeEffect(name: "neonGlow", slot: .content, claims: [.shadow]) { view, _ in
            AnyView(view.shadow(color: color, radius: 2).shadow(color: color, radius: 8).shadow(color: color.opacity(0.7), radius: 22))
        }
        return XeerpeChain {
            if flicker > 0 { .flicker(flicker) }
            .then(glow)
        }
    }
}
#endif
