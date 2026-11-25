#if os(macOS)
import SwiftUI

/// A section title with one line on what to do with it.
@MainActor
func heading(_ title: String, _ hint: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.system(.title2, design: .rounded).bold()).foregroundStyle(.white)
        Text(hint).foregroundStyle(.white.opacity(0.55))
    }
}

/// One step of an example: the view, and the code that makes it under it.
@MainActor
func step(_ code: String, @ViewBuilder _ view: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 8) { view(); CodeView(code) }.frame(maxWidth: .infinity, alignment: .topLeading)
}
#endif
