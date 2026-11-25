#if os(macOS)
import SwiftUI
import xeerpe

// An effect drawn by a Metal shader of the app's own, the `scan` function,
// added to xeerpe with `XeerpeEffect.shader`. Once declared, it chains,
// takes signals and is edited like any library effect.
extension XeerpeEffect {
    /// A scanner line at `progress` (0 top, 1 bottom): what it has passed
    /// turns black and white. 0 leaves the content alone.
    static func scan(_ progress: XeerpeValue) -> XeerpeEffect {
        .shader("scan", claims: ["scan"], inputs: progress.inputs) { ctx in
            let p = progress.value(in: ctx)
            return .color(ShaderLibrary.bundle(.module).scan(.boundingRect, .float(p)), enabled: p > 0)
        }
    }
}

extension XeerpeChain {
    static func scan(_ progress: some XeerpeValueConvertible) -> XeerpeChain { XeerpeChain([.scan(progress.xeerpeValue)]) }
    func scan(_ progress: some XeerpeValueConvertible) -> XeerpeChain { appending(.scan(progress.xeerpeValue)) }
}
#endif
