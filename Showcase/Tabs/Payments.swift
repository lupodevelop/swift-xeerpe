#if os(macOS)
import SwiftUI
import xeerpe

// Money and cards: a wallet, card finishes, tickets, a gift sent with a job,
// a tap-to-pay flow.

@MainActor
struct WalletPhone: View {
    @State private var hidden = true
    var body: some View {
        Phone {
            VStack(alignment: .leading, spacing: 16) {
                Text("Wallet").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white).padding(.top, 50)
                VStack(alignment: .leading) {
                    Text("xeerpe").font(.system(.headline, design: .rounded).weight(.heavy))
                    Spacer()
                    Text("•••• 4092").font(.system(.callout, design: .monospaced))
                }
                .foregroundStyle(.black.opacity(0.7)).padding(18).frame(height: 160).frame(maxWidth: .infinity, alignment: .leading)
                .xeerpe(.card(.holographic, .tilt, angle: 16, in: card))
                HStack {
                    VStack(alignment: .leading) {
                        Text("Balance").font(.caption).foregroundStyle(.white.opacity(0.6))
                        Text("€ 12.480,22").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            .xeerpe { .privacy(hidden, blur: 12) }
                    }
                    Spacer()
                    Button { withAnimation(.smooth(duration: 0.4)) { hidden.toggle() } } label: {
                        Image(systemName: hidden ? "eye.slash" : "eye").font(.title3).foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                Text("Hover a row to peek").font(.caption).foregroundStyle(.white.opacity(0.5))
                ForEach([("cup.and.saucer.fill", "Bar Roma", "-3,20"), ("tram.fill", "ATM Milano", "-2,40"),
                         ("cart.fill", "Esselunga", "-48,15"), ("arrow.down.circle.fill", "Stipendio", "+2.140,00")], id: \.1) { r in
                    HStack {
                        Image(systemName: r.0).frame(width: 26)
                        Text(r.1)
                        Spacer()
                        Text(r.2).monospacedDigit()
                    }
                    .font(.system(size: 14)).foregroundStyle(.white).padding(.vertical, 4)
                    .xeerpe { .privacy(.hover(from: 1, to: 0), blur: 7).feedback(.alignment, sound: .tick, on: .enter) }
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .background(Color(white: 0.05))
        }
    }
}

@MainActor
struct CardRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Cards", "card(preset): a reactive preset, a glare and a 3D tilt in one style. Click one.")
            HStack(spacing: 22) {
                ForEach([(XeerpePreset.holographic, "PLATINUM"), (.blackGold, "PRIVÉ"), (.oilSlick, "NIGHT")], id: \.1) { c in
                    VStack(alignment: .leading) {
                        HStack { Text("xeerpe").font(.system(.headline, design: .rounded).weight(.heavy)); Spacer(); Image(systemName: "wave.3.right") }
                        Spacer()
                        Text("•••• •••• •••• 4092").font(.system(.callout, design: .monospaced))
                        Text(c.1).font(.caption.weight(.bold)).tracking(3).opacity(0.8)
                    }
                    .foregroundStyle(c.0.id == "holographic" ? .black.opacity(0.7) : .white).padding(20).frame(height: 180)
                    .xeerpe {
                        .card(c.0, .tilt, angle: 18, in: card)
                        .scale(.press(from: 1, to: 0.96))
                        .feedback(.impact(weight: .medium), sound: .pop, on: .press)
                    }
                }
            }
            CodeView("""
            cardView.xeerpe {
                .card(.holographic, .tilt, angle: 18)
                .scale(.press(from: 1, to: 0.96))
                .feedback(.impact, sound: .pop, on: .press)
            }
            """)
        }
    }
}

@MainActor
struct TapToCash: View {
    /// Two separate jobs: sending on one phone, receiving on the other.
    /// Each has its own progress and its own timing.
    @State private var send = XeerpeJob<Double>()
    @State private var receive = XeerpeJob<Double>()
    @State private var drag: CGFloat = snapshotProgress == nil ? 0 : 40
    @State private var sendScrub: Double? = snapshotProgress
    @State private var receiveScrub: Double? = snapshotProgress.map { max($0 * 1.4 - 0.4, 0) }
    private let gap: CGFloat = 40
    private let scale: CGFloat = 0.72

    private var ps: Double { sendScrub ?? send.progress }
    private var pr: Double { receiveScrub ?? receive.progress }

    private func screen(sending: Bool) -> some View {
        let p = sending ? ps : pr
        let glow = p > 0 && p < 1 ? 1.0 : 0
        return VStack(spacing: 10) {
            Spacer()
            Text("$20").font(.system(size: 124, weight: .semibold).width(.condensed))
                .xeerpeFill(.preset(.chrome, reacting: .tilt, strength: 1.6))
                .overlay { Text("$20").font(.system(size: 124, weight: .semibold).width(.condensed))
                    .xeerpeFill(.preset(.holographic, reacting: .tilt, strength: 1.4)).opacity(0.4).blendMode(.overlay) }
                .xeerpe { .emboss(depth: 3, light: .tilt).bloom(radius: 10, intensity: glow * 0.35) }
                .xeerpeStream(progress: p, toward: .top, reach: 360, inward: !sending, count: 6000,
                              colors: [.white, Color(white: 0.8), Color(red: 1, green: 0.9, blue: 0.95), Color(red: 0.85, green: 0.95, blue: 1)])
            Text("“Breakfast”").font(.system(.headline, design: .rounded)).foregroundStyle(.white)
            Text(sending ? (send.phase == .done ? "Sent to Dan" : "To Dan") : "From Daniele")
                .font(.callout).foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.035, green: 0.07, blue: 0.065))
        .xeerpe {
            .starfield(count: 160, color: Color(red: 0.85, green: 0.95, blue: 0.95), speed: 0.8, tilt: .tilt)
            .edgeGlow(XeerpeGlow.ice, intensity: glow * 0.45, width: 3, in: RoundedRectangle(cornerRadius: 46, style: .continuous))
        }
        .overlay(alignment: .top) {
            RadialGradient(colors: [.white.opacity(0.55), Color(red: 0.7, green: 0.85, blue: 1).opacity(0.18), .clear],
                           center: .top, startRadius: 0, endRadius: 110)
                .frame(width: 220, height: 120).blendMode(.plusLighter).opacity(glow).allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.4), value: glow)
    }

    private func phone(sending: Bool) -> some View {
        Phone { screen(sending: sending) }
            .scaleEffect(scale).frame(width: 298 * scale, height: 618 * scale)
            .rotationEffect(.degrees(sending ? 90 : -90))
            .frame(width: 618 * scale, height: 298 * scale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Tap to Cash", "Drag the left phone until the tops touch, or press Tap. The sender's $20 streams out toward the top; a moment later, on its own timing, the receiver's streams in and forms. Nothing crosses between the phones.")
            HStack(spacing: gap - drag) {
                phone(sending: true)
                    .xeerpe { .feedback(.impact(weight: .heavy), sound: .pop, on: .entered(.pending, of: send)) }
                    .gesture(DragGesture()
                        .onChanged { v in
                            guard send.phase == .idle else { return }
                            drag = min(max(v.translation.width, 0), gap)
                            if drag >= gap - 4 { tap() }
                        }
                        .onEnded { _ in if send.phase == .idle { withAnimation(.spring(duration: 0.4)) { drag = 0 } } })
                phone(sending: false)
                    .xeerpe { .feedback(.success, sound: .glass, on: .entered(.done, of: receive)) }
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 14) {
                Button(send.phase == .idle && sendScrub == nil ? "Tap" : "Again") { send.phase == .idle && sendScrub == nil ? bring() : reset() }
                    .buttonStyle(PillButtonStyle())
                scrubber("send", value: ps) { sendScrub = $0; drag = gap }
                scrubber("receive", value: pr) { receiveScrub = $0; drag = gap }
            }
            CodeView("""
            // Sender: its own job.
            amount.xeerpeStream(progress: .progress(send), toward: .top)
            // Receiver: another job, started when the payment arrives.
            amount.xeerpeStream(progress: .progress(receive), toward: .top, inward: true)
            receiver.xeerpe { .feedback(.success, sound: .glass, on: .entered(.done, of: receive)) }
            """)
        }
    }

    private func scrubber(_ name: String, value: Double, set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(name).font(.system(.caption, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            Slider(value: Binding(get: { value }, set: set), in: 0...1)
            Text(String(format: "%.2f", value)).font(.system(.caption, design: .monospaced)).foregroundStyle(.cyan).frame(width: 36)
        }
    }

    private func bring() {
        withAnimation(.easeIn(duration: 0.4)) { drag = gap }
        Task { try? await Task.sleep(for: .milliseconds(400)); tap() }
    }

    private func tap() {
        guard send.phase == .idle else { return }
        drag = gap
        let receive = receive
        send.run { report in
            for k in 1...110 {
                try await Task.sleep(for: .milliseconds(16))
                await report(Double(k) / 110)
                // The payment reaches the other phone partway through.
                if k == 45 { await MainActor.run { Self.arrive(receive) } }
            }
            return 20
        }
    }

    private static func arrive(_ job: XeerpeJob<Double>) {
        job.run { report in
            for k in 1...130 {
                try await Task.sleep(for: .milliseconds(16))
                await report(Double(k) / 130)
            }
            return 20
        }
    }

    private func reset() {
        sendScrub = nil; receiveScrub = nil
        send.cancel(); receive.cancel()
        withAnimation(.spring(duration: 0.5)) { drag = 0 }
    }
}

@MainActor
private func metalFace(ink: Color = .black.opacity(0.65)) -> some View {
    VStack(alignment: .leading) {
        HStack {
            Text("xeerpe").font(.system(.title3, design: .rounded).weight(.heavy))
            Spacer()
            Image(systemName: "wave.3.right").font(.title3)
        }
        Spacer()
        Text("5412 7700 1234 8890").font(.system(.callout, design: .monospaced).weight(.semibold))
        HStack { Text("D. ROSSI"); Spacer(); Text("09/31") }.font(.system(.caption, design: .monospaced))
    }
    .foregroundStyle(ink).padding(20).frame(height: 190)
}

@MainActor
struct MetalCardDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Metal card", "Finishes go in a backdrop: they shape the metal behind the text, never the text. Titanium, then brushed grain, then polished edges, then the preset turning in 3D.")
            HStack(alignment: .top, spacing: 14) {
                step("card.xeerpe {\n    .backdrop { .preset(.titanium, reacting: .tilt, in: shape) }\n}") {
                    metalFace().xeerpe { .backdrop { .preset(.titanium, reacting: .tilt, in: card) } }
                }
                step("    .backdrop { ... .brushed() }") {
                    metalFace().xeerpe { .backdrop { .preset(.titanium, reacting: .tilt, in: card).brushed() } }
                }
            }
            HStack(alignment: .top, spacing: 14) {
                step("    .backdrop { ... .brushed().bevel() }") {
                    metalFace().xeerpe { .backdrop { .preset(.titanium, reacting: .tilt, in: card).brushed().bevel() } }
                }
                step("card.xeerpe(.metalCard(in: shape))") { metalFace().xeerpe(.metalCard(in: card)) }
            }
            HStack(alignment: .top, spacing: 14) {
                step("card.xeerpe(.metalCard(.blackGold, in: shape))") {
                    metalFace(ink: Color(red: 0.95, green: 0.85, blue: 0.6)).xeerpe(.metalCard(.blackGold, in: card))
                }
                step("card.xeerpe {\n    .backdrop { .preset(.titanium, reacting: .tilt, in: shape)\n        .brushed(radial: true).bevel() }\n    .tilt3D(.tilt)\n}") {
                    metalFace().xeerpe {
                        .backdrop { .preset(.titanium, reacting: .tilt, in: card).brushed(radial: true).bevel() }
                        .tilt3D(.tilt)
                    }
                }
            }
        }
    }
}

@MainActor
struct SendGift: View {
    @State private var job = XeerpeJob<Double>()

    private func card() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "gift.fill").font(.title2)
            Spacer()
            Text("€ 25").font(.system(size: 30, weight: .bold, design: .rounded))
            Text("Gift card").font(.caption).opacity(0.7)
        }
        .foregroundStyle(.white).padding(14).frame(width: 150, height: 96, alignment: .leading)
        .background(LinearGradient(colors: [Color(red: 1, green: 0.45, blue: 0.4), Color(red: 0.85, green: 0.2, blue: 0.55)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func friend() -> some View {
        VStack(spacing: 6) {
            Circle().fill(LinearGradient(colors: [.teal, .blue], startPoint: .top, endPoint: .bottom))
                .overlay { Text("MR").font(.system(.headline, design: .rounded)).foregroundStyle(.white) }
                .frame(width: 64, height: 64)
            Text("Marta").font(.callout).foregroundStyle(.white.opacity(0.8))
        }
    }

    /// The row at `stage`: 1 dissolves the card, 2 also forms it again by
    /// the friend, 3 also flies the particles between them.
    private func row(_ stage: Int) -> some View {
        HStack(spacing: 0) {
            card().xeerpe { .transferSource(progress: .progress(job)) }
            Spacer()
            Image(systemName: "chevron.right.2").foregroundStyle(.white.opacity(0.25))
            Spacer()
            HStack(spacing: 14) {
                friend()
                card().scaleEffect(0.6).frame(width: 90, height: 58).xeerpe { if stage >= 2 { .transferTarget(progress: .progress(job)) } }
            }
        }
        .padding(.horizontal, 40).padding(.vertical, 18)
        .background(Color(white: 0.1), in: tile)
        .xeerpe { if stage >= 3 { .transfer(progress: .progress(job), colors: [.white, .pink, .orange]) } }
    }

    private func send() {
        job.run { report in
            for k in 1...110 {
                try await Task.sleep(for: .milliseconds(16))
                await report(Double(k) / 110)
            }
            return 25
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Send a gift", "The card turns to dust, forms again by the friend, and the dust flies between them. One job drives all three. Press Send.")
            step("card.xeerpe { .transferSource(progress: .progress(job)) }") { row(1) }
            step("received.xeerpe { .transferTarget(progress: .progress(job)) }") { row(2) }
            step("row.xeerpe { .transfer(progress: .progress(job), colors: [.white, .pink, .orange]) }") { row(3) }
            Button(job.phase == .done ? "Send again" : "Send") { send() }.buttonStyle(PillButtonStyle())
        }
    }
}

@MainActor
struct TicketDemo: View {
    private func ticket(_ strip: XeerpeChain) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("NEON HARBOR").font(.system(.title3, design: .rounded).weight(.heavy))
                Text("Live at the Docks").font(.callout).opacity(0.7)
                Spacer()
                Text("12 JUL · 21:00").font(.system(.callout, design: .monospaced))
                Text("GATE B · ROW 14 · SEAT 22").font(.system(.caption, design: .monospaced)).opacity(0.7)
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(LinearGradient(colors: [Color(white: 0.8), Color(white: 0.5)], startPoint: .top, endPoint: .bottom))
                .frame(width: 44)
                .xeerpe(strip)
        }
        .foregroundStyle(.white).frame(height: 170)
        .background(Color(red: 0.12, green: 0.1, blue: 0.22))
        .clipShape(tile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Ticket", "A security strip in holo foil that shifts with the light, then glints, then the whole ticket turning. Move the pointer over them.")
            HStack(alignment: .top, spacing: 14) {
                step("strip.xeerpe { .holo() }") { ticket(XeerpeChain { .holo() }) }
                step("strip.xeerpe { .holo().sparkle(density: 0.4) }") { ticket(XeerpeChain { .holo().sparkle(density: 0.4) }) }
                step("ticket.xeerpe { .tilt3D(.tilt, angle: 8) }") {
                    ticket(XeerpeChain { .holo().sparkle(density: 0.4) }).xeerpe { .tilt3D(.tilt, angle: 8) }
                }
            }
        }
    }
}
#endif
