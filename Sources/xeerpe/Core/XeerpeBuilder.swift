/// Builds a chain from effects listed one per line. `if`, `if`-`else`,
/// `switch` and `for` work as in a view builder.
@resultBuilder
public enum XeerpeBuilder {
    public static func buildExpression(_ c: XeerpeChain) -> XeerpeChain { c }
    public static func buildBlock(_ parts: XeerpeChain...) -> XeerpeChain {
        parts.reduce(XeerpeChain()) { $0.appending($1) }
    }
    public static func buildOptional(_ c: XeerpeChain?) -> XeerpeChain { c ?? XeerpeChain() }
    public static func buildEither(first c: XeerpeChain) -> XeerpeChain { c }
    public static func buildEither(second c: XeerpeChain) -> XeerpeChain { c }
    public static func buildArray(_ cs: [XeerpeChain]) -> XeerpeChain {
        cs.reduce(XeerpeChain()) { $0.appending($1) }
    }
}
