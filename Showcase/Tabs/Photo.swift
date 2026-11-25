#if os(macOS)
import SwiftUI
import xeerpe

// Photo looks: an editor with a filter strip, then the film look built
// one piece at a time, each piece compared with the step before.

@MainActor
struct FilmDemo: View {
    private let grade = XeerpeChain { .grade(contrast: 0.1, warmth: 0.2, fade: 0.2) }
    private var halation: XeerpeChain { grade.halation(intensity: 0.9) }
    private var leak: XeerpeChain { halation.lightLeak() }
    private var grain: XeerpeChain { leak.grain(0.25) }

    /// One step: this chain against the one before it, split by a handle,
    /// with what to look for.
    private func stage(_ title: String, _ look: String, _ code: String, before: XeerpeChain, after: XeerpeChain) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Compare(before: photo().xeerpe(before), after: photo().xeerpe(after)).frame(height: 170).clipShape(tile)
            Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(.white)
            Text(look).font(.callout).foregroundStyle(.white.opacity(0.6)).fixedSize(horizontal: false, vertical: true)
            CodeView(code)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Film, piece by piece", "Each photo shows one step: left of the line the step before, right of it the step added. Drag the line to compare.")
            HStack(alignment: .top, spacing: 14) {
                stage("1 · Grade", "Warmer colors, blacks lifted to grey, a touch more contrast.",
                      "photo.xeerpe { .grade(contrast: 0.1, warmth: 0.2, fade: 0.2) }", before: XeerpeChain(), after: grade)
                stage("2 · Halation", "A red glow where the bright sun meets the mountains.", "+ .halation(intensity: 0.9)", before: grade, after: halation)
                stage("3 · Light leak", "Warm light bleeding in from the left and right edges, drifting slowly.", "+ .lightLeak()", before: halation, after: leak)
            }
            HStack(alignment: .top, spacing: 14) {
                stage("4 · Grain", "Fine specks that move like running film, strongest in the mid-tones.", "+ .grain(0.25)", before: leak, after: grain)
                stage("The preset", "The same kind of chain in one call, against the original.", "photo.xeerpe(.film())", before: XeerpeChain(), after: .film())
                stage("Edit the preset", "The film preset with its light leak taken out, against the full preset.",
                      "photo.xeerpe(.film().without(.lightLeak))", before: .film(), after: .film().without(.lightLeak))
            }
            HStack(alignment: .top, spacing: 14) {
                step("photo.xeerpe(.polaroid()), in a paper frame") {
                    VStack(spacing: 8) {
                        photo(height: 150).xeerpe(.polaroid())
                        Text("Dolomites, '98").font(.system(.callout, design: .serif).italic()).foregroundStyle(Color(white: 0.25))
                    }
                    .padding(10).padding(.bottom, 4)
                    .background(Color(red: 0.97, green: 0.96, blue: 0.92), in: RoundedRectangle(cornerRadius: 4))
                    .rotationEffect(.degrees(-2))
                }
                step("photo.xeerpe(.duotone()\n    .replacing(.colorMap, with: .gradientMap(\n        [.indigo, .orange], amount: .hover(from: 1, to: 0))))") {
                    VStack(alignment: .leading, spacing: 8) {
                        photo().xeerpe(.duotone().replacing(.colorMap, with: .gradientMap([.indigo, .orange], amount: .hover(from: 1, to: 0))))
                        Text("A duotone in other inks that fades to the original under the pointer.").font(.callout).foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
    }
}

/// A filter strip under a large photo, as in a photo app. Each look has a
/// name and one line on what it does; the line on the photo compares it with
/// the original.
@MainActor
struct PhotoEditor: View {
    private struct Look { let name: String, does: String, code: String, chain: XeerpeChain }
    private let looks = [
        Look(name: "Original", does: "The photo as it is.", code: "photo", chain: XeerpeChain()),
        Look(name: "Cinematic", does: "Teal shadows, warm highlights, more contrast, dark corners: the blockbuster look.",
             code: "photo.xeerpe(.cinematic())", chain: .cinematic()),
        Look(name: "Film", does: "A warm faded grade, a red glow around the sun, a light leak, grain, dark corners.",
             code: "photo.xeerpe(.film())", chain: .film()),
        Look(name: "Polaroid", does: "Warm and washed out, soft contrast, fine grain: an instant photo.",
             code: "photo.xeerpe(.polaroid())", chain: .polaroid()),
        Look(name: "Noir", does: "Black and white with hard contrast, heavy grain and deep corners.",
             code: "photo.xeerpe(.noir())", chain: .noir()),
        Look(name: "Duotone", does: "Only two inks: the shadows indigo, the lights pink.",
             code: "photo.xeerpe(.duotone())", chain: .duotone()),
    ]
    @State private var pick = 1

    var body: some View {
        let look = looks[pick]
        VStack(alignment: .leading, spacing: 18) {
            heading("Photo editor", "Pick a look under the photo. Drag the line on the photo to compare it with the original.")
            HStack(alignment: .top, spacing: 24) {
                Compare(before: photo(height: 330), after: photo(height: 330).xeerpe(look.chain))
                    .frame(width: 600, height: 330).clipShape(tile)
                VStack(alignment: .leading, spacing: 10) {
                    Text(look.name).font(.system(.title2, design: .rounded).bold()).foregroundStyle(.white)
                    Text(look.does).foregroundStyle(.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
                    CodeView(look.code)
                }
            }
            HStack(spacing: 10) {
                ForEach(looks.indices, id: \.self) { i in
                    Button { pick = i } label: {
                        VStack(spacing: 6) {
                            photo(height: 64).xeerpe(looks[i].chain)
                                .overlay { tile.strokeBorder(.white, lineWidth: i == pick ? 2 : 0) }
                            Text(looks[i].name).font(.caption).foregroundStyle(.white.opacity(i == pick ? 1 : 0.6))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// `before` left of a vertical line, `after` right of it. Drag to move the
/// line; it starts in the middle.
@MainActor
struct Compare<Before: View, After: View>: View {
    let before: Before, after: After
    @State private var split = 0.5

    var body: some View {
        GeometryReader { g in
            let x = g.size.width * split
            ZStack(alignment: .topLeading) {
                after
                before.mask(alignment: .leading) { Rectangle().frame(width: x) }
                Rectangle().fill(.white).frame(width: 2).shadow(color: .black.opacity(0.5), radius: 2).offset(x: x - 1)
                Circle().fill(.white).frame(width: 18, height: 18).shadow(color: .black.opacity(0.4), radius: 3)
                    .offset(x: x - 9, y: g.size.height / 2 - 9)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { split = min(max($0.location.x / g.size.width, 0), 1) })
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Before and after")
        .accessibilityValue("\(Int(split * 100)) percent before")
        .accessibilityAdjustableAction { d in split = min(max(split + (d == .increment ? 0.1 : -0.1), 0), 1) }
    }
}
#endif
