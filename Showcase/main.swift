// Live showcase window. With a path argument it writes a PNG of a tab
// (optional second argument: a tab such as reveal or backgrounds; optional
// third: a catalog category). Pointer and tap
// effects need the live window. macOS only.
#if os(macOS)
import SwiftUI
import AppKit
import xeerpe

/// Set only when writing a PNG: the grid of every preset is too tall to render as one image.
nonisolated(unsafe) var snapshotLimit: Int?
nonisolated(unsafe) var snapshotCategory: XeerpeCategory?
/// Set only when writing a PNG, from XEERPE_PROGRESS: freezes progress-driven demos at that value.
nonisolated(unsafe) var snapshotProgress: Double? = ProcessInfo.processInfo.environment["XEERPE_PROGRESS"].flatMap(Double.init)

let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
let ink = Color(red: 0.04, green: 0.045, blue: 0.07)

@MainActor
struct Demo<Content: View>: View {
    let title: String, hint: String, code: String
    let content: Content
    init(_ title: String, hint: String, code: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.hint = hint; self.code = code; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content.frame(height: 250)
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text(hint).font(.caption).foregroundStyle(.white.opacity(0.5))
            }
            CodeView(code)
        }
    }
}

@MainActor
func label(_ big: String, _ small: String) -> some View {
    VStack(spacing: 6) {
        Text(big).font(.system(size: 54, weight: .bold, design: .rounded))
        Text(small).font(.system(.callout, design: .rounded)).opacity(0.8)
    }
    .foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
}

/// The vector signal a demo reacts to. On a Mac, tilt follows the pointer's
/// offset from the center of the view.
enum Source: String, CaseIterable, Identifiable {
    case tilt = "Tilt", touch = "Touch", drag = "Drag"
    var id: String { rawValue }
    var signal: XeerpeVector {
        switch self {
        case .tilt: .tilt
        case .touch: .touch
        case .drag: .drag
        }
    }
    var code: String { "." + rawValue.lowercased() }
}

// MARK: Catalog

/// A button drawn by SwiftUI. Native AppKit/UIKit controls cannot be drawn
/// inside a shader effect (they show as a placeholder), so content that goes
/// under a reveal or a layer effect uses this instead.
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.callout, design: .rounded).weight(.semibold)).foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(.white.opacity(configuration.isPressed ? 0.35 : 0.22), in: Capsule())
    }
}

// MARK: Window

/// One tab as a page: the library's name, then the tab's sections.
@MainActor
struct Sheet: View {
    let tab: Tab
    let start: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 4) {
                Text("xeerpe").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Chainable effects for SwiftUI. Presets drawn by Metal.").foregroundStyle(.white.opacity(0.6))
            }
            tab.content(start: start)
        }
        .padding(36)
        .frame(width: 1000)
        .background(ink)
        .environment(\.colorScheme, .dark)
    }
}

/// The live window: the tabs in a sidebar, the selected one scrolling beside it.
@MainActor
struct ShowcaseWindow: View {
    @State var tab: Tab
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Tab.allCases) { t in
                    Button { tab = t } label: {
                        Label(t.rawValue, systemImage: t.symbol).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(t == tab ? .white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(t == tab ? .white : .white.opacity(0.6))
                    // Reference tabs sit apart from the use cases.
                    if t == .brand { Divider().padding(.vertical, 8) }
                }
                Spacer()
            }
            .padding(.top, 52).padding(.horizontal, 10)
            .frame(width: 190)
            .background(Color(red: 0.06, green: 0.065, blue: 0.095))
            ScrollView { Sheet(tab: tab, start: 0) }.id(tab).defaultScrollAnchor(.top)
        }
        .background(ink)
        .environment(\.colorScheme, .dark)
    }
}

let args = Array(CommandLine.arguments.dropFirst())
if let scene = ProcessInfo.processInfo.environment["XEERPE_FRAMES"], let dir = args.first {
    try renderFrames(scene, into: URL(fileURLWithPath: dir))
} else if let out = args.first {
    let tab = Tab.allCases.first { $0.rawValue.lowercased() == args.dropFirst().first } ?? .catalog
    snapshotLimit = 12
    snapshotCategory = args.dropFirst(2).first.flatMap { XeerpeCategory(rawValue: $0) }
    let renderer = ImageRenderer(content: Sheet(tab: tab, start: 0.55))
    renderer.scale = 2
    for _ in 0..<6 { _ = renderer.cgImage; RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
       let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
        try png.write(to: URL(fileURLWithPath: out))
        print("wrote \(out)")
    } else {
        print("render failed"); exit(1)
    }
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1220, height: 900),
        styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
        backing: .buffered, defer: false)
    window.title = "xeerpe"
    window.titlebarAppearsTransparent = true
    window.appearance = NSAppearance(named: .darkAqua)
    window.backgroundColor = NSColor(red: 0.04, green: 0.045, blue: 0.07, alpha: 1)
    window.contentView = NSHostingView(rootView: ShowcaseWindow(tab: Tab.allCases.first { $0.rawValue.lowercased() == ProcessInfo.processInfo.environment["XEERPE_TAB"] } ?? .start))
    window.center()
    window.makeKeyAndOrderFront(nil)
    app.activate(ignoringOtherApps: true)
    app.run()
}
#else
print("xeerpe-preview runs on macOS only")
#endif
