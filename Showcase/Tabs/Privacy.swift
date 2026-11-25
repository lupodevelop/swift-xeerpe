#if os(macOS)
import SwiftUI
import LocalAuthentication
import xeerpe

// Hiding and showing: a lock screen, blurred rows, a progressive blur,
// screens that go offline, a vault opened by a fingerprint.

@MainActor
struct LockPhone: View {
    var body: some View {
        Phone {
            VStack(spacing: 10) {
                Text("Friday 20 November").font(.system(.callout, design: .rounded).weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 60)
                Text("9:41").font(.system(size: 86, weight: .bold, design: .rounded))
                    .xeerpeFill(.preset(.iridescent, reacting: .tilt))
                Spacer()
                ForEach([("message.fill", "Giulia", "The butler was the narrator all along"),
                         ("creditcard.fill", "Bank", "Payment of € 48,15 at Esselunga")], id: \.1) { n in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: n.0).font(.title3).frame(width: 30, height: 30).background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n.1).font(.system(size: 14, weight: .semibold))
                            Text(n.2).font(.system(size: 13)).lineLimit(2)
                        }
                        Spacer()
                    }
                    .foregroundStyle(.white).padding(12)
                    .xeerpe(.hoverReveal(radius: 90, blur: 10))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                Text("slide to unlock").font(.system(.callout, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .xeerpe { .shimmer() }
                    .padding(.vertical, 26)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .xeerpe(.preset(.northernLights, reacting: .tilt, strength: 1.4))
        }
    }
}

@MainActor
struct PrivacyDemo: View {
    @State private var on = false
    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            InboxMock()
                .frame(width: 420, height: 230)
                .xeerpe { .privacy(.max(on, .inactive)) }
            VStack(alignment: .leading, spacing: 12) {
                heading("Privacy mode", "Blurs everything: on the switch, and on its own when the window loses focus (click another app).")
                Toggle("Privacy", isOn: Binding(get: { on }, set: { v in withAnimation(.smooth(duration: 0.5)) { on = v } }))
                    .toggleStyle(.switch).foregroundStyle(.white)
                CodeView("""
                screen.xeerpe {
                    .privacy(.max(on, .inactive))
                }
                """)
            }
        }
    }
}

@MainActor
private struct InboxMock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach([("Dr. Rossi", "Your test results are ready"), ("Bank", "New login from Milano, IT"),
                     ("Marta", "Don't tell anyone, but…")], id: \.0) { m in
                HStack(spacing: 12) {
                    Circle().fill(.white.opacity(0.25)).frame(width: 34, height: 34)
                        .overlay(Text(String(m.0.prefix(1))).foregroundStyle(.white))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.0).font(.system(size: 14, weight: .semibold))
                        Text(m.1).font(.system(size: 13)).opacity(0.75)
                    }
                    .foregroundStyle(.white)
                    Spacer()
                }
            }
        }
        .padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .xeerpe(.preset(.blueHour, in: card))
    }
}

@MainActor
struct ProgressiveBlur: View {
    @State private var hidden = snapshotProgress ?? 0

    private func panel(_ title: String, _ preset: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 30, weight: .bold, design: .rounded))
            Text("Tomorrow 9:00 · Studio B").font(.callout).opacity(0.8)
            Spacer()
            HStack { Image(systemName: "calendar"); Text("3 people"); Spacer(); Image(systemName: "chevron.right") }.font(.callout)
        }
        .foregroundStyle(.white).padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .xeerpe(XeerpeCatalog[preset]!.style(in: card))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Progressive blur", "A soft front of blur and shade sweeps across to hide, and back to show. Press mid-way to reverse.")
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    panel("Design review", "aurora-dream")
                        .frame(height: 220)
                        .xeerpe { .blurSweep(progress: .binding($hidden), angle: 90, maxBlur: 30, darken: 0.45) }
                    HStack {
                        Button(hidden > 0.5 ? "Show" : "Hide") { withAnimation(.easeInOut(duration: 1.2)) { hidden = hidden > 0.5 ? 0 : 1 } }
                            .buttonStyle(PillButtonStyle())
                        Slider(value: $hidden, in: 0...1)
                    }
                    CodeView("""
                    panel.xeerpe { .blurSweep(progress: .binding($hidden), angle: 90) }
                    withAnimation(.easeInOut(duration: 1.2)) { hidden = 1 }
                    """)
                }
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Balance").font(.caption).opacity(0.7)
                        Text("€ 12.480,22").font(.system(size: 34, weight: .bold, design: .rounded))
                        Spacer()
                        Text("IBAN IT60 X054 2811 1010 0000 0123 456").font(.system(.caption, design: .monospaced)).opacity(0.85)
                    }
                    .foregroundStyle(.white).padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .xeerpe {
                        .preset(.midnight, in: card)
                        .viewAngle(.tilt, start: 0.15, maxBlur: 26, darken: 0.55)
                        .tilt3D(.tilt, angle: 22)
                    }
                    .frame(height: 220)
                    Text("Privacy by viewing angle: move the pointer to a side (tilt the phone). The more it leans, the more the far side blurs and darkens.")
                        .font(.callout).foregroundStyle(.white.opacity(0.55))
                    CodeView("""
                    account.xeerpe {
                        .preset(.midnight, in: card)
                        .viewAngle(.tilt, start: 0.15)
                        .tilt3D(.tilt, angle: 22)
                    }
                    """)
                }
            }
        }
    }
}

@MainActor
struct RetroScreens: View {
    @State private var offline = true

    private func contact() -> some View {
        HStack(spacing: 14) {
            Circle().fill(LinearGradient(colors: [.orange, .pink], startPoint: .top, endPoint: .bottom))
                .overlay { Text("GR").font(.system(.title2, design: .rounded).bold()).foregroundStyle(.white) }
                .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text("Giulia Rossi").font(.headline)
                Text("+39 347 555 0192").font(.system(.callout, design: .monospaced)).opacity(0.8)
            }
            Spacer()
        }
        .foregroundStyle(.white).padding(16).frame(height: 96)
        .background(card.fill(Color(white: 0.14)))
    }

    private func banner() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Connection lost").font(.headline)
                Text("Retrying in 5 s").font(.callout).opacity(0.8)
            }
            Spacer()
        }
        .foregroundStyle(.white).padding(16).frame(height: 96)
        .background(card.fill(Color(red: 0.75, green: 0.12, blue: 0.2)))
    }

    private func terminal() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("> ssh ops@vault").font(.system(.callout, design: .monospaced))
            Text("Touch ID to continue").font(.headline)
        }
        .foregroundStyle(.white).padding(16).frame(maxWidth: .infinity, alignment: .leading).frame(height: 96)
    }

    private func step(_ view: some View, _ code: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { view; CodeView(code) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Pixel, glitch, rain", "A contact hidden in blocks until the pointer is on it, an offline banner that glitches until the connection is back, a sign-in over digital rain that speeds up under the pointer.")
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    step(contact().xeerpe { .pixelate(12) }, "contact.xeerpe { .pixelate(12) }")
                    step(contact().xeerpe { .pixelate(.hover(from: 12, to: 1)) },
                         "contact.xeerpe { .pixelate(.hover(from: 12, to: 1)) }")
                }
                VStack(alignment: .leading, spacing: 14) {
                    step(banner().xeerpe { .glitch() }, "banner.xeerpe { .glitch() }")
                    step(VStack(alignment: .leading, spacing: 8) {
                        banner().xeerpe { if offline { .glitch(shift: 22) } }
                        Button(offline ? "Reconnect" : "Drop connection") { offline.toggle() }.buttonStyle(PillButtonStyle())
                    }, "banner.xeerpe { if offline { .glitch(shift: 22) } }")
                }
                VStack(alignment: .leading, spacing: 14) {
                    step(terminal().xeerpe { .matrix(in: card) }, "terminal.xeerpe { .matrix(in: card) }")
                    step(terminal().xeerpe { .matrix(speed: .hover(from: 1, to: 3), density: 0.6, in: card) },
                         "terminal.xeerpe {\n    .matrix(speed: .hover(from: 1, to: 3), density: 0.6, in: card)\n}")
                }
            }
        }
    }
}

@MainActor
struct VaultDemo: View {
    @State private var job = XeerpeJob<Bool>()
    private let card = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            caption("Vault", "Real Touch ID. Locked: blurred. Waiting: the lock beats. Unlocked: the content pours in. Refused: it shakes.")
            ZStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recovery codes").font(.system(.headline, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                    ForEach(["7F3K-92QX-LM4P", "B81Z-0RTW-55HN", "QQ2D-XE7Y-3VAC"], id: \.self) {
                        Text($0).font(.system(size: 22, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                    }
                }
                .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .xeerpe {
                    .phases(job, transition: .fluid(from: .center), glow: .yellow) { phase in
                        switch phase {
                        case .done: return XeerpeChain()
                        case .pending: return XeerpeChain.privacy(true, blur: 16).liquid(.orchid, speed: 1.2, warp: 2, in: card)
                        case .failed: return XeerpeChain.privacy(true, blur: 16).glow(.red, radius: 18).then(shake(job))
                        default: return XeerpeChain.privacy(true, blur: 16)
                        }
                    }
                    .feedback(.success, sound: .glass, on: .entered(.done, of: job))
                    .feedback(.error, sound: .system(name: "Basso", id: 1073), on: .entered(.failed, of: job))
                }
                if job.phase != .done {
                    Image(systemName: job.phase == .failed ? "lock.trianglebadge.exclamationmark.fill" : "lock.fill")
                        .font(.system(size: 46)).foregroundStyle(.white)
                        .xeerpe { .scale(XeerpeValue.beat(58).map { job.phase == .pending ? $0 : 0 }.mapped(to: 1, 1.1)) }
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 230)
            .xeerpe(.preset(.blackGold, in: card))
            .clipShape(card)
            .animation(.smooth, value: job.phase)
            HStack {
                Button(job.phase == .done ? "Lock" : "Unlock with Touch ID") {
                    if job.phase == .done { job.cancel() } else { job.run { _ in try await authenticate() } }
                }
                .buttonStyle(PillButtonStyle())
                Spacer()
            }
            CodeView("""
            vault.xeerpe {
                .phases(job, transition: .fluid(from: .center)) { phase in
                    switch phase {
                    case .done: XeerpeChain()
                    case .pending: .privacy(true).liquid(.orchid, in: card)
                    case .failed: .privacy(true).glow(.red).then(shake(job))
                    default: .privacy(true)
                    }
                }
                .feedback(.success, sound: .glass, on: .entered(.done, of: job))
            }
            job.run { _ in try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "unlock") }
            """)
        }
    }

    private func authenticate() async throws -> Bool {
        let context = LAContext()
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "unlock the vault")
    }
}
#endif
