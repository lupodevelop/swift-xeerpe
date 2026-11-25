#if os(macOS)
import SwiftUI
import xeerpe

// Games and comics: a scratch ticket, Game Boy, cartoon and comic looks,
// tape prints.

@MainActor
struct ScratchTicket: View {
    @State private var round = 0
    @State private var scratched = 0.0
    private let prizes = ["€ 5.000", "€ 50", "RITENTA", "€ 1.000.000", "€ 20"]

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(spacing: 14) {
                ZStack {
                    VStack(spacing: 6) {
                        Text("HAI VINTO").font(.system(.caption, design: .rounded).weight(.heavy)).tracking(4).foregroundStyle(.white.opacity(0.8))
                        Text(prizes[round % prizes.count]).font(.system(size: 52, weight: .black, design: .rounded))
                            .xeerpeFill(.preset(.gold, reacting: .tilt))
                        HStack { ForEach(0..<5) { _ in Image(systemName: "star.fill") } }
                            .font(.title3).xeerpeFill(.preset(.roseGold, reacting: .tilt))
                    }
                }
                .frame(width: 420, height: 220)
                .xeerpe {
                    .preset(.midnight, in: card)
                    .scratch(.preset(.silver, reacting: .touch, in: card), brush: 38, clearAt: 0.6) { scratched = $0 }
                    .feedback(.levelChange, sound: .tick, on: .steps(.binding($scratched), count: 8))
                }
                .id(round)
                HStack {
                    ProgressView(value: scratched).tint(.cyan)
                    Text("\(Int(scratched * 100))%").monospacedDigit().foregroundStyle(.white.opacity(0.7)).frame(width: 44)
                    Button("Nuovo biglietto") { scratched = 0; round += 1 }.buttonStyle(PillButtonStyle())
                }
                .frame(width: 420)
            }
            VStack(alignment: .leading, spacing: 12) {
                heading("Gratta e vinci", "Pass the pointer over the silver (on a phone, drag a finger). It ticks every 1/8 and clears itself at 60%. Nuovo biglietto draws another prize.")
                CodeView("""
                ticket.xeerpe {
                    .scratch(.preset(.silver, reacting: .touch),
                             brush: 38, clearAt: 0.6) { scratched = $0 }
                    .feedback(.levelChange, sound: .tick,
                              on: .steps(.binding($scratched), count: 8))
                }
                """)
            }
        }
    }
}

@MainActor
struct GameBoyDemo: View {
    private func card() -> some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.surfing").font(.system(size: 54))
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekend trip").font(.title3.bold())
                Text("Lisbon · 3 nights").font(.callout).opacity(0.85)
            }
            Spacer()
        }
        .foregroundStyle(.white).padding(18).frame(height: 130)
        .xeerpe(XeerpeCatalog["aurora-dream"]!.style(in: tile))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Game Boy", "Brightness mapped onto four colors with an ordered dither; with pixelate before it, the two grids line up.")
            HStack(alignment: .top, spacing: 14) {
                step("card.xeerpe { .dither(.gameBoy) }") { card().xeerpe { .dither(.gameBoy) } }
                step("card.xeerpe { .pixelate(3).dither(.gameBoy, pixel: 3) }") { card().xeerpe { .pixelate(3).dither(.gameBoy, pixel: 3) } }
            }
            HStack(alignment: .top, spacing: 14) {
                step("card.xeerpe(.gameBoy(pixel: 4))") { card().xeerpe(.gameBoy(pixel: 4)) }
                step("card.xeerpe { .dither([.black, .purple, .pink, .white], pixel: 2) }") {
                    card().xeerpe { .dither([.black, .purple, .pink, .white], pixel: 2) }
                }
            }
        }
    }
}

@MainActor
struct ToonDemo: View {
    private func sticker(_ symbol: String, _ colors: [Color]) -> some View {
        Image(systemName: symbol).font(.system(size: 70))
            .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .frame(maxWidth: .infinity).frame(height: 130)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Cartoon", "Flat bands of shade, a thick outline taken from the shape itself, ink where the shade jumps.")
            HStack(alignment: .top, spacing: 14) {
                step("icon.xeerpe { .toon(width: 0, ink: 0) }") {
                    sticker("flame.fill", [.yellow, .orange, .red]).xeerpe { .toon(width: 0, ink: 0) }
                }
                step("icon.xeerpe { .toon(ink: 0) }") {
                    sticker("flame.fill", [.yellow, .orange, .red]).xeerpe { .toon(ink: 0) }
                }
                step("icon.xeerpe { .toon() }") {
                    sticker("leaf.fill", [.mint, .green, Color(red: 0, green: 0.35, blue: 0.2)]).xeerpe { .toon() }
                }
                step("icon.xeerpe { .toon(levels: 3, outline: .white, width: 6) }") {
                    sticker("heart.fill", [.pink, .red]).xeerpe { .toon(levels: 3, outline: .white, width: 6) }
                }
            }
        }
    }
}

/// A game character card, rich enough in shade and color to show the styles.
@MainActor
private func hero() -> some View {
    HStack(spacing: 16) {
        Image(systemName: "figure.martial.arts").font(.system(size: 64))
            .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.4), Color(red: 0.95, green: 0.3, blue: 0.2)],
                                            startPoint: .top, endPoint: .bottom))
        VStack(alignment: .leading, spacing: 4) {
            Text("KAITO").font(.system(size: 26, weight: .black, design: .rounded))
            Text("Lv 42 · Storm fist").font(.callout.weight(.semibold)).opacity(0.85)
        }
        .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
        Spacer(minLength: 0)
    }
    .padding(18).frame(height: 130)
    .background(tile.fill(LinearGradient(colors: [Color(red: 0.2, green: 0.45, blue: 0.95), Color(red: 0.55, green: 0.2, blue: 0.7)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)))
}

@MainActor
struct ComicChains: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Anime, manga, comic", "One chain growing a step at a time, the presets it becomes, then presets chained with other effects and signals.")
            HStack(alignment: .top, spacing: 14) {
                step("card") { hero() }
                step("card.xeerpe { .toon(levels: 3, width: 0, ink: 0) }") { hero().xeerpe { .toon(levels: 3, width: 0, ink: 0) } }
                step("+ outline: .toon(levels: 3, width: 4, ink: 0)") { hero().xeerpe { .toon(levels: 3, width: 4, ink: 0) } }
            }
            HStack(alignment: .top, spacing: 14) {
                step("+ ink and color: .toon(levels: 3, width: 4, ink: 0.15, vivid: 0.5)") {
                    hero().xeerpe { .toon(levels: 3, width: 4, ink: 0.15, vivid: 0.5) }
                }
                step("+ .halftone(size: 4)") { hero().xeerpe { .toon(levels: 3, width: 4, ink: 0.15).halftone(size: 4) } }
                step("+ .halftone(size: 4, colored: true)") {
                    hero().xeerpe { .toon(levels: 4, width: 4, ink: 0.15, vivid: 0.5).halftone(size: 4, colored: true) }
                }
            }
            HStack(alignment: .top, spacing: 14) {
                step("card.xeerpe(.anime())") { hero().xeerpe(.anime()) }
                step("card.xeerpe(.manga())") { hero().xeerpe(.manga()) }
                step("card.xeerpe(.comic())") { hero().xeerpe(.comic()) }
                step("card.xeerpe(.celShaded())") { hero().xeerpe(.celShaded()) }
            }
            HStack(alignment: .top, spacing: 14) {
                step("card.xeerpe(.comic().without(.halftone))") { hero().xeerpe(.comic().without(.halftone)) }
                step("card.xeerpe { .celShaded().crt() }") { hero().xeerpe { .celShaded().crt() } }
                step("card.xeerpe(.manga()\n    .adding { .pixelate(.hover(from: 1, to: 5)) })") {
                    hero().xeerpe(.manga().adding { .pixelate(.hover(from: 1, to: 5)) })
                }
                step("card.xeerpe(.anime()\n    .adding { .tilt3D(.tilt, angle: 14).glare(.tilt) })") {
                    hero().xeerpe(.anime().adding { .tilt3D(.tilt, angle: 14).glare(.tilt) })
                }
            }
        }
    }
}

@MainActor
struct TapePrintDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("VHS and riso", "Two more presets built from small pieces: a tape with bleeding color and rolling tracking, and a two-ink print.")
            HStack(alignment: .top, spacing: 14) {
                step("card.xeerpe { .colorBleed(5) }") { hero().xeerpe { .colorBleed(5) } }
                step("+ .tracking()") { hero().xeerpe { .colorBleed(5).tracking() } }
                step("card.xeerpe(.vhs())") { hero().xeerpe(.vhs()) }
            }
            HStack(alignment: .top, spacing: 14) {
                step("card.xeerpe { .riso() }") { hero().xeerpe { .riso() } }
                step("card.xeerpe(.risograph())") { hero().xeerpe(.risograph()) }
                step("card.xeerpe(.risograph([.orange, .teal])\n    .adding { .tilt3D(.tilt) })") {
                    hero().xeerpe(.risograph([.orange, .teal]).adding { .tilt3D(.tilt) })
                }
            }
        }
    }
}
#endif
