#if os(macOS)
import SwiftUI
import NaturalLanguage
import xeerpe
#if canImport(FoundationModels)
import FoundationModels
#endif

// Chat: spoilers, a burned message, text that rises in, gooey typing dots,
// and an assistant that streams its answer.

@MainActor
struct ChatPhone: View {
    private struct Message: Identifiable { let id: Int; let text: String; let mine: Bool; let spoiler: Bool }
    private let messages = [
        Message(id: 0, text: "Finished the finale last night", mine: false, spoiler: false),
        Message(id: 1, text: "No spoilers please!!", mine: true, spoiler: false),
        Message(id: 2, text: "The butler was the narrator all along", mine: false, spoiler: true),
        Message(id: 3, text: "…and the city was a ship", mine: false, spoiler: true),
        Message(id: 4, text: "I hate you", mine: true, spoiler: false),
    ]

    var body: some View {
        Phone {
            VStack(alignment: .leading, spacing: 10) {
                Text("Giulia").font(.system(.headline, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.top, 52).padding(.bottom, 8)
                ForEach(messages) { m in
                    let text = Text(m.text).font(.system(size: 15)).foregroundStyle(.white)
                    Group {
                        if m.spoiler {
                            text.xeerpe { .spoiler().feedback(.impact(weight: .light), sound: .pop, on: .tap) }
                        } else {
                            text
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(m.mine ? Color.blue : Color(white: 0.2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: m.mine ? .trailing : .leading)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .background(Color(white: 0.04))
        }
    }
}

struct Reply: Sendable {
    var text: String
    /// Sentiment of the text, -1...1, from NaturalLanguage.
    var mood: Double
}

func sentiment(_ text: String) -> Double {
    let tagger = NLTagger(tagSchemes: [.sentimentScore])
    tagger.string = text
    let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
    return Double(tag?.rawValue ?? "0") ?? 0
}

func moodColor(_ m: Double) -> Color {
    m > 0.1 ? Color(red: 0.3, green: 0.9, blue: 0.6) : m < -0.1 ? Color(red: 1, green: 0.35, blue: 0.4) : Color(white: 0.7)
}

/// The real work: the on-device language model when it is available,
/// otherwise the sentiment of the message read back. Both stream.
@Sendable func answer(_ prompt: String, report: XeerpeJob<Reply>.Report) async throws -> Reply {
    #if canImport(FoundationModels)
    if #available(macOS 26, *), SystemLanguageModel.default.availability == .available {
        let session = LanguageModelSession(instructions: "Reply in one or two short sentences, in the language of the message.")
        var text = ""
        do {
            for try await snapshot in session.streamResponse(to: prompt) {
                text = snapshot.content
                await report(min(Double(text.count) / 160, 0.95), Reply(text: text, mood: sentiment(text)))
            }
            return Reply(text: text, mood: sentiment(text))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // The system model can refuse at any time (busy, guardrails not
            // loaded): fall through to the local reply below.
        }
    }
    #endif
    let mood = sentiment(prompt)
    let text = "The on-device model is not answering right now. Your message reads \(mood > 0.1 ? "positive" : mood < -0.1 ? "negative" : "neutral") (\(String(format: "%.2f", mood)))."
    var shown = ""
    for word in text.split(separator: " ") {
        try await Task.sleep(for: .milliseconds(90))
        shown += (shown.isEmpty ? "" : " ") + word
        await report(Double(shown.count) / Double(text.count), Reply(text: shown, mood: mood))
    }
    return Reply(text: text, mood: mood)
}

@MainActor
struct AssistantDemo: View {
    @State private var job = XeerpeJob<Reply>()
    @State private var prompt = "I finally finished the project and it works!"
    @State private var asked = ""
    @State private var step = 5

    private let steps: [(String, String)] = [
        ("The job", "job.run { report in try await answer(prompt, report: report) }"),
        ("A look per phase", ".phases(job) { phase in .aura(...) }"),
        ("The result as a signal", "case .done: .aura(moodColors(job.value?.mood))"),
        ("Haptics, sound and edge light", ".feedback(.success, sound: .glass, on: .entered(.done, of: job))"),
        ("A pulse that quickens", ".scale(.beat(.phaseTime(job).remap(0...6, to: 48, 96)))"),
    ]

    private var mood: Double { job.value?.mood ?? 0 }
    private var moodColors: [Color] {
        mood > 0.1 ? [Color(red: 0.3, green: 0.95, blue: 0.7), Color(red: 0.4, green: 0.8, blue: 1), Color(red: 0.75, green: 1, blue: 0.6), .teal]
            : mood < -0.1 ? [Color(red: 1, green: 0.35, blue: 0.4), Color(red: 1, green: 0.6, blue: 0.3), Color(red: 0.8, green: 0.2, blue: 0.5), .orange]
            : [Color(red: 0.6, green: 0.7, blue: 0.9), .white, Color(red: 0.5, green: 0.6, blue: 0.8), .gray]
    }
    private var surface: String { mood > 0.1 ? "aurora-dream" : mood < -0.1 ? "volcano" : "blue-hour" }

    private let calmColors: [Color] = [Color(red: 0.2, green: 0.4, blue: 1), Color(red: 0.3, green: 0.9, blue: 1), Color(red: 0.6, green: 0.4, blue: 1), Color(red: 0.95, green: 0.55, blue: 0.9), Color(red: 0.15, green: 0.7, blue: 0.85)]
    private var calm: XeerpeChain { XeerpeChain.aura(calmColors, speed: 0.9).bloom(radius: 22, intensity: 0.35).breathe(period: 5, amount: 0.03) }

    private var orb: XeerpeChain {
        guard step >= 2 else { return calm }
        var chain = XeerpeChain.phases(job, transition: .iris(from: .center), glow: .white) { phase in
            switch phase {
            case .pending:
                var c = XeerpeChain.aura(speed: XeerpeValue.phaseTime(job).remap(0...6, to: 1, 2.6)).bloom(radius: 30, intensity: 0.7)
                if step >= 5 { c = c.scale(XeerpeValue.beat(XeerpeValue.phaseTime(job).remap(0...6, to: 48, 96)).mapped(to: 1, 1.05)) }
                return c
            case .streaming:
                return XeerpeChain.aura(speed: 1.8).bloom(radius: 26, intensity: 0.55)
            case .done where step >= 3:
                return XeerpeChain.aura(moodColors, speed: 0.7).bloom(radius: 28, intensity: 0.6)
            case .failed:
                return XeerpeChain.aura(XeerpeGlow.ember, speed: 1).bloom(radius: 24, intensity: 0.5)
            default:
                return calm
            }
        }
        if step >= 4 {
            chain = chain
                .feedback(.selection, sound: .tick, on: .steps(.progress(job), count: 8))
                .feedback(.success, sound: .glass, on: .entered(.done, of: job))
        }
        return chain
    }

    private var status: String {
        switch job.phase {
        case .idle: "Ask me anything"
        case .pending: "Thinking"
        case .streaming: "Writing"
        case .done: step >= 3 ? (mood > 0.1 ? "Sounds good" : mood < -0.1 ? "Rough one" : "Noted") : "Done"
        case .failed: "Failed: \(job.error.map { String(describing: $0) } ?? "unknown")"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            chat.frame(width: 470)
            VStack(alignment: .leading, spacing: 14) {
                caption("Assistant", "The on-device model writes the reply, NaturalLanguage reads its mood. Click a step: each one adds to the same chain.")
                VStack(spacing: 6) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        Button { withAnimation(.smooth) { step = i + 1 } } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(i + 1)").font(.system(.callout, design: .rounded).bold())
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(i < step ? Color.white : .white.opacity(0.1)))
                                    .foregroundStyle(i < step ? Color.black : .white.opacity(0.6))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.0).font(.system(.callout, design: .rounded).weight(.semibold)).foregroundStyle(.white.opacity(i < step ? 1 : 0.45))
                                    Text(s.1).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.white.opacity(i < step ? 0.6 : 0.25))
                                        .lineLimit(1).truncationMode(.tail)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(i + 1 == step ? 0.08 : 0)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                CodeView(source)
            }
        }
    }

    /// The code of the chain as it is at the selected step.
    private var source: String {
        var lines = ["@State var job = XeerpeJob<Reply>()", "job.run { report in try await answer(prompt, report: report) }"]
        guard step >= 2 else { return (lines + ["", "orb.xeerpe { .aura(calm, speed: 0.6).bloom(radius: 22, intensity: 0.35) }"]).joined(separator: "\n") }
        lines += ["", "orb.xeerpe {", "    .phases(job, transition: .iris(from: .center)) { phase in", "        switch phase {",
                  "        case .pending:", "            .aura(speed: .phaseTime(job).remap(0...6, to: 1, 2.6))",
                  "            .bloom(radius: 30, intensity: 0.7)"]
        if step >= 5 { lines.append("            .scale(.beat(.phaseTime(job).remap(0...6, to: 48, 96)).mapped(to: 1, 1.05))") }
        lines += ["        case .streaming: .aura(speed: 1.8).bloom(radius: 26)"]
        if step >= 3 { lines.append("        case .done: .aura(moodColors, speed: 0.7).bloom(radius: 28)") }
        lines += ["        default: .aura(calm, speed: 0.6).bloom(radius: 22, intensity: 0.35)", "        }", "    }"]
        if step >= 4 {
            lines += ["    .feedback(.selection, sound: .tick, on: .steps(.progress(job), count: 8))",
                      "    .feedback(.success, sound: .glass, on: .entered(.done, of: job))", "}",
                      "panel.xeerpe { .edgeGlow(intensity: .phase(job, is: .pending)) }"]
        } else {
            lines.append("}")
        }
        return lines.joined(separator: "\n")
    }

    private var chat: some View {
        VStack(spacing: 18) {
            Circle().fill(.clear).frame(width: 110, height: 110).contentShape(Circle()).xeerpe { orb }.padding(.top, 10)
            Text(status).font(.system(.headline, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                .contentTransition(.opacity).animation(.smooth, value: status)
            if !asked.isEmpty {
                Text(asked).font(.system(size: 14)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if job.phase != .idle && job.phase != .pending {
                Text(job.value?.text ?? "").font(.system(size: 15)).foregroundStyle(.white)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .xeerpe { job.phase == .streaming && step >= 2 ? XeerpeChain.shimmer(period: 1.2) : XeerpeChain() }
                    .background {
                        if step >= 3 && job.phase == .done {
                            Color.clear.xeerpe(XeerpeCatalog[surface]!.style(in: RoundedRectangle(cornerRadius: 20, style: .continuous)))
                                .transition(.opacity)
                        } else {
                            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(white: 0.16))
                        }
                    }
                    .animation(.smooth(duration: 0.6), value: job.phase)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                TextField("Message", text: $prompt).textFieldStyle(.plain).foregroundStyle(.white).onSubmit(send)
                Button(action: send) { Image(systemName: "arrow.up").font(.system(size: 14, weight: .bold)).foregroundStyle(.black).frame(width: 30, height: 30).background(Circle().fill(.white)) }
                    .buttonStyle(.plain)
            }
            .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.08)))
        }
        .padding(22)
        .frame(height: 470)
        .xeerpe { step >= 4 ? XeerpeChain.edgeGlow(intensity: .max(.phase(job, is: .pending), .phase(job, is: .streaming) * 0.6), in: panel) : XeerpeChain() }
        .animation(.smooth(duration: 0.6), value: job.phase)
        .background(panel.fill(LinearGradient(colors: [Color(white: 0.09), Color(white: 0.05)], startPoint: .top, endPoint: .bottom)))
        .overlay(panel.stroke(.white.opacity(0.08)))
    }

    private func send() {
        let p = prompt
        asked = p
        job.run { report in try await answer(p, report: report) }
    }
}

@MainActor
struct BurnDemo: View {
    @State private var burnt = snapshotProgress ?? 0
    @State private var burning = snapshotProgress.map { $0 > 0 && $0 < 1 } ?? false

    private func message(_ from: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 40, height: 40)
                .overlay { Text(String(from.prefix(1))).font(.headline).foregroundStyle(.white) }
            VStack(alignment: .leading, spacing: 2) {
                Text(from).font(.headline)
                Text(text).font(.callout).opacity(0.75).lineLimit(1)
            }
            Spacer()
        }
        .foregroundStyle(.white).padding(14)
        .background(tile.fill(Color(white: 0.15)))
    }

    private func burn() {
        burning = true
        withAnimation(.easeIn(duration: 1.8)) { burnt = 1 }
        Task { try? await Task.sleep(for: .seconds(2.1)); burning = false }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Delete with fire", "A message burns away from the bottom up; sparks rise from the burning front. Press Burn, then Restore.")
            HStack(alignment: .top, spacing: 18) {
                step("row.xeerpe { .burn(progress: .binding($burnt)) }") {
                    message("Marco", "The code for the door is 4471", .indigo)
                        .xeerpe { .burn(progress: .binding($burnt)) }
                }
                step("row.xeerpe {\n    .burn(progress: .binding($burnt))\n    if burning { .embers() }\n}") {
                    message("Bank", "Your one-time code is 902 114", .teal)
                        .xeerpe {
                            .burn(progress: .binding($burnt))
                            if burning { .embers() }
                        }
                }
            }
            HStack(spacing: 12) {
                Button(burnt > 0.5 ? "Restore" : "Burn") { burnt > 0.5 ? withAnimation(.easeOut(duration: 0.4)) { burnt = 0 } : burn() }
                    .buttonStyle(PillButtonStyle())
                Slider(value: $burnt, in: 0...1)
            }
        }
    }
}

/// Three dots chasing each other in one Canvas, so the gooey effect sees
/// them as one layer.
@MainActor
private struct Dots: View {
    var body: some View {
        TimelineView(.animation) { t in
            Canvas { ctx, size in
                let s = t.date.timeIntervalSinceReferenceDate
                for i in 0..<3 {
                    let x = size.width / 2 + sin(s * 2.4 + Double(i) * 2.1) * size.width * 0.28
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 14, y: size.height / 2 - 14, width: 28, height: 28)), with: .color(.mint))
                }
            }
        }
        .frame(height: 110)
    }
}

@MainActor
struct GooeyDemo: View {
    @State private var open = snapshotProgress != nil

    private var fab: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle().fill(Color.pink).frame(width: 44, height: 44)
                    .offset(x: open ? CGFloat(i - 1) * 70 : 0, y: open ? -60 : 0)
            }
            Circle().fill(Color.pink).frame(width: 64, height: 64)
                .overlay { Image(systemName: "plus").font(.title.bold()).foregroundStyle(.white).rotationEffect(.degrees(open ? 45 : 0)) }
        }
        .frame(maxWidth: .infinity).frame(height: 150, alignment: .bottom).padding(.bottom, 8)
        .onTapGesture { withAnimation(.spring(duration: 0.7, bounce: 0.35)) { open.toggle() } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Gooey", "Shapes that come close melt into one, like drops. A typing indicator and a menu button that buds off its items. Click the button.")
            HStack(alignment: .top, spacing: 14) {
                step("dots") { Dots() }
                step("dots.xeerpe { .gooey(radius: 10) }") { Dots().xeerpe { .gooey(radius: 10) } }
                step("menu.xeerpe { .gooey(radius: 12) }") { fab.xeerpe { .gooey(radius: 12) } }
            }
        }
    }
}

@available(macOS 15, *)
@MainActor
struct TextRiseDemo: View {
    @State private var p = snapshotProgress ?? 1
    private let reply = "Your flight lands at 18:40.\nA taxi to the hotel takes about 25 minutes.\nCheck-in is open until midnight."

    private func bubble(_ unit: XeerpeTextRise.Unit) -> some View {
        Text(reply).font(.system(.body, design: .rounded)).foregroundStyle(.white)
            .xeerpeTextRise(p, by: unit, spread: unit == .line ? 1.5 : 12)
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(tile.fill(Color(white: 0.16)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Text that rises", "An assistant reply that fades in, unblurs and rises into place, by line or by glyph. Press Ask.")
            HStack(alignment: .top, spacing: 14) {
                step("Text(reply).xeerpeTextRise(p)") { bubble(.line) }
                step("Text(reply).xeerpeTextRise(p, by: .glyph, spread: 12)") { bubble(.glyph) }
            }
            Button("Ask") { p = 0; withAnimation(.easeOut(duration: 1.8)) { p = 1 } }.buttonStyle(PillButtonStyle())
        }
    }
}
#endif
