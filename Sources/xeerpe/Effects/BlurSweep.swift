import SwiftUI

extension Xeerpe {
    /// How blurred a point is (0 sharp, 1 fully) at position `s` (0...1
    /// along the sweep) when the front is at `progress`. Mirrors the shader.
    static func sweepAmount(_ s: Double, progress: Double, band: Double) -> Double {
        let b = max(band, 0.001)
        let front = -b + (1 + 2 * b) * clampUnit(progress)
        let t = clampUnit((s - (front - b)) / (2 * b))
        return 1 - t * t * (3 - 2 * t)
    }
}

/// Animatable, so a change of `progress` under `withAnimation` sweeps frame
/// by frame and can be reversed mid-way.
struct XeerpeBlurSweepView: View, Animatable {
    let content: AnyView
    nonisolated(unsafe) var progress: Double
    let angle: Double
    let maxBlur: Double
    let band: Double
    let darken: Double
    /// Reduce Transparency: no blur, the content dims to black behind the front.
    var opaque = false

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = Xeerpe.clampUnit(progress)
        let maxBlur = opaque ? 0 : maxBlur, darken = opaque ? 1 : darken
        #if os(watchOS)
        content.blur(radius: maxBlur * p).brightness(-darken * p * (opaque ? 1 : 0.5))
        #else
        content
            .layerEffect(XeerpeShaders.library.xeerpeBlurSweep(
                .boundingRect, .float(Float(p)), .float(Float(angle * .pi / 180)), .float(Float(max(maxBlur, 0))),
                .float(Float(max(band, 0.001))), .float(Float(Xeerpe.clampUnit(darken)))),
                maxSampleOffset: CGSize(width: maxBlur, height: maxBlur))
            .allowsHitTesting(p < 0.5)
            .accessibilityHidden(p >= 0.5)
        #endif
    }
}

extension XeerpeEffect {
    /// A progressive blur that sweeps across the view: as `progress` goes
    /// 0 to 1 a soft front travels along `angle` (degrees: 0 left to right,
    /// 90 top to bottom), blurring up to `maxBlur` points and dimming by
    /// `darken` behind it. Going back to 0 shows the content again the same
    /// way. Drive it with a binding inside `withAnimation`, a drag, a job.
    public static func blurSweep(progress: XeerpeValue, angle: Double = 90, maxBlur: Double = 28, band: Double = 0.35,
                                 darken: Double = 0.35) -> XeerpeEffect {
        XeerpeEffect(name: "blurSweep", slot: .content, claims: [.blur], inputs: progress.inputs) { view, ctx in
            AnyView(XeerpeBlurSweepView(content: view, progress: progress.value(in: ctx), angle: angle, maxBlur: maxBlur, band: band, darken: darken,
                                        opaque: ctx.reduceTransparency))
        }
    }
}
