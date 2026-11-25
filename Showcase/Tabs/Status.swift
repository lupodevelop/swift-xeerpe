#if os(macOS)
import SwiftUI
import AppKit
import xeerpe

// Progress and state: loading, a job with phases, a volume limit, pulses,
// smoke and sparks.

@MainActor
struct LoadingFeed: View {
    @State private var loaded: Set<Int> = []
    @State private var round = 0
    private let posts = [("Aurora over Tromsø", "aurora-dream"), ("Night market in Taipei", "neon-tokyo"),
                         ("Dunes at dawn", "dunes"), ("Glacier lagoon", "glacier")]

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                ForEach(Array(posts.enumerated()), id: \.offset) { i, p in
                    VStack(alignment: .leading, spacing: 8) {
                        Color.clear.frame(height: 90).xeerpe(XeerpeCatalog[p.1]!.style(in: RoundedRectangle(cornerRadius: 14)))
                        Text(p.0).font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(.white)
                        Text("2 h ago · 1.2k likes").font(.caption).foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(10).background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.06)))
                    .xeerpe { .loading(!loaded.contains(i), reveal: .fluid(from: .topLeading)) }
                    .task(id: round) {
                        // Simulated network: each card arrives at its own time.
                        try? await Task.sleep(for: .seconds(1.2 + Double(i) * 0.45))
                        _ = withAnimation(.easeInOut(duration: 0.9)) { loaded.insert(i) }
                    }
                }
            }
            .frame(width: 420)
            VStack(alignment: .leading, spacing: 12) {
                heading("Lazy loading", "A skeleton with a moving light while loading, then the card pours in.")
                Button("Reload") { loaded = []; round += 1 }.buttonStyle(PillButtonStyle())
                CodeView("""
                card.xeerpe { .loading(isLoading, reveal: .fluid(from: .topLeading)) }

                withAnimation { isLoading = false }
                """)
            }
        }
    }
}

@MainActor
struct HeartView: View {
    @Binding var bpm: Double
    var body: some View {
        // The rate is a signal: the slider, plus 12 while the pointer is on the card.
        let rate = XeerpeValue.binding($bpm) + .hover(from: 0, to: 10)
        let beat = XeerpeValue.beat(rate)
        Image(systemName: "heart.fill").font(.system(size: 110))
            .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.35, blue: 0.5), Color(red: 0.8, green: 0.05, blue: 0.25)],
                                            startPoint: .top, endPoint: .bottom))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .xeerpe {
                .scale(beat.mapped(to: 1, 1.07))
                .bloom(radius: beat.mapped(to: 12, 30), intensity: beat.mapped(to: 0.35, 0.85))
                .feedback(.impact(weight: .light), on: .beat(rate))
            }
    }
}

@MainActor
struct RateLabel: View {
    @Binding var bpm: Double
    var body: some View {
        HStack {
            Slider(value: $bpm, in: 40...180)
            Text("\(Int(bpm)) bpm").monospacedDigit().foregroundStyle(.white.opacity(0.7)).frame(width: 70)
        }
    }
}

@MainActor
struct PulseAndLight: View {
    @State private var bpm = 54.0
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Pulse and light", "A heart that beats at any rate signal, with a bloom of itself. A screen edge that lights up while you hold it.")
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    HeartView(bpm: $bpm)
                        .frame(height: 260)
                        .background(card.fill(RadialGradient(colors: [Color(red: 0.25, green: 0.03, blue: 0.08), Color(white: 0.04)],
                                                             center: .center, startRadius: 10, endRadius: 260)))
                        .clipShape(card)
                    RateLabel(bpm: $bpm)
                    CodeView("""
                    let rate = XeerpeValue.binding($bpm) + .hover(from: 0, to: 10)
                    let beat = XeerpeValue.beat(rate)
                    heart.xeerpe {
                        .scale(beat.mapped(to: 1, 1.07))
                        .bloom(radius: beat.mapped(to: 12, 30))
                        .feedback(.impact(weight: .light), on: .beat(rate))
                    }
                    """)
                }
                VStack(alignment: .leading, spacing: 14) {
                    Phone {
                        VStack(spacing: 14) {
                            Spacer()
                            Image(systemName: "waveform").font(.system(size: 40)).foregroundStyle(.white.opacity(0.9))
                                .xeerpe { .scale(XeerpeValue.press(from: 1, to: 1.25)) }
                            Text("Hold to talk").font(.system(.title3, design: .rounded).weight(.semibold)).foregroundStyle(.white)
                            Text("Hover lights the edge, holding turns it on.").font(.callout).foregroundStyle(.white.opacity(0.6))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(red: 0.02, green: 0.02, blue: 0.05))
                        .xeerpe {
                            .edgeGlow(intensity: .max(.hover(from: 0, to: 0.35), .press(from: 0, to: 1)),
                                      width: 6, in: RoundedRectangle(cornerRadius: 46, style: .continuous))
                            .feedback(.levelChange, sound: .pop, on: .press)
                        }
                    }
                    CodeView("""
                    screen.xeerpe {
                        .edgeGlow(intensity: .max(.hover(from: 0, to: 0.35),
                                                  .press(from: 0, to: 1)))
                        .feedback(.levelChange, sound: .pop, on: .press)
                    }
                    """)
                }
                .frame(width: 300)
            }
        }
    }
}

struct Export: Sendable { var count: Int; var bytes: Int }

@MainActor
struct ExportDemo: View {
    @State private var job = XeerpeJob<Export>()
    private let ids = ["gold", "aurora-dream", "synthwave", "glacier", "galaxy", "rose-gold",
                       "jungle", "neon-tokyo", "sunset", "holographic", "lava", "ocean"]
    private let tile = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        let done = job.value?.count ?? 0
        VStack(alignment: .leading, spacing: 14) {
            caption("Export", "Real work: each wallpaper is rendered to a 1024 px PNG. Tiles appear as they are written.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Array(ids.enumerated()), id: \.offset) { i, id in
                    Color.clear.frame(height: 56)
                        .xeerpe(XeerpeCatalog[id]!.style(in: tile))
                        .xeerpe { .reveal(.iris(from: .center), progress: i < done ? 1 : 0, glow: .white) }
                        .background(tile.fill(.white.opacity(0.05)))
                        .animation(.easeOut(duration: 0.6), value: done)
                }
            }
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                GeometryReader { g in
                    Color.clear.frame(width: max(g.size.width * job.progress, 0))
                        .xeerpe { .liquid(.ocean, speed: 1.4, in: Capsule()) }
                        .animation(.smooth, value: job.progress)
                }
                Text(label).font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(.white).padding(.horizontal, 12)
            }
            .frame(height: 28)
            .xeerpe { .feedback(.success, sound: .glass, on: .entered(.done, of: job)) }
            HStack {
                Button(job.phase == .pending || job.phase == .streaming ? "Cancel" : "Export 12 wallpapers") {
                    if job.phase == .pending || job.phase == .streaming { job.cancel() } else { start() }
                }
                .buttonStyle(PillButtonStyle())
                Spacer()
            }
            CodeView("""
            tile.xeerpe { .reveal(.iris(from: .center), progress: i < job.value?.count ?? 0 ? 1 : 0) }
            bar.frame(width: width * job.progress).xeerpe { .liquid(.ocean, in: Capsule()) }
            job.run { report in
                for (i, id) in ids.enumerated() { render(id); await report(Double(i + 1) / 12, Export(...)) }
            }
            """)
        }
    }

    private var label: String {
        let e = job.value ?? Export(count: 0, bytes: 0)
        switch job.phase {
        case .idle: return "Ready"
        case .done: return "Done · \(ByteCountFormatter.string(fromByteCount: Int64(e.bytes), countStyle: .file))"
        case .failed: return "Failed"
        default: return "\(e.count)/12 · \(ByteCountFormatter.string(fromByteCount: Int64(e.bytes), countStyle: .file))"
        }
    }

    private func start() {
        let ids = ids
        job.run { report in
            var e = Export(count: 0, bytes: 0)
            for id in ids {
                try Task.checkCancellation()
                let bytes = await MainActor.run { () -> Int in
                    let r = ImageRenderer(content: Color.clear.frame(width: 512, height: 512).xeerpe(XeerpeCatalog[id]!.style()))
                    r.scale = 2
                    guard let cg = r.cgImage else { return 0 }
                    return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.count ?? 0
                }
                e.count += 1
                e.bytes += bytes
                await report(Double(e.count) / Double(ids.count), e)
                try await Task.sleep(for: .milliseconds(120))
            }
            return e
        }
    }
}

@MainActor
struct SmokeSparksDemo: View {
    private func like() -> some View {
        Image(systemName: "heart.fill").font(.system(size: 56)).foregroundStyle(.pink)
            .frame(maxWidth: .infinity).frame(height: 130)
    }

    private func engine() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cpu").font(.system(size: 40))
            VStack(alignment: .leading) { Text("GPU 94 °C").font(.headline); Text("Throttling").font(.callout).opacity(0.8) }
            Spacer()
        }
        .foregroundStyle(.white).padding(16).frame(height: 90)
        .background(tile.fill(Color(red: 0.55, green: 0.15, blue: 0.1)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Smoke and sparks", "Sparks burst where you tap; smoke rises from an overheated card. Both stack in one chain.")
            HStack(alignment: .top, spacing: 14) {
                step("like.xeerpe { .sparks() }") { like().xeerpe { .sparks() } }
                step("card.xeerpe { .smoke() }") { engine().xeerpe { .smoke() }.padding(.top, 90) }
                step("card.xeerpe {\n    .smoke(.hover(from: 0.4, to: 1))\n    .sparks(.orange)\n}") {
                    engine().xeerpe { .smoke(.hover(from: 0.4, to: 1)).sparks(.orange) }.padding(.top, 90)
                }
            }
        }
    }
}

@MainActor
struct GenieDemo: View {
    @State private var p = snapshotProgress ?? 0
    @State private var shown = true

    private func doc() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Q3 report.pdf").font(.headline)
            ForEach(0..<4) { i in RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.25)).frame(height: 8).padding(.trailing, CGFloat(i * 30)) }
        }
        .foregroundStyle(.white).padding(16).frame(maxWidth: .infinity, alignment: .leading).frame(height: 150, alignment: .top)
        .background(tile.fill(Color(red: 0.15, green: 0.3, blue: 0.6)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Genie", "A window that pours into the dock, as an effect driven by a binding or as a transition.")
            HStack(alignment: .top, spacing: 14) {
                step("doc.xeerpe { .genie(progress: .binding($p), to: UnitPoint(x: 0.8, y: 1)) }") {
                    VStack(spacing: 8) {
                        doc().xeerpe { .genie(progress: .binding($p), to: UnitPoint(x: 0.8, y: 1)) }
                        HStack {
                            Button(p > 0.5 ? "Restore" : "Minimize") { withAnimation(.easeInOut(duration: 0.8)) { p = p > 0.5 ? 0 : 1 } }
                                .buttonStyle(PillButtonStyle())
                            Slider(value: $p, in: 0...1)
                        }
                    }
                }
                step("if shown { doc.transition(.xeerpeGenie(to: .bottom)) }") {
                    VStack(spacing: 8) {
                        ZStack { if shown { doc().transition(.xeerpeGenie(to: .bottom)) } }.frame(height: 150)
                        Button(shown ? "Remove" : "Insert") { withAnimation(.easeInOut(duration: 0.8)) { shown.toggle() } }
                            .buttonStyle(PillButtonStyle())
                    }
                }
            }
        }
    }
}

@MainActor
struct VolumeLimit: View {
    @State private var volume = 0.5

    private func meter() -> some View {
        HStack(spacing: 14) {
            Image(systemName: volume > 0.85 ? "speaker.wave.3.fill" : "speaker.wave.2.fill").font(.title2)
            GeometryReader { g in
                Capsule().fill(.white.opacity(0.15))
                    .overlay(alignment: .leading) { Capsule().fill(volume > 0.85 ? Color.orange : .white).frame(width: g.size.width * volume) }
            }
            .frame(height: 8)
        }
        .foregroundStyle(.white).padding(18).frame(height: 70)
        .background(Color(white: 0.12), in: tile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Volume limit", "The bar glows brighter as the volume rises. Past 85% a haptic and a sound fire once, as it crosses the limit, not on every move.")
            HStack(alignment: .top, spacing: 14) {
                step("bar.xeerpe { .glow(.orange, radius: .binding($volume).mapped(to: 0, 14)) }") {
                    meter().xeerpe { .glow(.orange, radius: .binding($volume).mapped(to: 0, 14)) }
                }
                step("bar.xeerpe {\n    .glow(.orange, radius: .binding($volume).mapped(to: 0, 14))\n    .feedback(.warning, sound: .pop, on: .crossing(.binding($volume), above: 0.85))\n}") {
                    meter().xeerpe {
                        .glow(.orange, radius: .binding($volume).mapped(to: 0, 14))
                        .feedback(.warning, sound: .pop, on: .crossing(.binding($volume), above: 0.85))
                    }
                }
            }
            Slider(value: $volume).frame(width: 320)
        }
    }
}
#endif
