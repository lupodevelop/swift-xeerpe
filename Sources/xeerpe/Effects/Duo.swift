import SwiftUI

/// The edge a fold hinges on: blur and darkness start at zero there and
/// grow toward the opposite edge.
public enum XeerpeEdge: Int, Sendable {
    case leading = 0, trailing, top, bottom
}

/// The screen effect of a folding phone: a progressive blur (up to
/// `maxBlur` points) and a darkening toward black that both grow across the
/// surface away from the hinge, scaled by `progress` 0...1. `fold` tilts the
/// view in perspective up to that many degrees around the hinge.
/// Animatable, so a `progress` binding changed under `withAnimation`
/// glides; any signal (tilt, drag, touch, time) can drive it directly.
struct XeerpeDuoView: View, Animatable {
    let content: AnyView
    nonisolated(unsafe) var progress: Double
    let edge: XeerpeEdge
    let maxBlur: Double
    let fold: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = Xeerpe.clampUnit(progress)
        let motion = p * p * (3 - 2 * p)
        let axis: (x: CGFloat, y: CGFloat, z: CGFloat) = edge == .leading || edge == .trailing ? (0, 1, 0) : (1, 0, 0)
        let sign: Double = edge == .leading || edge == .bottom ? 1 : -1   // the far edge recedes
        let anchor: UnitPoint = [.leading, .trailing, .top, .bottom][edge.rawValue]
        #if os(watchOS)
        // No shaders on watchOS: the darkening only.
        let shaded = content.overlay(LinearGradient(colors: [.clear, .black.opacity(min(1, 2 * motion))],
                                                    startPoint: anchor, endPoint: UnitPoint(x: 1 - anchor.x, y: 1 - anchor.y)).allowsHitTesting(false))
        #else
        let shaded = content.layerEffect(
            XeerpeShaders.library.xeerpeDuo(.boundingRect, .float(Float(p)), .float(Float(edge.rawValue)), .float(Float(max(maxBlur, 0)))),
            maxSampleOffset: CGSize(width: maxBlur, height: maxBlur))
        #endif
        return shaded.rotation3DEffect(.degrees(sign * fold * motion), axis: axis, anchor: anchor, perspective: 0.55)
    }
}

extension XeerpeEffect {
    /// The folding-phone screen effect. Drive `progress` with any signal,
    /// for example `XeerpeVector.drag.x.mapped(to: 0, 1)`; `fold` is the
    /// largest turn in degrees (28 reads as a folding phone), 0 keeps the
    /// screen flat.
    public static func duo(progress: XeerpeValue, from edge: XeerpeEdge = .leading, maxBlur: Double = 72, fold: Double = 0) -> XeerpeEffect {
        XeerpeEffect(name: "duo", slot: .content, claims: [.duo], inputs: progress.inputs) { view, ctx in
            AnyView(XeerpeDuoView(content: view, progress: progress.value(in: ctx), edge: edge, maxBlur: maxBlur, fold: fold))
        }
    }
}
