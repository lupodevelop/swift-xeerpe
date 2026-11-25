import SwiftUI

/// An ordered list of effects. Order is the contract: effects are applied
/// first to last and are never reordered or fused.
///
/// A chain is also how a look is named and shared: a preset is a static
/// member in an extension, so anyone can add one without touching the core,
/// and its users can still edit it with `adding`, `without` and `replacing`.
///
///     extension XeerpeChain {
///         static func neon(_ color: Color = .pink) -> XeerpeChain {
///             XeerpeChain { .glow(color, radius: .hover(from: 6, to: 20)).pulse() }
///         }
///     }
///
/// Each static preset also has a chained form, so it can be used on any
/// line of a builder.
public struct XeerpeChain: Sendable {
    /// The effects in the order they are applied.
    public private(set) var effects: [XeerpeEffect]

    /// A chain of `effects`, applied in that order.
    public init(_ effects: [XeerpeEffect] = []) { self.effects = effects }
    /// A chain of the effects `build` lists, one per line.
    public init(@XeerpeBuilder _ build: () -> XeerpeChain) { self = build() }

    /// This chain with `effect` added at the end.
    public func appending(_ effect: XeerpeEffect) -> XeerpeChain { XeerpeChain(effects + [effect]) }
    /// This chain with the effects of `other` added at the end.
    public func appending(_ other: XeerpeChain) -> XeerpeChain { XeerpeChain(effects + other.effects) }

    /// A later effect claims a property an earlier effect already claimed.
    public struct Conflict: Hashable {
        /// The property both effects claim.
        public let property: XeerpeProperty
        /// Index in `effects` of the effect that claimed it first.
        public let first: Int
        /// Index in `effects` of the later effect.
        public let second: Int
    }

    /// Reported, never resolved: every effect still renders, in order.
    public var conflicts: [Conflict] {
        var lastOwner: [XeerpeProperty: Int] = [:]
        var found: [Conflict] = []
        for (i, effect) in effects.enumerated() {
            for p in effect.claims.sorted(by: { $0.rawValue < $1.rawValue }) {
                if let prev = lastOwner[p] { found.append(Conflict(property: p, first: prev, second: i)) }
                lastOwner[p] = i
            }
        }
        return found
    }

    /// Union of the inputs every effect reads.
    public var inputs: XeerpeInput { effects.reduce([]) { $0.union($1.inputs) } }

    @MainActor
    func render(_ content: AnyView, context: XeerpeContext = XeerpeContext()) -> AnyView {
        effects.reduce(content) { $1.render($0, context) }
    }
}

/// Customizing: take a chain or style someone else wrote, then drop or swap
/// the parts you do not want. Position in the order is preserved.
extension XeerpeChain {
    /// Appends effects after the chain's own.
    public func adding(@XeerpeBuilder _ build: () -> XeerpeChain) -> XeerpeChain { appending(build()) }

    /// Removes every effect that claims `property`.
    public func without(_ property: XeerpeProperty) -> XeerpeChain {
        XeerpeChain(effects.filter { !$0.claims.contains(property) })
    }

    /// Puts `effect` where the first effect claiming `property` stood and
    /// drops any other claimant. Appends when nothing claimed it.
    public func replacing(_ property: XeerpeProperty, with effect: XeerpeEffect) -> XeerpeChain {
        guard let i = effects.firstIndex(where: { $0.claims.contains(property) }) else { return appending(effect) }
        var out = effects
        out[i] = effect
        return XeerpeChain(out.enumerated().filter { $0.offset == i || !$0.element.claims.contains(property) }.map(\.element))
    }
}
