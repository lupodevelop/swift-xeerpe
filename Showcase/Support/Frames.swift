#if os(macOS)
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import xeerpe

// Scenes for the website, drawn offscreen frame by frame. Each frame is the
// scene at progress p in 0...1: time, tilt, touch and taps are computed from
// p and handed to the effects, so nothing reads the clock or the pointer and
// the same p always gives the same picture. The site scrubs them with scroll.

struct Scene {
    let size: CGSize
    let frames: Int
    let draw: @MainActor (Double) -> AnyView
}

private let canvas = Color(red: 0.02, green: 0.02, blue: 0.03)
private let cardShape = RoundedRectangle(cornerRadius: 22, style: .continuous)

/// Smooth 0...1 ease, so motion starts and ends at rest.
private func ease(_ t: Double) -> Double { let t = min(max(t, 0), 1); return t * t * (3 - 2 * t) }

@MainActor
let scenes: [String: Scene] = [
    "card": Scene(size: CGSize(width: 800, height: 450), frames: 120) { p in
        let card = CGSize(width: 340, height: 214)
        let a = p * .pi * 2
        let ctx = XeerpeContext(time: p * 6, size: card, tilt: CGPoint(x: sin(a) * 0.9, y: cos(a) * 0.5))
        return AnyView(VStack(alignment: .leading) {
            HStack { Text("xeerpe").font(.system(.headline).weight(.heavy)); Spacer(); Image(systemName: "wave.3.right") }
            Spacer()
            Text("•••• •••• •••• 4092").font(.system(.callout, design: .monospaced))
            Text("PLATINUM").font(.system(size: 10, weight: .semibold)).tracking(2).opacity(0.7)
        }
        .foregroundStyle(.black.opacity(0.75)).padding(20).frame(width: card.width, height: card.height)
        .xeerpe(.card(.holographic, .tilt, angle: 22, in: cardShape), at: ctx)
        .frame(width: 800, height: 450).background(canvas))
    },
    // Aurora flowing while a finger draws a slow loop over it.
    "aurora": Scene(size: CGSize(width: 800, height: 450), frames: 150) { p in
        let size = CGSize(width: 800, height: 450)
        let a = p * .pi * 2
        let ctx = XeerpeContext(time: p * 14, size: size, touch: CGPoint(x: sin(a) * 0.6, y: sin(a * 2) * 0.4),
                                focus: CGPoint(x: sin(a) * 0.6, y: sin(a * 2) * 0.4), presence: 1)
        return AnyView(Color.clear.frame(width: size.width, height: size.height).xeerpe(.aurora(), at: ctx))
    },
    // Three drops on still water.
    "pond": Scene(size: CGSize(width: 800, height: 450), frames: 150) { p in
        let size = CGSize(width: 800, height: 450)
        let time = p * 9
        let drops = [(0.4, CGPoint(x: 275, y: 190)), (3.4, CGPoint(x: 540, y: 275)), (6.2, CGPoint(x: 400, y: 150))]
        let tap = drops.last { $0.0 <= time }.map { XeerpeTap(location: $0.1, time: $0.0) }
        let ctx = XeerpeContext(time: time, tap: tap, size: size)
        return AnyView(VStack(spacing: 6) {
            Text("Still water").font(.system(size: 80, weight: .bold))
            Text("until something touches it").font(.title3).opacity(0.8)
        }
        .foregroundStyle(.white).frame(width: size.width, height: size.height).xeerpe(.pond(), at: ctx))
    },
    // Content pouring in from the center.
    "reveal": Scene(size: CGSize(width: 800, height: 450), frames: 120) { p in
        let size = CGSize(width: 800, height: 450)
        let still = XeerpeContext(time: 2, size: size)
        let ctx = XeerpeContext(time: p * 4, size: size)
        return AnyView(VStack(alignment: .trailing, spacing: 10) {
            Spacer()
            Text("Now playing").font(.callout).opacity(0.8)
            Text("Midnight Tide").font(.system(size: 52, weight: .bold))
            Text("A long drive home, the city fading in the mirror.").font(.title3).opacity(0.85)
        }
        .multilineTextAlignment(.trailing)
        .foregroundStyle(.white).padding(.horizontal, 48).padding(.bottom, 120)
        .frame(width: size.width, height: size.height, alignment: .trailing)
        .xeerpe(.preset(.synthwave), at: still)
        .xeerpe(.fluidReveal(progress: ease(p), glow: .cyan), at: ctx)
        .background(canvas))
    },
]

/// Pixels per point: 2400 px wide frames stay sharp on a large retina screen.
private let frameScale: CGFloat = 3

/// Writes every frame of a scene as numbered PNGs into `dir`.
@MainActor
func renderFrames(_ name: String, into dir: URL) throws {
    guard let scene = scenes[name] else {
        print("unknown scene \(name); known: \(scenes.keys.sorted().joined(separator: " "))"); exit(2)
    }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for i in 0..<scene.frames {
        let p = Double(i) / Double(scene.frames - 1)
        let renderer = ImageRenderer(content: scene.draw(p).environment(\.colorScheme, .dark))
        renderer.scale = frameScale
        guard let image = renderer.cgImage,
              let out = CGImageDestinationCreateWithURL(dir.appendingPathComponent(String(format: "%04d.png", i + 1)) as CFURL,
                                                        UTType.png.identifier as CFString, 1, nil) else {
            print("render failed at frame \(i)"); exit(1)
        }
        CGImageDestinationAddImage(out, image, nil)
        guard CGImageDestinationFinalize(out) else { print("write failed at frame \(i)"); exit(1) }
    }
    print("frames \(scene.frames) \(Int(scene.size.width * frameScale)) \(Int(scene.size.height * frameScale))")
}
#endif
