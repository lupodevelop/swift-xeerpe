import SwiftUI
import Testing
@testable import xeerpe

@MainActor
@Suite struct FrozenTests {
    @Test func everyEffectSeesTheGivenContext() {
        for _ in 0..<25 {
            let time = Double.random(in: 0...100)
            let tilt = CGPoint(x: .random(in: -1...1), y: .random(in: -1...1))
            let touch: CGPoint? = Bool.random() ? CGPoint(x: .random(in: -1...1), y: .random(in: -1...1)) : nil
            var seen: [XeerpeContext] = []
            let count = Int.random(in: 1...6)
            let chain = (0..<count).reduce(XeerpeChain()) { c, i in
                c.appending(XeerpeEffect(name: "e\(i)", slot: .content, inputs: .time) { view, ctx in seen.append(ctx); return view })
            }
            _ = EmptyView().xeerpe(chain, at: XeerpeContext(time: time, tilt: tilt, touch: touch))
            #expect(seen.count == count)
            #expect(seen.allSatisfy { $0.time == time && $0.tilt == tilt && $0.touch == touch })
        }
    }

    @Test func sizeComesFromTheCallerNotTheLayout() {
        var seen: CGSize?
        let chain = XeerpeChain([XeerpeEffect(name: "s", slot: .content, inputs: []) { view, ctx in seen = ctx.size; return view }])
        let size = CGSize(width: 320, height: 180)
        _ = Color.clear.xeerpe(chain, at: XeerpeContext(size: size))
        #expect(seen == size)
    }
}
