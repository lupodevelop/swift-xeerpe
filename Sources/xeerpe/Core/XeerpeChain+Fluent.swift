import SwiftUI

/// Fluent form of the effects. A builder body is one expression, so
/// leading-dot lines continue the previous one:
///
///     .gradient(.aurora)
///     .glow(.cyan)
///
/// Each effect is declared once, as a static member of `XeerpeEffect`, and
/// also has two chain forms: a static, so the first line can start with a
/// dot, and a method, so the next lines continue it.
extension XeerpeChain {
    /// Appends an effect of your own, or any `XeerpeEffect` value.
    public func then(_ effect: XeerpeEffect) -> XeerpeChain { appending(effect) }
    public static func then(_ effect: XeerpeEffect) -> XeerpeChain { XeerpeChain([effect]) }

    /// Appends a whole chain: a preset kept in a variable, or one built elsewhere.
    public func then(_ chain: XeerpeChain) -> XeerpeChain { appending(chain) }
    public static func then(_ chain: XeerpeChain) -> XeerpeChain { chain }
}
