import SwiftUI

/// A number signal: what most effect parameters take.
public typealias XeerpeValue = XeerpeSignal<Double>

/// Colors for the gradient primitive.
public struct XeerpeGradient: Sendable {
    public var colors: [Color]
    public init(colors: [Color]) { self.colors = colors }
    /// Indigo, purple and teal.
    public static var aurora: XeerpeGradient { XeerpeGradient(colors: [.indigo, .purple, .teal]) }
}

/// Every numeric parameter takes a signal; a literal is a constant signal.
/// Out-of-range values are clamped (NaN becomes 0) and documented per effect.
extension XeerpeEffect {
    /// Content opacity, clamped to 0...1.
    public static func opacity(_ value: XeerpeValue) -> XeerpeEffect {
        XeerpeEffect(name: "opacity", slot: .content, claims: [.opacity], inputs: value.inputs) { view, ctx in
            AnyView(view.opacity(Xeerpe.clampUnit(value.value(in: ctx))))
        }
    }

    /// Gaussian blur radius in points, clamped to 0...
    public static func blur(_ radius: XeerpeValue) -> XeerpeEffect {
        XeerpeEffect(name: "blur", slot: .content, claims: [.blur], inputs: radius.inputs) { view, ctx in
            AnyView(view.blur(radius: Xeerpe.clampNonNegative(radius.value(in: ctx))))
        }
    }

    /// Visual scale only; layout size is unchanged. Clamped to 0...
    public static func scale(_ factor: XeerpeValue, anchor: UnitPoint = .center) -> XeerpeEffect {
        XeerpeEffect(name: "scale", slot: .geometry, claims: [.scale], inputs: factor.inputs) { view, ctx in
            AnyView(view.scaleEffect(Xeerpe.clampNonNegative(factor.value(in: ctx)), anchor: anchor))
        }
    }

    /// Colored shadow around the content's rendered shape; radius clamped to 0...
    public static func glow(_ color: Color, radius: XeerpeValue = 12) -> XeerpeEffect {
        XeerpeEffect(name: "glow", slot: .content, claims: [.shadow], inputs: radius.inputs) { view, ctx in
            AnyView(view.shadow(color: color, radius: Xeerpe.clampNonNegative(radius.value(in: ctx))))
        }
    }

    /// Linear gradient behind the content, clipped to `shape` (default: the
    /// full rectangle). Pass the content's own shape to keep rounded corners;
    /// effects after it, such as `glow`, then follow that shape too.
    /// `angle` is in degrees, clockwise from the +x axis; the default 45 runs
    /// top-leading to bottom-trailing.
    public static func gradient(
        _ g: XeerpeGradient,
        angle: XeerpeValue = 45,
        in shape: some Shape = Rectangle()
    ) -> XeerpeEffect {
        let clip = AnyShape(shape)
        return gradient(.constant(g.colors), angle: angle, in: XeerpeShapeSignal { _ in clip })
    }

    /// Fixed palette, outline that changes (for example `.superellipse(...)`).
    public static func gradient(_ g: XeerpeGradient, angle: XeerpeValue = 45, in shape: XeerpeShapeSignal) -> XeerpeEffect {
        gradient(.constant(g.colors), angle: angle, in: shape)
    }

    /// The general form: palette, angle and outline may all be signals, so
    /// the surface can change color and shape over time or with input.
    /// Palettes must keep the same number of colors across their values.
    public static func gradient(
        _ colors: XeerpeSignal<[Color]>,
        angle: XeerpeValue = 45,
        in shape: XeerpeShapeSignal
    ) -> XeerpeEffect {
        let inputs = colors.inputs.union(angle.inputs).union(shape.inputs)
        return XeerpeEffect(name: "gradient", slot: .background, claims: [.backgroundFill], inputs: inputs) { view, ctx in
            let pts = Xeerpe.gradientPoints(angleDegrees: angle.value(in: ctx))
            return AnyView(view.background(
                LinearGradient(
                    colors: colors.value(in: ctx),
                    startPoint: UnitPoint(x: pts.start.x, y: pts.start.y),
                    endPoint: UnitPoint(x: pts.end.x, y: pts.end.y)
                ).clipShape(shape.value(in: ctx))
            ))
        }
    }

    /// Shadow whose color is a signal, for a glow that changes hue.
    public static func glow(_ color: XeerpeSignal<Color>, radius: XeerpeValue = 12) -> XeerpeEffect {
        XeerpeEffect(name: "glow", slot: .content, claims: [.shadow], inputs: color.inputs.union(radius.inputs)) { view, ctx in
            AnyView(view.shadow(color: color.value(in: ctx), radius: Xeerpe.clampNonNegative(radius.value(in: ctx))))
        }
    }
}
