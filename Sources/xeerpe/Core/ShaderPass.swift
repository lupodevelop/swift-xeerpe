import SwiftUI

extension XeerpeContext {
    /// `time` wrapped every hour: small enough to keep a shader's Float
    /// precise, for effects that pass time to Metal.
    public var shaderTime: Double { time.truncatingRemainder(dividingBy: 3600) }
}

extension XeerpeEffect {
    /// An effect that leaves the view alone, for platforms where an effect
    /// has nothing to draw with.
    static func passthrough(_ name: String, slot: XeerpeSlot = .content, claims: Set<XeerpeProperty> = [], inputs: XeerpeInput = []) -> XeerpeEffect {
        XeerpeEffect(name: name, slot: slot, claims: claims, inputs: inputs) { view, _ in view }
    }
}

#if !os(watchOS)
/// One Metal shader applied to a view: a `colorEffect`, a `layerEffect` or a
/// `distortionEffect`. A pass that is not `enabled` keeps the modifier in
/// place but draws nothing, so the view keeps its identity when an effect
/// switches on and off.
public struct XeerpeShaderPass {
    enum Kind { case color, layer(CGSize), distortion(CGSize) }
    let shader: Shader
    let kind: Kind
    let enabled: Bool

    /// A shader that changes each pixel's color and sees nothing else.
    public static func color(_ shader: Shader, enabled: Bool = true) -> XeerpeShaderPass {
        XeerpeShaderPass(shader: shader, kind: .color, enabled: enabled)
    }

    /// A shader that samples the view. It also runs in a margin of
    /// `maxSampleOffset` around the view; return clear there unless the
    /// effect means to draw outside (sparks, smoke).
    public static func layer(_ shader: Shader, maxSampleOffset: CGSize = .zero, enabled: Bool = true) -> XeerpeShaderPass {
        XeerpeShaderPass(shader: shader, kind: .layer(maxSampleOffset), enabled: enabled)
    }

    /// A shader that returns, for each point, where to read the view from.
    public static func distortion(_ shader: Shader, maxSampleOffset: CGSize, enabled: Bool = true) -> XeerpeShaderPass {
        XeerpeShaderPass(shader: shader, kind: .distortion(maxSampleOffset), enabled: enabled)
    }

    @MainActor
    func apply(to view: AnyView) -> AnyView {
        switch kind {
        case .color: AnyView(view.colorEffect(shader, isEnabled: enabled))
        case .layer(let m): AnyView(view.layerEffect(shader, maxSampleOffset: m, isEnabled: enabled))
        case .distortion(let m): AnyView(view.distortionEffect(shader, maxSampleOffset: m, isEnabled: enabled))
        }
    }
}

extension XeerpeEffect {
    /// An effect drawn by a Metal shader of your own: `make` turns the
    /// context into one shader pass each time the chain renders. Declare in
    /// `inputs` everything `make` reads (`.time`, `.tilt`, a signal's
    /// `inputs`), so the chain schedules frames only when they are needed.
    ///
    ///     extension XeerpeEffect {
    ///         static func tint(_ amount: XeerpeValue) -> XeerpeEffect {
    ///             .shader("tint", claims: ["tint"], inputs: amount.inputs) { ctx in
    ///                 let k = amount.value(in: ctx)
    ///                 return .color(ShaderLibrary.tint(.float(k)), enabled: k > 0)
    ///             }
    ///         }
    ///     }
    ///
    /// Return a pass with `enabled: false` to switch the effect off for a
    /// moment; return nil only when it never draws in this configuration.
    /// Two things to know when writing the shader itself: a layer shader
    /// runs in its sampling margin too, so return clear there; and in an
    /// offscreen `ImageRenderer`, samples taken across sibling views can come
    /// back wrong, so test with a single view.
    public static func shader(_ name: String, slot: XeerpeSlot = .content, claims: Set<XeerpeProperty> = [], inputs: XeerpeInput = [],
                              _ make: @escaping @MainActor (XeerpeContext) -> XeerpeShaderPass?) -> XeerpeEffect {
        XeerpeEffect(name: name, slot: slot, claims: claims, inputs: inputs) { view, ctx in
            make(ctx)?.apply(to: view) ?? view
        }
    }
}

/// Chain forms of `shader`, written by hand because the effect exists only
/// where shaders do.
extension XeerpeChain {
    /// A chain that starts with your own Metal shader. See
    /// `XeerpeEffect.shader(_:slot:claims:inputs:_:)`.
    public static func shader(_ name: String, slot: XeerpeSlot = .content, claims: Set<XeerpeProperty> = [], inputs: XeerpeInput = [],
                              _ make: @escaping @MainActor (XeerpeContext) -> XeerpeShaderPass?) -> XeerpeChain {
        XeerpeChain([XeerpeEffect.shader(name, slot: slot, claims: claims, inputs: inputs, make)])
    }

    /// Appends your own Metal shader. See
    /// `XeerpeEffect.shader(_:slot:claims:inputs:_:)`.
    public func shader(_ name: String, slot: XeerpeSlot = .content, claims: Set<XeerpeProperty> = [], inputs: XeerpeInput = [],
                       _ make: @escaping @MainActor (XeerpeContext) -> XeerpeShaderPass?) -> XeerpeChain {
        appending(XeerpeEffect.shader(name, slot: slot, claims: claims, inputs: inputs, make))
    }
}
#endif
