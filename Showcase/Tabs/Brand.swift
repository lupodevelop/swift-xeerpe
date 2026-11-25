#if os(macOS)
import SwiftUI
import AppKit
import xeerpe

// Brand pieces: an app icon, logos, signs and luxury finishes.

/// A small SVG drawn by AppKit; on iOS put the SVG in an asset catalog and use `Image("name")`.
private let logoSVG = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">
<path d="M14 10h26l20 30 20-30h26L73 60l33 50H80L60 80 40 110H14l33-50z"/>
<circle cx="60" cy="60" r="9"/>
</svg>
"""

@MainActor
struct Glyphs: View {
    private let symbols: [(String, String)] = [
        ("flame.fill", "lava"), ("bolt.fill", "electric"), ("heart.fill", "ruby"), ("star.fill", "gold"),
        ("moon.stars.fill", "galaxy"), ("leaf.fill", "jungle"), ("drop.fill", "ocean"), ("crown.fill", "black-gold"),
        ("sparkles", "holographic"), ("snowflake", "glacier"), ("sun.max.fill", "sunset"), ("gamecontroller.fill", "synthwave"),
    ]
    private let logo: NSImage? = NSImage(data: Data(logoSVG.utf8))

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Symbols, SVG and text", "Any shape can be filled with a preset. Move the pointer: each fill reacts, and each symbol ticks as you enter it.")
            HStack(alignment: .top, spacing: 24) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(64), spacing: 12), count: 6), spacing: 12) {
                    ForEach(symbols, id: \.0) { s in
                        Image(systemName: s.0).font(.system(size: 38))
                            .xeerpeFill(XeerpeCatalog[s.1]!.reactive(to: .tilt))
                            .frame(width: 64, height: 64)
                            .xeerpe { .scale(.hover(from: 1, to: 1.18)).feedback(.alignment, sound: .tick, on: .enter) }
                    }
                }
                .padding(18).background(card.fill(.white.opacity(0.05)))
                VStack(spacing: 10) {
                    if let logo {
                        Image(nsImage: logo).resizable().aspectRatio(contentMode: .fit).frame(width: 150, height: 150)
                            .xeerpeFill(.preset(.chrome, reacting: .tilt, strength: 1.5))
                            .xeerpe { .tilt3D(.tilt, angle: 22) }
                    }
                    Text("SVG").font(.caption).foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, minHeight: 200).background(card.fill(.white.opacity(0.05)))
            }
            Text("Liquid metal")
                .font(.system(size: 96, weight: .black, design: .rounded))
                .xeerpeFill(.preset(.liquidSilver, reacting: .tilt, strength: 1.4))
                .xeerpe { .tilt3D(.tilt, angle: 10).feedback(.impact, sound: .glass, on: .tap) }
                .frame(maxWidth: .infinity)
            CodeView("""
            Image(systemName: "flame.fill").xeerpeFill(.preset(.lava, reacting: .tilt))
                .xeerpe { .scale(.hover(from: 1, to: 1.18)).feedback(.alignment, sound: .tick, on: .enter) }
            Text("Liquid metal").xeerpeFill(.preset(.liquidSilver, reacting: .tilt))
                .xeerpe { .tilt3D().feedback(.impact, sound: .glass, on: .tap) }
            """)
        }
    }
}

@MainActor
struct SignsDemo: View {
    private func wall() -> LinearGradient {
        LinearGradient(colors: [Color(red: 0.08, green: 0.04, blue: 0.1), Color(red: 0.03, green: 0.02, blue: 0.05)], startPoint: .top, endPoint: .bottom)
    }

    private func tradingCard() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("VOLTARA").font(.system(.headline, design: .rounded).weight(.black))
                Spacer()
                Text("HP 120").font(.system(.caption, design: .rounded).weight(.heavy))
            }
            Spacer()
            Image(systemName: "bolt.horizontal.circle.fill").font(.system(size: 64)).frame(maxWidth: .infinity)
            Spacer()
            Text("Arc Surge · 90").font(.system(.callout, design: .rounded).weight(.semibold))
        }
        .foregroundStyle(.white).shadow(color: .black.opacity(0.5), radius: 2, y: 1)
        .padding(16).frame(width: 170, height: 240)
    }

    private func plan(_ name: String, _ price: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.system(.headline, design: .rounded)).foregroundStyle(.white.opacity(0.7))
            Text(price).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text("Unlimited looks, every preset, priority renders.").font(.caption).foregroundStyle(.white.opacity(0.55))
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading).frame(height: 170)
        .background(Color(red: 0.07, green: 0.07, blue: 0.1), in: tile)
    }

    /// The holo cards and the lit plans, shown with the payments.
    var cards = false

    var body: some View {
        if cards { cardsAndPlans } else { signs }
    }

    private var signs: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Signs", "Neon on a wall, chrome letters and a synthwave banner. neonSign and synthwave are showcase recipes written with the public API.")
            HStack(alignment: .top, spacing: 14) {
                step("Text(\"OPEN\").xeerpe(.neonSign())") {
                    Text("OPEN").font(.system(size: 54, weight: .medium, design: .rounded)).foregroundStyle(Color(red: 1, green: 0.86, blue: 0.93))
                        .xeerpe(.neonSign())
                        .frame(maxWidth: .infinity).frame(height: 170).background(wall(), in: tile)
                }
                step("Text(\"bar · 24h\").xeerpe(.neonSign(.cyan, flicker: 0))") {
                    Text("bar · 24h").font(.system(size: 44, weight: .light, design: .rounded)).foregroundStyle(Color(red: 0.85, green: 1, blue: 1))
                        .xeerpe(.neonSign(.cyan, flicker: 0))
                        .frame(maxWidth: .infinity).frame(height: 170).background(wall(), in: tile)
                }
                step("Text(\"XEERPE\").xeerpe(.chromeLogo())") {
                    Text("XEERPE").font(.system(size: 52, weight: .black)).italic()
                        .xeerpe(.chromeLogo())
                        .frame(maxWidth: .infinity).frame(height: 170).background(Color(red: 0.1, green: 0.1, blue: 0.16), in: tile)
                }
            }
            step("banner.xeerpe { .synthwave() }   title.xeerpe(.neonSign(.pink, flicker: 0))") {
                Text("NIGHT DRIVE").font(.system(size: 40, weight: .heavy, design: .rounded)).italic().foregroundStyle(Color(red: 1, green: 0.9, blue: 0.97))
                    .xeerpe(.neonSign(.pink, flicker: 0))
                    .offset(y: -30)
                    .frame(maxWidth: .infinity).frame(height: 230)
                    .xeerpe { .synthwave() }
                    .clipShape(tile)
            }
        }
    }

    private var cardsAndPlans: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Collectible cards and plans", "A holo trading card that turns with the pointer, and subscription plans with a lit border or a spotlight. Move the pointer over them.")
            HStack(alignment: .top, spacing: 14) {
                step("card.xeerpe(.holoCard())") { tradingCard().xeerpe(.holoCard()).frame(maxWidth: .infinity) }
                step("card.xeerpe(.holoCard(.gold))") { tradingCard().xeerpe(.holoCard(.gold)).frame(maxWidth: .infinity) }
                VStack(spacing: 14) {
                    step("plan.xeerpe { .borderBeam(in: tile) }") { plan("Pro", "€9").xeerpe { .borderBeam(in: tile) } }
                    step("plan.xeerpe { .spotlight(in: tile) }") { plan("Team", "€29").xeerpe { .spotlight(in: tile) } }
                }
            }
        }
    }
}

@MainActor
struct FoilDemo: View {
    private func invite(@ViewBuilder _ title: () -> some View) -> some View {
        VStack(spacing: 10) {
            Text("YOU ARE INVITED").font(.system(.caption, design: .serif).weight(.semibold)).tracking(3).foregroundStyle(.black.opacity(0.5))
            title()
            Text("Saturday 14 June · Villa Erba").font(.system(.callout, design: .serif)).foregroundStyle(.black.opacity(0.6))
        }
        .frame(maxWidth: .infinity).frame(height: 190)
        .background(card.fill(Color(red: 0.97, green: 0.94, blue: 0.88)))
    }

    private var title: some View { Text("Gala 2027").font(.system(size: 46, weight: .bold, design: .serif)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Hot foil", "Foil only where the ink is: the title turns to metal with fine crinkles and a sheen that moves with the light.")
            HStack(alignment: .top, spacing: 14) {
                step("title") { invite { title.foregroundStyle(.black) } }
                step("title.xeerpe { .foil() }") { invite { title.xeerpe { .foil() } } }
                step("title.xeerpe { .foil(roseGold, crinkle: 0.8)\n    .bevel(width: 1.5) }") {
                    invite { title.xeerpe { .foil(Color(red: 0.92, green: 0.62, blue: 0.55), crinkle: 0.8).bevel(width: 1.5) } }
                }
            }
        }
    }
}

@MainActor
struct DialDemo: View {
    private func dial() -> some View {
        Circle().fill(Color(red: 0.12, green: 0.2, blue: 0.38)).frame(width: 180, height: 180)
    }

    private func hands() -> some View {
        ZStack {
            Capsule().fill(.white).frame(width: 4, height: 60).offset(y: -30).rotationEffect(.degrees(300))
            Capsule().fill(.white).frame(width: 3, height: 78).offset(y: -39).rotationEffect(.degrees(50))
            Circle().fill(.white).frame(width: 10, height: 10)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Engraved dial", "Guilloché rings, then radial brushing that catches the light in two lobes, then a polished rim.")
            HStack(alignment: .top, spacing: 14) {
                step("dial.xeerpe { .guilloche() }") { dial().xeerpe { .guilloche() }.overlay { hands() }.frame(maxWidth: .infinity) }
                step("+ .brushed(radial: true)") {
                    dial().xeerpe { .guilloche(intensity: 0.4).brushed(radial: true) }.overlay { hands() }.frame(maxWidth: .infinity)
                }
                step("+ .bevel(width: 8)") {
                    dial().xeerpe { .guilloche(intensity: 0.4).brushed(radial: true).bevel(width: 8, intensity: 0.8) }
                        .overlay { hands() }.frame(maxWidth: .infinity)
                }
            }
        }
    }
}

@MainActor
struct JewelDemo: View {
    private let gem = RoundedRectangle(cornerRadius: 34, style: .continuous)

    private func stone() -> some View { Color.clear.frame(width: 150, height: 150) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Jewels", "A gem preset, glints that flash at their own angle as it turns, a pearl sheen, polished facets.")
            HStack(alignment: .top, spacing: 14) {
                step(".preset(.sapphire, reacting: .tilt, in: gem)") {
                    stone().xeerpe { .preset(.sapphire, reacting: .tilt, in: gem) }.frame(maxWidth: .infinity)
                }
                step("+ .sparkle()") { stone().xeerpe { .preset(.sapphire, reacting: .tilt, in: gem).sparkle() }.frame(maxWidth: .infinity) }
                step(".jewel(.emerald, in: gem)") { stone().xeerpe(.jewel(.emerald, in: gem)).frame(maxWidth: .infinity) }
                step("Circle().xeerpe { .pearl().bevel(width: 10) }") {
                    Circle().fill(Color(white: 0.93)).frame(width: 150, height: 150).xeerpe { .pearl().bevel(width: 10, intensity: 0.5) }
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

@MainActor
struct AppIconDemo: View {
    private func icon() -> some View {
        Image(systemName: "waveform").font(.system(size: 46, weight: .semibold)).foregroundStyle(.white).frame(width: 116, height: 116)
    }

    private func stage(_ view: some View) -> some View {
        view.frame(maxWidth: .infinity).frame(height: 170).background(Color(white: 0.08), in: tile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("App icon", "A squircle whose outline is a signal: it rounds into a circle under the pointer, glows, and sinks when pressed.")
            HStack(alignment: .top, spacing: 14) {
                step("icon.xeerpe {\n    .gradient(.aurora, in: .superellipse(4))\n}") {
                    stage(icon().xeerpe { .gradient(.aurora, in: .superellipse(4)) })
                }
                step("icon.xeerpe {\n    .gradient(.aurora, in: .superellipse(.hover(from: 4, to: 2)))\n}") {
                    stage(icon().xeerpe { .gradient(.aurora, in: .superellipse(.hover(from: 4, to: 2))) })
                }
                step("icon.xeerpe {\n    .gradient(.aurora, in: .superellipse(.hover(from: 4, to: 2)))\n    .glow(.purple, radius: .hover(from: 0, to: 18))\n    .scale(.press(from: 1, to: 0.92))\n}") {
                    stage(icon().xeerpe {
                        .gradient(.aurora, in: .superellipse(.hover(from: 4, to: 2)))
                        .glow(.purple, radius: .hover(from: 0, to: 18))
                        .scale(.press(from: 1, to: 0.92))
                    })
                }
            }
        }
    }
}
#endif
