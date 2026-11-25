#if os(macOS)
import SwiftUI
import xeerpe

// Shapes, sample content and helpers used by more than one tab.

let card = RoundedRectangle(cornerRadius: 22, style: .continuous)

@MainActor
struct Phone<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        ZStack(alignment: .top) {
            content.frame(width: 280, height: 600).clipShape(RoundedRectangle(cornerRadius: 46, style: .continuous))
            HStack {
                Text("9:41").font(.system(size: 13, weight: .semibold))
                Spacer()
                Image(systemName: "wifi"); Image(systemName: "battery.75")
            }
            .font(.system(size: 12)).foregroundStyle(.white).padding(.horizontal, 30).padding(.top, 18)
            .frame(width: 280)
            Capsule().fill(.black).frame(width: 96, height: 28).padding(.top, 12)
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 54, style: .continuous).fill(Color(white: 0.09)))
        .overlay(RoundedRectangle(cornerRadius: 54, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1.5))
    }
}

let panel = RoundedRectangle(cornerRadius: 28, style: .continuous)

@MainActor
func caption(_ title: String, _ hint: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.system(.title3, design: .rounded).bold()).foregroundStyle(.white)
        Text(hint).font(.callout).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
    }
}

/// A custom effect, written in place: a shake that dies out over the
/// first second of the job's phase.
@MainActor
func shake<V>(_ job: XeerpeJob<V>) -> XeerpeEffect {
    let t = XeerpeValue.phaseTime(job)
    return XeerpeEffect(name: "shake", slot: .geometry, inputs: t.inputs) { view, ctx in
        let s = t.value(in: ctx)
        return AnyView(view.offset(x: sin(s * 48) * 12 * exp(-s * 5)))
    }
}

let tile = RoundedRectangle(cornerRadius: 18, style: .continuous)

/// A mountain landscape at golden hour, drawn in one Canvas so shaders that
/// sample around a pixel (halation, ascii) see it as a single layer.
@MainActor
func photo(height: Double = 170) -> some View {
    Canvas { c, size in
        let w = size.width, h = size.height
        c.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(red: 0.2, green: 0.42, blue: 0.85), Color(red: 0.62, green: 0.68, blue: 0.9), Color(red: 1, green: 0.78, blue: 0.55)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.7)))
        let sun = CGPoint(x: w * 0.72, y: h * 0.42)
        c.fill(Path(ellipseIn: CGRect(x: sun.x - 60, y: sun.y - 60, width: 120, height: 120)),
               with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.9, blue: 0.6).opacity(0.9), .clear]), center: sun, startRadius: 10, endRadius: 60))
        c.fill(Path(ellipseIn: CGRect(x: sun.x - 16, y: sun.y - 16, width: 32, height: 32)), with: .color(Color(red: 1, green: 0.98, blue: 0.9)))
        func ridge(_ base: Double, _ peaks: [(Double, Double)], _ color: Color) {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: h))
            p.addLine(to: CGPoint(x: 0, y: h * base))
            for (x, y) in peaks { p.addLine(to: CGPoint(x: w * x, y: h * y)) }
            p.addLine(to: CGPoint(x: w, y: h * base))
            p.addLine(to: CGPoint(x: w, y: h))
            c.fill(p, with: .color(color))
        }
        ridge(0.6, [(0.12, 0.38), (0.25, 0.52), (0.4, 0.3), (0.55, 0.5), (0.68, 0.42), (0.85, 0.55)], Color(red: 0.42, green: 0.42, blue: 0.62))
        ridge(0.72, [(0.08, 0.58), (0.2, 0.66), (0.33, 0.5), (0.5, 0.68), (0.7, 0.56), (0.9, 0.66)], Color(red: 0.2, green: 0.32, blue: 0.35))
        c.fill(Path(CGRect(x: 0, y: h * 0.78, width: w, height: h * 0.22)), with: .linearGradient(
            Gradient(colors: [Color(red: 0.3, green: 0.5, blue: 0.22), Color(red: 0.1, green: 0.22, blue: 0.1)]),
            startPoint: CGPoint(x: 0, y: h * 0.78), endPoint: CGPoint(x: 0, y: h)))
        var tent = Path()
        tent.move(to: CGPoint(x: w * 0.22, y: h * 0.9))
        tent.addLine(to: CGPoint(x: w * 0.29, y: h * 0.74))
        tent.addLine(to: CGPoint(x: w * 0.36, y: h * 0.9))
        tent.closeSubpath()
        c.fill(tent, with: .color(Color(red: 0.9, green: 0.2, blue: 0.15)))
        for (x, s) in [(0.08, 1.0), (0.13, 0.75), (0.82, 1.1), (0.9, 0.8)] {
            var tree = Path()
            tree.move(to: CGPoint(x: w * x, y: h * (0.88 - 0.2 * s)))
            tree.addLine(to: CGPoint(x: w * x + 12 * s, y: h * 0.9))
            tree.addLine(to: CGPoint(x: w * x - 12 * s, y: h * 0.9))
            tree.closeSubpath()
            c.fill(tree, with: .color(Color(red: 0.05, green: 0.15, blue: 0.08)))
        }
    }
    .frame(height: height)
    .clipShape(tile)
}
#endif
