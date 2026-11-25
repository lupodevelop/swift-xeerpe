import SwiftUI

/// Which part of a view has been scratched, kept on a coarse grid. A cell
/// counts as scratched when its center falls within `radius` of a stroke
/// segment, so coverage follows the brush area and never decreases.
struct XeerpeScratchGrid: Equatable {
    let cols: Int, rows: Int
    private var cells: [Bool]
    private var marked = 0

    init(cols: Int = 40, rows: Int = 40) {
        self.cols = max(cols, 1); self.rows = max(rows, 1)
        cells = Array(repeating: false, count: self.cols * self.rows)
    }

    /// Scratched fraction, 0...1.
    var coverage: Double { Double(marked) / Double(cells.count) }

    mutating func mark(from a: CGPoint, to b: CGPoint, radius: Double, in size: CGSize) {
        guard radius.isFinite, radius > 0, size.width > 0, size.height > 0 else { return }
        let cw = size.width / Double(cols), ch = size.height / Double(rows)
        let c0 = max(Int(((min(a.x, b.x) - radius) / cw).rounded(.down)), 0)
        let c1 = min(Int(((max(a.x, b.x) + radius) / cw).rounded(.up)), cols - 1)
        let r0 = max(Int(((min(a.y, b.y) - radius) / ch).rounded(.down)), 0)
        let r1 = min(Int(((max(a.y, b.y) + radius) / ch).rounded(.up)), rows - 1)
        guard c0 <= c1, r0 <= r1 else { return }
        let d = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let len2 = d.x * d.x + d.y * d.y
        for r in r0...r1 {
            for c in c0...c1 where !cells[r * cols + c] {
                let p = CGPoint(x: (Double(c) + 0.5) * cw, y: (Double(r) + 0.5) * ch)
                let t = len2 > 0 ? min(max(((p.x - a.x) * d.x + (p.y - a.y) * d.y) / len2, 0), 1) : 0
                if hypot(p.x - (a.x + d.x * t), p.y - (a.y + d.y * t)) <= radius {
                    cells[r * cols + c] = true
                    marked += 1
                }
            }
        }
    }
}

/// A cover over the content that is erased where a finger drags or a
/// pointer passes. Once `clearAt` of it is gone the rest fades away and the content
/// takes touches. On tvOS, and for VoiceOver, one activation clears it.
struct XeerpeScratchView: View {
    let content: AnyView
    let cover: AnyView
    let brush: Double
    let clearAt: Double
    let onChange: (@MainActor (Double) -> Void)?

    @State private var strokes: [[CGPoint]] = []
    @State private var grid = XeerpeScratchGrid()
    @State private var cleared = false
    @State private var dragging = false

    var body: some View {
        content
            .accessibilityHidden(!cleared)
            .overlay { GeometryReader { geo in scratchable(geo.size) } }
    }

    private func scratchable(_ size: CGSize) -> some View {
        let erase = brush
        let shown = cover
            .mask {
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                    ctx.blendMode = .destinationOut
                    for s in strokes {
                        guard let first = s.first else { continue }
                        if s.count == 1 {
                            ctx.fill(Path(ellipseIn: CGRect(x: first.x - erase / 2, y: first.y - erase / 2, width: erase, height: erase)),
                                     with: .color(.white))
                        } else {
                            var p = Path()
                            p.addLines(s)
                            ctx.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: erase, lineCap: .round, lineJoin: .round))
                        }
                    }
                }
            }
            .opacity(cleared ? 0 : 1)
            .allowsHitTesting(!cleared)
            .contentShape(Rectangle())
            .accessibilityElement()
            .accessibilityLabel("Scratch to reveal")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { clear() }
        #if os(tvOS)
        return shown.onTapGesture { clear() }
        #else
        #if os(watchOS)
        return shown.gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in scratch(to: v.location, new: !dragging, in: size); dragging = true }
            .onEnded { _ in dragging = false })
        #else
        // A pointer scratches by passing over, a finger by dragging.
        return shown
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { v in scratch(to: v.location, new: !dragging, in: size); dragging = true }
                .onEnded { _ in dragging = false })
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): scratch(to: p, new: !dragging, in: size); dragging = true
                case .ended: dragging = false
                }
            }
        #endif
        #endif
    }

    private func scratch(to p: CGPoint, new: Bool, in size: CGSize) {
        guard !cleared else { return }
        let from = new ? p : (strokes.last?.last ?? p)
        if new { strokes.append([p]) } else { strokes[strokes.count - 1].append(p) }
        grid.mark(from: from, to: p, radius: brush / 2, in: size)
        onChange?(grid.coverage)
        if grid.coverage >= clearAt { clear() }
    }

    private func clear() {
        guard !cleared else { return }
        withAnimation(.easeOut(duration: 0.45)) { cleared = true }
        onChange?(1)
    }
}

extension XeerpeEffect {
    /// A scratch card: `cover` is drawn over the content and erased by
    /// dragging, with a round brush `brush` points wide. When `clearAt`
    /// (0...1) of the cover is gone, the rest fades. `onChange` receives the
    /// scratched fraction. To cover the card again, give the view a new `.id`.
    public static func scratch(_ cover: XeerpeChain, brush: Double = 36, clearAt: Double = 0.55,
                               onChange: (@MainActor (Double) -> Void)? = nil) -> XeerpeEffect {
        XeerpeEffect(name: "scratch", slot: .mask, claims: [.reveal]) { view in
            AnyView(XeerpeScratchView(content: view, cover: AnyView(Color.clear.xeerpe(cover)),
                                      brush: max(brush, 1), clearAt: Xeerpe.clampUnit(clearAt), onChange: onChange))
        }
    }
}
