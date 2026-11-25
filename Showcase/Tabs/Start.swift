#if os(macOS)
import SwiftUI
import xeerpe

// How a chain works: one effect per tile, then whole screens built from them,
// then an effect written with the app's own Metal shader.

@MainActor
private func hudLabel(_ text: String, _ color: Color) -> some View {
    HStack(spacing: 5) {
        Circle().fill(color).frame(width: 7, height: 7)
        Text(text).font(.system(.caption2, design: .monospaced).weight(.bold))
    }
    .foregroundStyle(.white.opacity(0.9)).padding(10)
}

@MainActor
struct DeviceScreens: View {
    /// An old desktop window: title bar, an icon and a line of text.
    private func window() -> some View {
        VStack(spacing: 0) {
            HStack {
                Rectangle().fill(.black).frame(width: 10, height: 10)
                Spacer()
                Text("Untitled").font(.system(.caption, design: .monospaced).weight(.bold))
                Spacer()
            }
            .padding(.horizontal, 8).frame(height: 22).background(Color(white: 0.85))
            HStack(spacing: 14) {
                Image(systemName: "photo.artframe").font(.system(size: 50))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome").font(.system(.title3, design: .serif).bold())
                    Text("Dithered in two tones.").font(.caption)
                }
            }
            .foregroundStyle(.black).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LinearGradient(colors: [.white, Color(white: 0.55)], startPoint: .top, endPoint: .bottom))
        }
        .frame(height: 170).clipShape(tile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Screens", "The same photo through a scope, a heat camera and a terminal; a window in 1-bit. The labels sit outside the chain, so they stay sharp. These four looks are showcase recipes written with the public API: copy them into your app.")
            HStack(alignment: .top, spacing: 14) {
                step("photo.xeerpe(.nightVision())") {
                    photo().xeerpe(.nightVision()).clipShape(tile).overlay(alignment: .topLeading) { hudLabel("REC  CAM 02", .red) }
                }
                step("photo.xeerpe(.thermal())") {
                    photo().xeerpe(.thermal()).clipShape(tile).overlay(alignment: .topTrailing) { hudLabel("38.4 °C", .orange) }
                }
                step("photo.xeerpe(.terminal())") { photo().xeerpe(.terminal()) }
            }
            HStack(alignment: .top, spacing: 14) {
                step("window.xeerpe(.oneBit())") { window().xeerpe(.oneBit()) }
                step("photo.xeerpe { .ascii(cell: 7, colored: true) }") { photo().xeerpe { .ascii(cell: 7, colored: true) } }
                step("photo.xeerpe(.oneBit(pixel: 3)\n    .adding { .scanlines(spacing: 3, intensity: 0.2) })") {
                    photo().xeerpe(.oneBit(pixel: 3).adding { .scanlines(spacing: 3, intensity: 0.2) })
                }
            }
        }
    }
}

@MainActor
struct CRTDemo: View {
    private func screen() -> some View {
        VStack(spacing: 6) {
            Text("HIGH SCORE").font(.system(.caption, design: .monospaced)).opacity(0.7)
            Text("028 450").font(.system(size: 34, weight: .heavy, design: .monospaced))
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                Text("PRESS START").font(.system(.callout, design: .monospaced))
            }
            .foregroundStyle(Color(red: 1, green: 0.8, blue: 0.2))
        }
        .foregroundStyle(Color(red: 0.4, green: 1, blue: 0.7))
        .frame(maxWidth: .infinity).frame(height: 150)
        .background(LinearGradient(colors: [Color(red: 0.05, green: 0.08, blue: 0.2), Color(red: 0.2, green: 0.05, blue: 0.25)],
                                   startPoint: .top, endPoint: .bottom))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("CRT", "A shader engine is a chain: each piece is one effect, a preset puts them in order, and you can take any piece out.")
            HStack(alignment: .top, spacing: 14) {
                step("screen.xeerpe { .scanlines() }") { screen().xeerpe { .scanlines() } }
                step("+ .phosphor()") { screen().xeerpe { .scanlines().phosphor() } }
                step("+ .barrel(0.12).vignette(0.45)") { screen().xeerpe { .scanlines().phosphor().barrel(0.12).vignette(0.45) } }
            }
            HStack(alignment: .top, spacing: 14) {
                step("screen.xeerpe(.crt())") { screen().xeerpe(.crt()) }
                step("screen.xeerpe(.crt(roll: 1).without(.vignette))") { screen().xeerpe(.crt(roll: 1).without(.vignette)) }
                step("screen.xeerpe(.crt(curvature: .hover(from: 0.25, to: 0)))") {
                    screen().xeerpe(.crt(curvature: XeerpeValue.hover(from: 0.25, to: 0)))
                }
            }
        }
    }
}

@MainActor
struct BasicsGrid: View {
    @State private var duo = snapshotProgress ?? 0.6

    private func face(_ title: String) -> some View {
        Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 110)
    }

    private func filled(_ title: String) -> some View {
        face(title).xeerpe(XeerpeCatalog["aurora-dream"]!.style(in: tile))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Basics", "One tile per basic effect. Hover, tap and move the pointer over them.")
            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow {
                    step(".gradient(.aurora, in: tile)") { face("Gradient").xeerpe { .gradient(.aurora, in: tile) } }
                    step(".blur(.hover(from: 6, to: 0))") { filled("Blur").xeerpe { .blur(.hover(from: 6, to: 0)) } }
                    step(".pulse(period: 1.2)") { filled("Pulse").xeerpe { .pulse(period: 1.2) } }
                }
                GridRow {
                    step(".glare(.tilt, in: tile)") { filled("Glare").xeerpe { .glare(.tilt, in: tile) } }
                    step(".ripple()") { filled("Tap me").xeerpe { .ripple() } }
                    step(".glass(in: tile)") {
                        face("Glass").xeerpe { .glass(in: tile) }
                            .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing).clipShape(tile))
                    }
                }
                GridRow {
                    step(".focusReveal()") { filled("Focus").xeerpe { .focusReveal() } }
                    step(".dotField(origin: .bottom)") { face("Dots").xeerpe { .dotField(origin: .bottom) }.background(Color(white: 0.1)).clipShape(tile) }
                    step(".duo(progress: .binding($duo))") {
                        VStack(spacing: 6) {
                            filled("Duo").xeerpe { .duo(progress: .binding($duo)) }
                            Slider(value: $duo, in: 0...1)
                        }
                    }
                }
            }
        }
    }
}

@MainActor
struct ScannerDemo: View {
    private func receipt() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Caffè Brera").font(.system(.headline, design: .serif))
            Text("Via Fiori Chiari 12, Milano").font(.caption).opacity(0.6)
            Divider().overlay(Color.black.opacity(0.3))
            ForEach([("Cappuccino", "1,80"), ("Brioche", "1,50"), ("Spremuta", "3,50")], id: \.0) { item in
                HStack { Text(item.0); Spacer(); Text(item.1) }.font(.system(.callout, design: .monospaced))
            }
            Divider().overlay(Color.black.opacity(0.3))
            HStack { Text("TOTALE").bold(); Spacer(); Text("€ 6,80").bold() }.font(.system(.callout, design: .monospaced))
        }
        .foregroundStyle(Color(red: 0.2, green: 0.15, blue: 0.1))
        .padding(16).frame(height: 210)
        .background(LinearGradient(colors: [Color(red: 1, green: 0.96, blue: 0.86), Color(red: 0.93, green: 0.86, blue: 0.72)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), in: tile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Your own shader", "A receipt scanner drawn by a Metal function of the app, declared once with XeerpeEffect.shader. From then on it chains and takes signals like any effect of the library.")
            CodeView("""
            extension XeerpeEffect {
                static func scan(_ progress: XeerpeValue) -> XeerpeEffect {
                    .shader("scan", claims: ["scan"], inputs: progress.inputs) { ctx in
                        let p = progress.value(in: ctx)
                        return .color(ShaderLibrary.bundle(.module).scan(.boundingRect, .float(p)), enabled: p > 0)
                    }
                }
            }
            """)
            HStack(alignment: .top, spacing: 14) {
                step("receipt.xeerpe { .scan(0.55) }") { receipt().xeerpe { .scan(0.55) } }
                step("receipt.xeerpe {\n    .scan(.time(period: 3, wave: .loop))\n}") { receipt().xeerpe { .scan(.time(period: 3, wave: .loop)) } }
                step("receipt.xeerpe {\n    .scan(.time(period: 3, wave: .loop))\n    .grain(0.15).vignette(0.3)\n}") {
                    receipt().xeerpe { .scan(.time(period: 3, wave: .loop)).grain(0.15).vignette(0.3) }
                }
            }
        }
    }
}
#endif
