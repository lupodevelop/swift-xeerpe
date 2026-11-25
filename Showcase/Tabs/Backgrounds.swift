#if os(macOS)
import SwiftUI
import xeerpe

// Surfaces: backgrounds made of layers, still or moving.

@MainActor
struct Surfaces: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Demo("aurora", hint: "pointer pulls the flow", code: "view.xeerpe(.aurora(in: shape))") {
                label("xeerpe", "a preset: .aurora()").xeerpe(.aurora(in: shape))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 400), spacing: 28)], alignment: .leading, spacing: 32) {
                Demo("magnifier", hint: "hover", code: "view.xeerpe(.magnifier(in: shape))") {
                    VStack(spacing: 8) {
                        Text("Look closer").font(.system(size: 44, weight: .heavy, design: .rounded))
                        Text("A glass lens follows the pointer and magnifies what is under it.")
                            .font(.callout).multilineTextAlignment(.center).padding(.horizontal, 30).opacity(0.85)
                    }
                    .foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .xeerpe(.magnifier(in: shape))
                }
                Demo("pond", hint: "click anywhere", code: "view.xeerpe(.pond(in: shape))") {
                    label("Tap", "the wave bends the liquid too").xeerpe(.pond(in: shape))
                }
                Demo("lava", hint: "hover, then click", code: "view.xeerpe(.lava(in: shape))") {
                    label("72°", "hot").xeerpe(.lava(in: shape))
                }
                Demo("glassPill", hint: "native Liquid Glass over a live background", code: "view.xeerpe(.aurora(speed: 1.2, in: shape))\npill.xeerpe(.glassPill())") {
                    HStack(spacing: 14) {
                        ForEach(["Play", "Share", "More"], id: \.self) { t in
                            Text(t).font(.system(.headline, design: .rounded)).foregroundStyle(.white)
                                .padding(.horizontal, 26).padding(.vertical, 16)
                                .xeerpe(.glassPill())
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .xeerpe(.aurora(speed: 1.2, in: shape))
                }
                Demo("compose your own", hint: "hover", code: "view.xeerpe { .liquid(.ocean, speed: 0.6, in: shape).lens(radius: 70) }") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 22) {
                        ForEach(["flame.fill", "bolt.fill", "heart.fill", "star.fill", "moon.fill", "cloud.fill",
                                 "leaf.fill", "drop.fill", "wind", "sun.max.fill", "snowflake", "sparkles"], id: \.self) {
                            Image(systemName: $0).font(.system(size: 28)).foregroundStyle(.white)
                        }
                    }
                    .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .xeerpe { .liquid(.ocean, speed: 0.6, in: shape).lens(radius: 70) }
                }
                Demo("edit a preset", hint: "chains stay editable", code: "view.xeerpe(.pond(in: shape)\n    .without(.distortion).adding { .lens() })") {
                    label("Remix", "pond without the ripple, plus a lens").xeerpe(
                        XeerpeChain.pond(in: shape).without(.distortion).adding { .lens(radius: 80) })
                }
            }
        }
    }
}
#endif
