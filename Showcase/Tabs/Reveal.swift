#if os(macOS)
import SwiftUI
import xeerpe

// Reveals: content uncovered by the pointer, by a progress, or turned to dust.

@MainActor
struct DustDelete: View {
    @State private var shown = 1.0

    private func photo() -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color(red: 0.98, green: 0.6, blue: 0.35), Color(red: 0.55, green: 0.25, blue: 0.6), Color(red: 0.1, green: 0.12, blue: 0.3)],
                           startPoint: .top, endPoint: .bottom)
            Image(systemName: "mountain.2.fill").font(.system(size: 90)).foregroundStyle(Color(red: 0.08, green: 0.06, blue: 0.15))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            Text("IMG_2047").font(.system(.caption, design: .monospaced)).foregroundStyle(.white.opacity(0.8)).padding(10)
        }
        .frame(height: 180).clipShape(tile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Delete to dust", "A photo that crumbles when deleted and settles back on undo. The reveal follows the binding, so withAnimation sets its pace.")
            HStack(alignment: .top, spacing: 14) {
                step("photo.xeerpe { .reveal(.dust(), progress: .binding($shown)) }") {
                    photo().xeerpe { .reveal(.dust(), progress: .binding($shown)) }
                }
                step("photo.xeerpe {\n    .reveal(.dust(angle: 90, grain: 0.9), progress: .binding($shown), glow: .orange)\n}") {
                    photo().xeerpe { .reveal(.dust(angle: 90, grain: 0.9), progress: .binding($shown), glow: .orange) }
                }
            }
            Button(shown > 0.5 ? "Delete" : "Undo") { withAnimation(.easeInOut(duration: 1.4)) { shown = shown > 0.5 ? 0 : 1 } }
                .buttonStyle(PillButtonStyle())
        }
    }
}

/// A card with real content under an interactive reveal.
@MainActor
struct InteractiveCard: View {
    let title: String, code: String
    let look: XeerpeChain
    let wallpaper: String
    var reactiveWallpaper = false
    @State private var taps = 0

    var body: some View {
        let preset = XeerpeCatalog[wallpaper] ?? XeerpeCatalog.all[0]
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Now playing").font(.caption).opacity(0.8)
                Text("Midnight Tide").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("A long drive home, the city fading in the mirror.").font(.callout).opacity(0.85)
                Spacer()
                HStack {
                    ForEach(["backward.fill", "play.fill", "forward.fill"], id: \.self) { Image(systemName: $0).font(.title2) }
                    Spacer()
                    Button("Like · \(taps)") { taps += 1 }.buttonStyle(PillButtonStyle())
                }
            }
            .foregroundStyle(.white).padding(22).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .xeerpe(reactiveWallpaper ? preset.reactive(to: .touch, in: shape) : preset.style(in: shape))
            .xeerpe(look)
            .frame(height: 260)
            Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(.white)
            CodeView(code)
        }
    }
}

/// Real controls inside: while the reveal is hidden the button must not react.
@MainActor
struct MockCard: View {
    @State private var taps = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Now playing").font(.caption).opacity(0.75)
            Text("Midnight Tide").font(.system(.title, design: .rounded).bold())
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<9) { i in RoundedRectangle(cornerRadius: 3).frame(width: 6, height: CGFloat(10 + (i * 11) % 26)) }
            }
            Spacer()
            Button("Play · \(taps)") { taps += 1 }.buttonStyle(PillButtonStyle())
        }
        .foregroundStyle(.white).padding(22).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .xeerpe(.aurora(in: shape))
    }
}

@MainActor
struct RevealCard: View {
    let title: String, code: String
    let style: (XeerpeValue) -> XeerpeChain
    @State var progress: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MockCard().frame(height: 230).xeerpe(style(.binding($progress)))
            HStack {
                Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Button(progress > 0.5 ? "Hide" : "Reveal") {
                    withAnimation(.easeInOut(duration: 1.6)) { progress = progress > 0.5 ? 0 : 1 }
                }
            }
            Slider(value: $progress, in: 0...1)
            CodeView(code)
        }
    }
}

@MainActor
struct Reveals: View {
    let start: Double
    @State private var shown = true
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Move the pointer over a card, or touch it on a phone. The content is blurred and dimmed, and turns clear where you are. Its buttons keep working.")
                .foregroundStyle(.white.opacity(0.6))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 400), spacing: 28)], alignment: .leading, spacing: 32) {
                InteractiveCard(title: "hoverReveal", code: "card.xeerpe(.hoverReveal())", look: .hoverReveal(), wallpaper: "synthwave")
                InteractiveCard(title: "inkReveal", code: "card.xeerpe(.inkReveal())", look: .inkReveal(), wallpaper: "aurora-dream")
                InteractiveCard(title: "torch", code: "card.xeerpe(.torch())", look: .torch(), wallpaper: "gold")
                InteractiveCard(title: "on a reactive preset", code: "card.xeerpe(.preset(.galaxy, reacting: .touch))\n    .xeerpe(.inkReveal(radius: 110))",
                                look: .inkReveal(radius: 110), wallpaper: "galaxy", reactiveWallpaper: true)
            }
            Text("Driven by your own value: drag the slider, press Reveal, then press again mid-way to reverse. The button inside ignores clicks while hidden.")
                .foregroundStyle(.white.opacity(0.6))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 400), spacing: 28)], alignment: .leading, spacing: 32) {
                RevealCard(title: "fluidReveal", code: "view.xeerpe(.fluidReveal(progress: .binding($p)))",
                           style: { .fluidReveal(progress: $0, glow: .cyan) }, progress: start)
                RevealCard(title: "irisReveal", code: "view.xeerpe(.irisReveal(progress: .binding($p), from: .topLeading))",
                           style: { .irisReveal(progress: $0, from: .topLeading, glow: .white) }, progress: start)
                RevealCard(title: "wipeReveal", code: "view.xeerpe(.wipeReveal(progress: .binding($p), angle: 20))",
                           style: { .wipeReveal(progress: $0, angle: 20, glow: .pink) }, progress: start)
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 30).fill(.white.opacity(0.04)).frame(height: 230)
                        if shown { MockCard().frame(height: 230).transition(.xeerpe(.fluid(from: .bottom), glow: .cyan)) }
                    }
                    HStack {
                        Text("as a transition").font(.system(.headline, design: .rounded)).foregroundStyle(.white)
                        Spacer()
                        Button(shown ? "Remove" : "Insert") { withAnimation(.easeInOut(duration: 1.4)) { shown.toggle() } }
                    }
                    CodeView("if shown { card.transition(.xeerpe(.fluid(from: .bottom))) }")
                }
            }
        }
    }
}
#endif
