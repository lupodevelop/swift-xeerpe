import SwiftUI

/// A group of presets in the catalog.
public enum XeerpeCategory: String, CaseIterable, Sendable, Identifiable {
    case metals, gems, food, nature, sky, space, neon, pastel, neutral, luxury, textures, moods, motion
    /// Presets drawn by Metal shaders.
    case liquid
    public var id: String { rawValue }
    /// The name with a capital initial, for display.
    public var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// A named surface. Data presets list their layers; shader presets build a style.
public struct XeerpePreset: Identifiable {
    /// The preset's name, as `XeerpeCatalog[id:]` finds it.
    public let id: String
    public let category: XeerpeCategory
    /// The layers of a data preset; empty for a shader preset.
    public let layers: [XeerpeLayer]
    /// The slow movement of a data preset; empty for a shader preset.
    public let motion: [XeerpeMotion]
    private let make: ((AnyShape, XeerpeVector?) -> XeerpeChain)?

    /// A data preset drawn from `layers`, moving by `motion`.
    public init(_ id: String, _ category: XeerpeCategory, layers: [XeerpeLayer], motion: [XeerpeMotion] = []) {
        self.id = id; self.category = category; self.layers = layers; self.motion = motion; self.make = nil
    }

    init(_ id: String, _ category: XeerpeCategory, make: @escaping (AnyShape, XeerpeVector?) -> XeerpeChain) {
        self.id = id; self.category = category; self.layers = []; self.motion = []; self.make = make
    }

    /// Words a person would search for.
    public var name: String { id.replacingOccurrences(of: "-", with: " ") }

    /// The preset by its id; only for ids the catalog is known to hold.
    static func named(_ id: String) -> XeerpePreset {
        guard let p = XeerpeCatalog[id] else { preconditionFailure("No catalog preset \(id)") }
        return p
    }

    /// The base preset as a chain, clipped to `shape`. Edit it like any chain.
    public func style(in shape: some Shape = Rectangle()) -> XeerpeChain {
        if let make { return make(AnyShape(shape), nil) }
        return .surface(layers, motion: motion, in: shape)
    }

    /// The same preset, reacting to a vector signal: `.tilt`, `.touch`,
    /// `.drag`, or any `XeerpeVector`. `strength` scales the response
    /// (1 is the designed amount). At rest it looks like the base preset.
    public func reactive(to signal: XeerpeVector = .tilt, strength: Double = 1, in shape: some Shape = Rectangle()) -> XeerpeChain {
        if let make { return make(AnyShape(shape), signal) }
        return .surface(layers, motion: motion, in: shape, react: signal, strength: strength)
    }
}

/// Every preset that ships with xeerpe.
public enum XeerpeCatalog {
    /// Presets are immutable values; the shader ones hold style builders that are only called on the main actor.
    nonisolated(unsafe) public static let all: [XeerpePreset] = XeerpeCatalog.generated + XeerpeCatalog.shaderPresets

    /// The presets in `category`, in catalog order.
    public static func presets(in category: XeerpeCategory) -> [XeerpePreset] { all.filter { $0.category == category } }

    /// The preset named `id`, or nil.
    public static subscript(id: String) -> XeerpePreset? { all.first { $0.id == id } }

    /// Matches the id and the category; an empty query returns everything.
    public static func search(_ query: String) -> [XeerpePreset] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { $0.id.contains(q) || $0.name.contains(q) || $0.category.rawValue.contains(q) }
    }

    static var shaderPresets: [XeerpePreset] {
        [
            XeerpePreset("aurora-flow", .liquid) { s, v in XeerpeChain { .liquid(.aurora, in: s, pull: v) } },
            XeerpePreset("lava-flow", .liquid) { s, v in XeerpeChain { .liquid(.lava, speed: 1.6, warp: 2.4, in: s, pull: v).ripple(amplitude: 14) } },
            XeerpePreset("pond", .liquid) { s, v in XeerpeChain { .liquid(.ocean, speed: 0.7, in: s, pull: v).ripple() } },
            XeerpePreset("magnifier", .liquid) { s, v in XeerpeChain { .liquid(.orchid, speed: 0.8, in: s, pull: v).lens(radius: 90, strength: 0.6) } },
        ]
    }
}

extension XeerpeEffect {
    /// A layered surface behind the content, clipped to `shape`. Layers are
    /// plain data (see `XeerpeLayer`); `motion` adds slow movement.
    /// With `react`, the surface responds to that vector signal (see
    /// `XeerpePreset.reactive`).
    public static func surface(_ layers: [XeerpeLayer], motion: [XeerpeMotion] = [], in shape: some Shape = Rectangle(),
                               react: XeerpeVector? = nil, strength: Double = 1) -> XeerpeEffect {
        let clip = AnyShape(shape)
        let still: XeerpeInput = motion.isEmpty ? [] : .time
        let inputs = still.union(react?.inputs ?? [])
        return XeerpeEffect(name: "surface", slot: .background, claims: [.backgroundFill], inputs: inputs) { view, ctx in
            AnyView(view.background(XeerpeSurfaceView(
                layers: layers, motion: motion, time: ctx.reduceMotion ? 0 : ctx.time,
                react: react?.value(in: ctx) ?? .zero, strength: react == nil ? 0 : strength
            ).clipShape(clip)))
        }
    }
}

extension XeerpeChain {
    /// A catalog preset, as a surface behind the content and clipped to
    /// `shape`: `.preset(.midnight, in: card)`. With `reacting`, the
    /// surface follows that vector signal (`.tilt`, `.touch`, `.drag`);
    /// `strength` scales the response, 1 being the designed amount.
    public static func preset(_ preset: XeerpePreset, reacting signal: XeerpeVector? = nil, strength: Double = 1,
                              in shape: some Shape = Rectangle()) -> XeerpeChain {
        guard let signal else { return preset.style(in: shape) }
        return preset.reactive(to: signal, strength: strength, in: shape)
    }
}

extension View {
    /// Fills this view's own opaque pixels, such as text or an icon, with a
    /// chain's surface. The view takes no color of its own.
    public func xeerpeFill(_ chain: XeerpeChain) -> some View {
        overlay { Color.clear.xeerpe(chain).mask(self) }.foregroundStyle(.clear)
    }
}
