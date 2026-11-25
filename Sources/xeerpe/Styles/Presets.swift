import SwiftUI

/// Presets are named compositions written only with the public API. All of
/// them keep a Reduce Motion behavior: liquid presets freeze, the lens and
/// the ripple stay inactive, the CRT stops flickering.
extension XeerpeChain {
    /// A CRT screen: scanlines and an RGB phosphor mask on curved glass,
    /// dark corners and a soft glow. `roll` > 0 sends a faint refresh bar
    /// down the screen, which stops under Reduce Motion. Edit it like any
    /// chain, for example `.crt().without(.vignette)`.
    public static func crt(curvature: some XeerpeValueConvertible = 0.12, roll: Double = 0) -> XeerpeChain {
        XeerpeChain { .scanlines(roll: roll).phosphor().barrel(curvature).vignette(0.45).bloom(radius: 8, intensity: 0.35) }
    }

    /// Anime cel shading: vivid colors in three flat bands, a thin dark
    /// outline and light ink on the shade edges.
    public static func anime(outline: Color = Color(red: 0.16, green: 0.1, blue: 0.14)) -> XeerpeChain {
        XeerpeChain { .toon(levels: 3, outline: outline, width: 2.5, ink: 0.3, vivid: 0.4) }
    }

    /// Manga: black and white, shade as screentone dots `size` points apart,
    /// a bold outline and ink lines.
    public static func manga(size: Double = 4) -> XeerpeChain {
        XeerpeChain { .toon(levels: 3, width: 3.5, ink: 0.15).halftone(size: size) }
    }

    /// Comic print: punchy colors in bands, a heavy outline, and the colors
    /// printed as cyan, magenta, yellow and black dots `size` points apart.
    public static func comic(size: Double = 4) -> XeerpeChain {
        XeerpeChain { .toon(levels: 4, width: 4, ink: 0.18, vivid: 0.5).halftone(size: size, colored: true) }
    }

    /// Video game cel shading: two hard bands of light, a thick outline and
    /// heavy ink, so every shape reads from far away.
    public static func celShaded() -> XeerpeChain {
        XeerpeChain { .toon(levels: 2, width: 5, ink: 0.12, vivid: 0.25) }
    }

    /// A VHS tape: color smeared sideways, rows that wobble with a noisy
    /// tracking band rolling down, fine scanlines and dark corners. The band
    /// stops under Reduce Motion.
    public static func vhs() -> XeerpeChain {
        XeerpeChain { .colorBleed(5).tracking().scanlines(spacing: 2, intensity: 0.25).vignette(0.35) }
    }

    /// A risograph zine: shade in flat bands, printed in two offset inks
    /// with grain.
    public static func risograph(_ inks: [Color] = [Color(red: 1, green: 0.28, blue: 0.55), Color(red: 0.1, green: 0.35, blue: 0.9)]) -> XeerpeChain {
        XeerpeChain { .toon(levels: 3, width: 0, ink: 0).riso(inks) }
    }

    /// A metal card: `metal` reacting to the tilt, brushed, with polished
    /// edges, all behind the content so it stays readable, turning in 3D.
    public static func metalCard(_ metal: XeerpePreset = .titanium,
                                 in shape: some Shape = RoundedRectangle(cornerRadius: 22, style: .continuous)) -> XeerpeChain {
        let clip = AnyShape(shape)
        return XeerpeChain {
            .backdrop { .preset(metal, reacting: .tilt, in: clip).brushed().bevel() }
            .tilt3D(.tilt, angle: 10)
        }
    }

    /// A jewel: a gem preset with mother-of-pearl sheen, glints that flash
    /// as it turns, and polished edges.
    public static func jewel(_ gem: XeerpePreset = .sapphire, in shape: some Shape = RoundedRectangle(cornerRadius: 22, style: .continuous)) -> XeerpeChain {
        let clip = AnyShape(shape)
        return XeerpeChain { .backdrop { .preset(gem, reacting: .tilt, in: clip).pearl(intensity: 0.35).sparkle().bevel(width: 4) } }
    }

    /// A Game Boy screen: blocks of `pixel` points in four dithered greens.
    public static func gameBoy(pixel: Double = 3) -> XeerpeChain {
        XeerpeChain { .pixelate(pixel).dither(.gameBoy, pixel: pixel) }
    }

    /// Slow green-violet flow. The pointer pulls the flow toward itself.
    /// `speed` is a multiplier (1 = default, 0 = still). Runs a shader over
    /// the whole shape: avoid very large areas on watchOS.
    public static func aurora(speed: some XeerpeValueConvertible = 1, in shape: some Shape = Rectangle()) -> XeerpeChain {
        XeerpeChain { .liquid(.aurora, speed: speed, in: shape) }
    }

    /// Hot, turbulent flow that shakes when tapped. `amplitude` is the wave
    /// height of the tap ripple in points (0...30 reads well).
    public static func lava(amplitude: some XeerpeValueConvertible = 14, in shape: some Shape = Rectangle()) -> XeerpeChain {
        XeerpeChain { .liquid(.lava, speed: 1.6, warp: 2.4, in: shape).ripple(amplitude: amplitude) }
    }

    /// Calm water: tap and a wave spreads through the surface and the content.
    public static func pond(in shape: some Shape = Rectangle()) -> XeerpeChain {
        XeerpeChain { .liquid(.ocean, speed: 0.7, in: shape).ripple() }
    }

    /// Orchid flow with a glass lens under the pointer. `radius` is in points.
    public static func magnifier(radius: some XeerpeValueConvertible = 90, in shape: some Shape = Rectangle()) -> XeerpeChain {
        XeerpeChain { .liquid(.orchid, speed: 0.8, in: shape).lens(radius: radius, strength: 0.6) }
    }

    /// Native Liquid Glass capsule that sinks slightly when pressed. Falls
    /// back to a material before the 26 systems.
    public static func glassPill(tint: Color? = nil) -> XeerpeChain {
        XeerpeChain { .glass(.regular, tint: tint, interactive: true, in: Capsule()).scale(.press(from: 1, to: 0.95)) }
    }
}

/// Photographic looks. Grain and the light leak hold still under Reduce
/// Motion.
extension XeerpeChain {
    /// Blockbuster color: teal shadows, warm highlights, a touch more
    /// contrast and dark corners.
    public static func cinematic() -> XeerpeChain {
        XeerpeChain {
            .grade(contrast: 0.2,
                   shadows: Color(red: 0, green: 0.5, blue: 0.6).opacity(0.6),
                   highlights: Color(red: 1, green: 0.6, blue: 0.28).opacity(0.45))
            .vignette(0.35)
        }
    }

    /// An instant photo: warm, washed out, soft contrast and fine grain.
    public static func polaroid() -> XeerpeChain {
        XeerpeChain {
            .grade(contrast: -0.1, saturation: -0.15, warmth: 0.3, fade: 0.45,
                   shadows: Color(red: 0.2, green: 0.35, blue: 0.55).opacity(0.35),
                   highlights: Color(red: 1, green: 0.9, blue: 0.6).opacity(0.3))
            .grain(0.16)
            .vignette(0.25)
        }
    }

    /// A film still: a warm, slightly faded grade, red halation around the
    /// lights, a light leak when `leak`, grain and dark corners.
    public static func film(leak: Bool = true) -> XeerpeChain {
        XeerpeChain {
            .grade(contrast: 0.1, warmth: 0.12, fade: 0.2).halation()
            if leak { .lightLeak(intensity: 0.6) }
            .grain(0.22).vignette(0.3)
        }
    }

    /// Black and white with hard contrast, heavy grain and deep corners.
    public static func noir() -> XeerpeChain {
        XeerpeChain { .grade(contrast: 0.45, saturation: -1).grain(0.28).vignette(0.55) }
    }

    /// Two inks: the shadows in `dark`, the lights in `light`.
    public static func duotone(_ dark: Color = Color(red: 0.12, green: 0.08, blue: 0.4),
                               _ light: Color = Color(red: 1, green: 0.45, blue: 0.55)) -> XeerpeChain {
        XeerpeChain { .gradientMap([dark, light]) }
    }
}

/// Cards and lettering.
extension XeerpeChain {
    /// A trading-card holo: `base` reacting to the tilt, rainbow foil that
    /// slides as it turns, glints and polished edges, all behind the content
    /// so it stays readable, turning in 3D.
    public static func holoCard(_ base: XeerpePreset = .gunmetal,
                                in shape: some Shape = RoundedRectangle(cornerRadius: 22, style: .continuous)) -> XeerpeChain {
        let clip = AnyShape(shape)
        return XeerpeChain {
            .backdrop { .preset(base, reacting: .tilt, in: clip).holo().sparkle(density: 0.35).bevel() }
            .tilt3D(.tilt, angle: 10)
        }
    }

    /// Chrome lettering: the content mirrors a horizon that rolls with the
    /// tilt, with polished edges and a few glints. For bold text or a logo.
    public static func chromeLogo() -> XeerpeChain {
        XeerpeChain { .chrome().bevel(width: 3, intensity: 0.7).sparkle(density: 0.3, size: 8) }
    }
}

/// Reveal presets. Pass `progress` as a literal, `.binding($p)`, or any
/// signal; animate the binding with `withAnimation` for a smooth reveal.
extension XeerpeChain {
    /// Liquid edge spreading from `from`, lit by `glow`.
    public static func fluidReveal(progress: some XeerpeValueConvertible, from: UnitPoint = .center, glow: Color = .cyan) -> XeerpeChain {
        XeerpeChain { .reveal(.fluid(from: from), progress: progress, glow: glow) }
    }

    /// Clean circular reveal.
    public static func irisReveal(progress: some XeerpeValueConvertible, from: UnitPoint = .center, glow: Color = .white) -> XeerpeChain {
        XeerpeChain { .reveal(.iris(from: from), progress: progress, glow: glow) }
    }

    /// Straight sweep; `angle` in degrees, 0 is left to right.
    public static func wipeReveal(progress: some XeerpeValueConvertible, angle: Double = 0, glow: Color = .white) -> XeerpeChain {
        XeerpeChain { .reveal(.wipe(angle: angle), progress: progress, glow: glow) }
    }
}
