import SwiftUI
import Testing
@testable import xeerpe

/// What a user writes to add an effect of their own: one shader pass from
/// the context. (Here the library's vignette shader stands in for theirs.)
@MainActor
private func dim(_ amount: XeerpeValue) -> XeerpeEffect {
    .shader("dim", claims: ["dim"], inputs: amount.inputs) { ctx in
        let k = Xeerpe.clampUnit(amount.value(in: ctx))
        return .color(XeerpeShaders.library.xeerpeVignette(.boundingRect, .float(k)), enabled: k > 0)
    }
}

@MainActor
@Suite struct ShaderPrimitiveTests {
    private var white: some View { Color.white.frame(width: 80, height: 60) }

    @Test func runsTheShaderAndCarriesNameClaimsAndInputs() throws {
        let plain = try #require(render(white, nil))
        let e = dim(.hover(from: 0, to: 0.9))
        #expect(e.name == "dim" && e.claims == ["dim"] && e.inputs.contains(.hover))
        let on = try #require(render(white, e, XeerpeContext(isHovering: true)))
        #expect(pixel(on, 1, 1)[0] < pixel(plain, 1, 1)[0])
    }

    @Test func disabledPassLeavesTheContentAlone() throws {
        let plain = try #require(render(white, nil))
        #expect(try #require(render(white, dim(0))).bytes == plain.bytes)
    }

    @Test func layerAndDistortionPasses() throws {
        let plain = try #require(render(white, nil))
        let layer = XeerpeEffect.shader("px") { _ in .layer(XeerpeShaders.library.xeerpePixelate(.boundingRect, .float(8)), maxSampleOffset: CGSize(width: 8, height: 8)) }
        #expect(try #require(render(white, layer)).bytes.count == plain.bytes.count)
        let bulge = XeerpeEffect.shader("bulge") { _ in
            .distortion(XeerpeShaders.library.xeerpeBarrel(.boundingRect, .float(0.3)), maxSampleOffset: CGSize(width: 30, height: 30))
        }
        #expect(pixel(try #require(render(white, bulge)), 0, 0)[3] == 0)
    }

    @Test func worksInBuildersAndChains() {
        let a = XeerpeChain { .glow(.cyan).then(dim(0.5)) }
        let b = XeerpeChain { .shader("dim", inputs: .time) { _ in nil }.glow(.cyan) }
        #expect(a.effects.map(\.name) == ["glow", "dim"])
        #expect(b.effects.map(\.name) == ["dim", "glow"] && b.inputs.contains(.time))
    }

    @Test func noPassIsAnIdentity() throws {
        let plain = try #require(render(white, nil))
        #expect(try #require(render(white, .shader("none") { _ in nil })).bytes == plain.bytes)
    }

    @Test func shaderTimeWrapsHourly() {
        #expect(XeerpeContext(time: 3600 + 12.5).shaderTime == 12.5)
        #expect(XeerpeContext(time: 7).shaderTime == 7)
    }
}
