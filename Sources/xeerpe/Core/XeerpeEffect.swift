import SwiftUI

/// One ordered operation on a view. `render` receives the view produced by
/// all earlier effects in the chain and the current context.
/// Immutable; `render` is only called on the main actor.
///
/// Three ways to add your own, from least to most work:
/// 1. Compose: a static func on `XeerpeChain` that returns a chain of
///    existing effects is a preset, usable on any builder line.
/// 2. Wrap SwiftUI: `XeerpeEffect(name:slot:claims:inputs:render:)` with any
///    modifier in `render`, reading signals with `value(in: ctx)`.
/// 3. Bring Metal: `.shader(_:slot:claims:inputs:_:)` turns the context into
///    one color, layer or distortion pass of your own shader.
///
/// In each, declare in `inputs` what the effect reads, so frames run only
/// when needed, and give it a `claims` property so `without` and
/// `replacing` can find it.
public struct XeerpeEffect: @unchecked Sendable {
    public let name: String
    public let slot: XeerpeSlot
    public let claims: Set<XeerpeProperty>
    /// Inputs the effect reads; the chain wires up only these.
    public let inputs: XeerpeInput
    let render: @MainActor (AnyView, XeerpeContext) -> AnyView

    public init(
        name: String,
        slot: XeerpeSlot,
        claims: Set<XeerpeProperty> = [],
        inputs: XeerpeInput = [],
        render: @escaping @MainActor (AnyView, XeerpeContext) -> AnyView
    ) {
        self.name = name
        self.slot = slot
        self.claims = claims
        self.inputs = inputs
        self.render = render
    }

    /// For effects that read no context.
    public init(
        name: String,
        slot: XeerpeSlot,
        claims: Set<XeerpeProperty> = [],
        render: @escaping @MainActor (AnyView) -> AnyView
    ) {
        self.init(name: name, slot: slot, claims: claims, inputs: []) { view, _ in render(view) }
    }

    func renamed(_ newName: String) -> XeerpeEffect {
        XeerpeEffect(name: newName, slot: slot, claims: claims, inputs: inputs, render: render)
    }
}
