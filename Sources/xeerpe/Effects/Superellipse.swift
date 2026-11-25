import SwiftUI

/// |x|^n + |y|^n = 1 scaled to the rect: 1 is a diamond, 2 a circle (or
/// ellipse), about 4 a squircle, large values a rectangle. Animatable, so a
/// changing exponent morphs the outline continuously. Clamped to 0.5...24.
public struct Superellipse: Shape {
    public var exponent: Double
    public init(exponent: Double) { self.exponent = exponent }

    public var animatableData: Double {
        get { exponent }
        set { exponent = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let n = Swift.min(Swift.max(exponent.isNaN ? 2 : exponent, 0.5), 24)
        let a = rect.width / 2, b = rect.height / 2
        let steps = 160
        var path = Path()
        for i in 0...steps {
            let th = Double(i) / Double(steps) * 2 * .pi
            let c = cos(th), s = sin(th)
            let x = rect.midX + a * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
            let y = rect.midY + b * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n)
            i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        path.closeSubpath()
        return path
    }
}

/// A shape that can change from frame to frame.
public typealias XeerpeShapeSignal = XeerpeSignal<AnyShape>

extension XeerpeSignal where Value == AnyShape {
    public static func superellipse(_ exponent: XeerpeValue) -> XeerpeShapeSignal {
        .init(inputs: exponent.inputs) { AnyShape(Superellipse(exponent: exponent.resolve($0))) }
    }
}
