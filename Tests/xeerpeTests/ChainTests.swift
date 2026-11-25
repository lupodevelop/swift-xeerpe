import SwiftUI
import Testing
@testable import xeerpe

@MainActor
final class Recorder {
    var names: [String] = []
}

@MainActor
func recording(_ name: String, claims: Set<XeerpeProperty> = [], into r: Recorder) -> XeerpeEffect {
    XeerpeEffect(name: name, slot: .content, claims: claims) { view in
        r.names.append(name)
        return view
    }
}

@MainActor
@Suite struct ChainTests {
    @Test func renderAppliesEffectsInDeclaredOrder() {
        for _ in 0..<25 {
            let names = (0..<Int.random(in: 0...20)).map { "e\($0)" }
            let r = Recorder()
            let chain = names.reduce(XeerpeChain()) { $0.appending(recording($1, into: r)) }
            _ = chain.render(AnyView(EmptyView()))
            #expect(r.names == names)
            #expect(chain.effects.map(\.name) == names)
        }
    }

    @Test func sharedClaimIsReportedAsConflict() {
        let r = Recorder()
        let chain = XeerpeChain()
            .appending(recording("a", claims: [.opacity], into: r))
            .appending(recording("b", claims: [.blur], into: r))
            .appending(recording("c", claims: [.opacity, .blur], into: r))
        let found = Set(chain.conflicts.map { "\($0.property.rawValue):\($0.first)>\($0.second)" })
        #expect(found == ["opacity:0>2", "blur:1>2"])
    }

    @Test func disjointClaimsHaveNoConflict() {
        let r = Recorder()
        let chain = (0..<10).reduce(XeerpeChain()) {
            $0.appending(recording("e\($1)", claims: [XeerpeProperty(rawValue: "p\($1)")], into: r))
        }
        #expect(chain.conflicts.isEmpty)
    }

    @Test func conflictsStillRenderEveryEffect() {
        let r = Recorder()
        let chain = XeerpeChain()
            .appending(recording("a", claims: [.opacity], into: r))
            .appending(recording("b", claims: [.opacity], into: r))
        _ = chain.render(AnyView(EmptyView()))
        #expect(r.names == ["a", "b"])
    }
}

@MainActor
@Suite struct BuilderTests {
    func make(_ name: String, _ r: Recorder) -> XeerpeEffect { recording(name, into: r) }

    @Test func builderKeepsOrderAcrossControlFlow() {
        let r = Recorder()
        func build(flag: Bool, count: Int) -> XeerpeChain {
            XeerpeBuilder.buildBlock(
                XeerpeChain([make("first", r)]),
                XeerpeBuilder.buildOptional(flag ? XeerpeChain([make("opt", r)]) : nil),
                XeerpeBuilder.buildArray((0..<count).map { XeerpeChain([make("n\($0)", r)]) }),
                XeerpeBuilder.buildEither(first: XeerpeChain([make("last", r)]))
            )
        }
        #expect(build(flag: true, count: 2).effects.map(\.name) == ["first", "opt", "n0", "n1", "last"])
        #expect(build(flag: false, count: 0).effects.map(\.name) == ["first", "last"])
    }

    @Test func chainInlinesIntoChainPreservingOrder() {
        let r = Recorder()
        let inner = XeerpeChain { .then(make("b", r)).then(make("c", r)) }
        let outer = XeerpeChain { .then(make("a", r))
            .then(inner)
            .then(make("d", r)) }
        #expect(outer.effects.map(\.name) == ["a", "b", "c", "d"])
    }

    @Test func publicDotSyntaxCompiles() {
        let chain = XeerpeChain {
            .gradient(.aurora)
            .glow(.cyan, radius: 12)
            .scale(1.1)
            .blur(2)
            .opacity(0.5)
        }
        #expect(chain.effects.count == 5)
        #expect(chain.conflicts.isEmpty)
    }
}

@Suite struct PrimitiveTests {
    @Test func inputsAreClamped() {
        for _ in 0..<100 {
            let v = Double.random(in: -10...10)
            #expect((0...1).contains(Xeerpe.clampUnit(v)))
            #expect(Xeerpe.clampNonNegative(v) >= 0)
        }
        #expect(Xeerpe.clampUnit(.nan) == 0)
    }

    @Test func primitivesDeclareSlotAndClaim() {
        #expect(XeerpeEffect.opacity(1).claims == [.opacity])
        #expect(XeerpeEffect.blur(1).claims == [.blur])
        #expect(XeerpeEffect.scale(1).claims == [.scale])
        #expect(XeerpeEffect.scale(1).slot == .geometry)
        #expect(XeerpeEffect.gradient(.aurora).slot == .background)
        #expect(XeerpeEffect.glow(.red).claims == [.shadow])
    }
}

@MainActor
@Suite struct ViewApiTests {
    @Test func entryPointsCompile() {
        let style = XeerpeChain { .glow(.cyan).blur(1) }
        _ = Text("x").xeerpe { .gradient(.aurora).glow(.cyan, radius: 8).scale(1.05) }
        _ = Text("x").xeerpe(XeerpeChain([.glow(.cyan)]))
        _ = Text("x").xeerpe(style)
    }
}

@MainActor
@Suite struct CustomizeTests {
    func effects(_ names: [(String, Set<XeerpeProperty>)]) -> XeerpeChain {
        let r = Recorder()
        return XeerpeChain(names.map { recording($0.0, claims: $0.1, into: r) })
    }

    @Test func withoutDropsAllClaimantsAndKeepsOrder() {
        let c = effects([("a", [.opacity]), ("b", [.blur]), ("c", [.opacity, .scale]), ("d", [])])
        #expect(c.without(.opacity).effects.map(\.name) == ["b", "d"])
        #expect(c.without("nothing").effects.map(\.name) == ["a", "b", "c", "d"])
    }

    @Test func replacingKeepsPositionAndRemovesOtherClaimants() {
        let c = effects([("a", [.blur]), ("b", [.opacity]), ("c", [.scale]), ("d", [.opacity])])
        let new = recording("new", claims: [.opacity], into: Recorder())
        let out = c.replacing(.opacity, with: new)
        #expect(out.effects.map(\.name) == ["a", "new", "c"])
        #expect(out.conflicts.isEmpty)
        #expect(c.replacing("absent", with: new).effects.map(\.name) == ["a", "b", "c", "d", "new"])
    }
}
