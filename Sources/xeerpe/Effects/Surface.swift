import SwiftUI

public enum XeerpeGlass: Sendable {
    case regular
    case clear
}

extension XeerpeEffect {
    /// Native Liquid Glass where the OS has it (iOS, iPadOS, macOS, tvOS and
    /// watchOS 26+); on visionOS the system regular material; on older
    /// systems an ultra-thin material in the same shape. Tint and
    /// interactivity only apply to Liquid Glass. The system draws the
    /// glass, so it does not appear in `ImageRenderer` snapshots.
    public static func glass(
        _ style: XeerpeGlass = .regular,
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: some Shape = Rectangle()
    ) -> XeerpeEffect {
        let clip = AnyShape(shape)
        return XeerpeEffect(name: "glass", slot: .background, claims: [.surface]) { view in
            #if os(visionOS)
            // glassBackgroundEffect needs an InsettableShape; the type-erased
            // shape is not one, so use the system material in the same shape.
            return AnyView(view.background(.regularMaterial, in: clip))
            #else
            if #available(iOS 26, macOS 26, tvOS 26, watchOS 26, *) {
                var g: Glass = style == .clear ? .clear : .regular
                if let tint { g = g.tint(tint) }
                if interactive { g = g.interactive() }
                return AnyView(view.glassEffect(g, in: clip))
            }
            return AnyView(view.background(.ultraThinMaterial, in: clip))
            #endif
        }
    }

    /// Fills the content's own opaque pixels with a gradient: an SF Symbol,
    /// a template image or an asset-catalog SVG takes the gradient as its
    /// color. Transparent areas stay transparent. Renders the content twice.
    public static func fill(_ g: XeerpeGradient, angle: XeerpeValue = 45) -> XeerpeEffect {
        XeerpeEffect(name: "fill", slot: .content, claims: [.foregroundFill], inputs: angle.inputs) { view, ctx in
            let pts = Xeerpe.gradientPoints(angleDegrees: angle.value(in: ctx))
            let gradient = LinearGradient(
                colors: g.colors,
                startPoint: UnitPoint(x: pts.start.x, y: pts.start.y),
                endPoint: UnitPoint(x: pts.end.x, y: pts.end.y)
            )
            return AnyView(view.overlay(gradient.mask(view).allowsHitTesting(false).accessibilityHidden(true)))
        }
    }
}
