#if os(macOS)
import SwiftUI
import xeerpe

// Every preset of the catalog, by category.

/// Every preset of the archive: browse by category, search, preview it as a
/// surface or as the fill of a text.
@MainActor
struct CatalogBrowser: View {
    @State private var category: XeerpeCategory? = snapshotCategory
    @State private var query = ""
    @State private var selected = "gold"
    @State private var asText = false
    @State private var reactive = true
    @State private var source = Source.tilt
    private let tile = RoundedRectangle(cornerRadius: 16, style: .continuous)

    private var results: [XeerpePreset] {
        Array(XeerpeCatalog.search(query).filter { category == nil || $0.category == category }.prefix(snapshotLimit ?? .max))
    }
    private var current: XeerpePreset { XeerpeCatalog[selected] ?? XeerpeCatalog.all[0] }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                sideButton("All", count: XeerpeCatalog.all.count, on: category == nil) { category = nil }
                ForEach(XeerpeCategory.allCases) { c in
                    sideButton(c.title, count: XeerpeCatalog.presets(in: c).count, on: category == c) { category = c }
                }
            }
            .frame(width: 150)
            VStack(alignment: .leading, spacing: 18) {
                detail
                TextField("Search \(XeerpeCatalog.all.count) presets", text: $query).textFieldStyle(.roundedBorder)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 18) {
                    ForEach(results) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            Color.clear.frame(height: 96).xeerpe(look(p, in: tile))
                                .overlay(tile.stroke(.white.opacity(p.id == selected ? 0.9 : 0), lineWidth: 2))
                            Text(p.name).font(.caption).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selected = p.id }
                    }
                }
            }
        }
    }

    private func look(_ p: XeerpePreset, in s: some Shape) -> XeerpeChain {
        reactive ? p.reactive(to: source.signal, in: s) : p.style(in: s)
    }

    private func snippet(_ p: XeerpePreset) -> String {
        // Catalog ids map to typed members in camel case: "rose-gold" is `.roseGold`.
        let member = p.id.split(separator: "-").enumerated().map { $0.offset == 0 ? String($0.element) : $0.element.capitalized }.joined()
        let args = [".\(member)", reactive ? "reacting: \(source.code)" : nil, asText ? nil : "in: shape"].compactMap { $0 }.joined(separator: ", ")
        return asText ? "Text(\"xeerpe\").xeerpeFill(.preset(\(args)))" : "view.xeerpe { .preset(\(args)) }"
    }

    private func sideButton(_ title: String, count: Int, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(title); Spacer(); Text("\(count)").foregroundStyle(.white.opacity(0.4)) }
                .font(.system(.callout, design: .rounded)).foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(on ? 0.14 : 0)))
        }
        .buttonStyle(.plain)
    }

    private var detail: some View {
        let p = current
        return VStack(alignment: .leading, spacing: 12) {
            Group {
                if asText {
                    Text("xeerpe").font(.system(size: 120, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .xeerpeFill(look(p, in: Rectangle()))
                        .background(Color(white: 0.08), in: shape)
                } else {
                    Color.clear.xeerpe(look(p, in: shape))
                }
            }
            .frame(height: 230)
            HStack {
                Text(p.name).font(.system(.title3, design: .rounded).bold()).foregroundStyle(.white)
                Text(p.category.title).font(.caption).foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 8).padding(.vertical, 3).background(.white.opacity(0.1), in: Capsule())
                if !p.motion.isEmpty { Text("animated").font(.caption).foregroundStyle(.cyan) }
                Spacer()
                Picker("", selection: $reactive) { Text("Base").tag(false); Text("Reactive").tag(true) }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 150)
                if reactive {
                    Picker("", selection: $source) { ForEach(Source.allCases) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 180)
                }
                Picker("", selection: $asText) { Text("Surface").tag(false); Text("Text").tag(true) }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 150)
            }
            CodeView(snippet(p))
        }
    }
}
#endif
