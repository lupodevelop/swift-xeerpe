// Plain import, no @testable: if this compiles, the public API is enough to
// author a preset outside the package.
import SwiftUI
import Testing
import xeerpe

extension XeerpeChain {
    static func neon(_ color: Color = .pink, in shape: some Shape = Rectangle()) -> XeerpeChain {
        XeerpeChain {
            .liquid(XeerpePalette([color, .black, color, .white]), speed: 0.6, in: shape)
            .glow(color, radius: .hover(from: 6, to: 20))
            .then(XeerpeEffect(name: "tint", slot: .content, claims: ["tint"]) { $0 })
        }
    }
}

@MainActor
@Suite struct ExternalPresetTests {
    @Test func thirdPartyPresetUsesOnlyPublicAPI() {
        let s = XeerpeChain.neon(.green)
        #expect(s.effects.map(\.name) == ["liquid", "glow", "tint"])
        #expect(s.inputs.contains(.hover))
        #expect(s.without("tint").effects.count == 2)
    }
}
