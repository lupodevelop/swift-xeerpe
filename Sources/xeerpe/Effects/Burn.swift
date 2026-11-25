import SwiftUI

/// Animatable, so a change of `progress` under `withAnimation` burns frame
/// by frame instead of jumping.
struct XeerpeBurnView: View, Animatable {
    let content: AnyView
    nonisolated(unsafe) var progress: Double
    let edge: Color

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = Xeerpe.clampUnit(progress)
        #if os(watchOS)
        content.opacity(1 - p)
        #else
        content
            .colorEffect(XeerpeShaders.library.xeerpeBurn(.boundingRect, .float(p), .color(edge)), isEnabled: p > 0)
            .allowsHitTesting(Xeerpe.revealIsInteractive(1 - p))
            .accessibilityHidden(!Xeerpe.revealIsInteractive(1 - p))
        #endif
    }
}

extension XeerpeEffect {
    /// Burns the content away from the bottom up as `progress` goes 0 to 1:
    /// a ragged front glowing in `edge`, charred ahead of it, flaking into
    /// ash behind. Change `progress` inside `withAnimation`; past half way
    /// the content stops taking touches and leaves the accessibility tree.
    public static func burn(progress: XeerpeValue, edge: Color = Color(red: 1, green: 0.42, blue: 0.08)) -> XeerpeEffect {
        XeerpeEffect(name: "burn", slot: .mask, claims: [.burn], inputs: progress.inputs) { view, ctx in
            AnyView(XeerpeBurnView(content: view, progress: progress.value(in: ctx), edge: edge))
        }
    }

    /// Sparks that rise up to `height` points from the content's top and
    /// bottom edges, flickering and fading as they climb. After `burn` they
    /// rise from the burning front. `amount` 0...1 is how many. Keeps frames
    /// running, so add it only while it should show: `if burning { .embers() }`.
    /// Off under Reduce Motion and on watchOS.
    public static func embers(_ amount: XeerpeValue = 1, color: Color = Color(red: 1, green: 0.5, blue: 0.12), height: Double = 36) -> XeerpeEffect {
        let inputs = amount.inputs.union(.time)
        #if os(watchOS)
        return .passthrough("embers", slot: .overlay, claims: [.embers], inputs: inputs)
        #else
        let h = height.isFinite ? max(height, 4) : 36
        return .shader("embers", slot: .overlay, claims: [.embers], inputs: inputs) { ctx in
            let a = Xeerpe.clampUnit(amount.value(in: ctx))
            return .layer(XeerpeShaders.library.xeerpeEmbers(.boundingRect, .float(ctx.shaderTime), .float(a), .float(h), .color(color)),
                          maxSampleOffset: CGSize(width: 8, height: h + 8), enabled: a > 0 && !ctx.reduceMotion)
        }
        #endif
    }
}
