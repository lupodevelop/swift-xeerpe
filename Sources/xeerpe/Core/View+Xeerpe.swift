import SwiftUI
import OSLog

private let log = Logger(subsystem: "xeerpe", category: "chain")

/// Gathers the local inputs the chain declared, and only those: a chain with
/// no `.time` input schedules no frames, and hover, pointer, press, tap,
/// touch, drag and tilt listeners are attached only when some effect reads
/// them. Listeners sit on the view's layout frame, so a scale or distortion
/// never moves the hit area. Time is measured from when the view appeared.
/// Vector inputs (tilt, touch, drag) are smoothed and run frames only while
/// they move: during a gesture, while hovered, and briefly after release.
/// In Low Power Mode frames run at half the rate.
struct XeerpeModifier: ViewModifier {
    let chain: XeerpeChain
    let inputs: XeerpeInput

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isFocused) private var isFocused
    @Environment(\.scenePhase) private var scenePhase
    #if os(macOS)
    @Environment(\.controlActiveState) private var windowState
    #endif
    #if !os(watchOS)
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    #endif
    @State private var isHovering = false
    @GestureState private var pressing = false
    private var isPressed: Bool { pressing }
    @State private var pointer: CGPoint?
    @State private var tap: XeerpeTap?
    @State private var tapActive = false
    @State private var start = Date()
    @State private var size: CGSize = .zero
    @State private var dragLocation: CGPoint?
    @State private var dragTranslation: CGSize = .zero
    @State private var settling = false
    @State private var settleToken = 0
    @State private var smoothers = XeerpeSmoothers()

    init(chain: XeerpeChain) {
        self.chain = chain
        self.inputs = chain.inputs
        for c in chain.conflicts {
            log.warning("Effects \(c.first) and \(c.second) both claim \(c.property.rawValue)")
        }
    }

    private struct Interaction: Equatable { var hover: Bool, press: Bool, focus: Bool }
    private var usesVectors: Bool { !inputs.isDisjoint(with: [.tilt, .touch, .drag]) }

    private var deviceTilt: Bool {
        #if os(iOS) || os(watchOS)
        inputs.contains(.tilt) && XeerpeMotionSource.shared.isAvailable
        #else
        false
        #endif
    }

    private var needsFrames: Bool {
        guard !reduceMotion else { return false }
        if inputs.contains(.time) || (inputs.contains(.tap) && tapActive) { return true }
        guard usesVectors else { return false }
        return deviceTilt || dragLocation != nil || pointer != nil || settling
    }

    func body(content: Content) -> some View {
        let interaction = Interaction(hover: isHovering, press: isPressed, focus: isFocused)
        let animation: Animation? = reduceMotion ? nil : .smooth(duration: 0.25)

        // One TimelineView, paused when nothing moves: switching between a
        // timeline and a plain view would give the content a new identity
        // and reset the state of stateful effects (spoiler, scratch, reveal).
        let lowPower = XeerpePowerSource.shared.isLowPower
        let rendered = TimelineView(.animation(minimumInterval: Xeerpe.frameInterval(lowPower: lowPower), paused: !needsFrames)) { timeline in
            chain.render(AnyView(content), context: context(time: (needsFrames ? timeline.date : Date()).timeIntervalSince(start),
                                                            lowPower: lowPower))
        }
        // Listeners go around the rendered effects, on the view's layout
        // frame, which no effect moves. On the content itself, a rotation or
        // a scale would move the hit area with it: at the edges the pointer
        // would fall out, the effect would relax, the pointer would be back
        // in, and the view would flicker.
        return listening(AnyView(rendered))
        .animation(animation, value: interaction)
        .animation(animation, value: scenePhase)
        #if os(macOS)
        .animation(animation, value: windowState)
        #endif
        .modifier(MotionLifetime(active: inputs.contains(.tilt)))
    }

    private func context(time: TimeInterval, lowPower: Bool) -> XeerpeContext {
        #if os(watchOS)
        let transparency = false
        #else
        let transparency = reduceTransparency
        #endif
        var ctx = XeerpeContext(
            time: time,
            isHovering: isHovering,
            isPressed: isPressed,
            isFocused: isFocused,
            pointer: pointer,
            tap: tap,
            size: size,
            reduceMotion: reduceMotion,
            reduceTransparency: transparency,
            increasedContrast: contrast == .increased
        )
        ctx.isLowPower = lowPower
        #if os(macOS)
        // A Mac window counts as inactive when its app is not frontmost. The
        // scene phase is not used here: outside a SwiftUI App it is never active.
        ctx.isInactive = windowState == .inactive
        #else
        ctx.isInactive = scenePhase != .active
        #endif
        guard usesVectors else { return ctx }
        let touched = (dragLocation ?? pointer).map { Xeerpe.normalizedTouch($0, in: size) }
        if inputs.contains(.touch) {
            let t = smoothers.touch.step(touched ?? .zero, at: time)
            ctx.touch = touched == nil && hypot(t.x, t.y) < 0.002 ? nil : t
            if let touched { smoothers.lastFocus = touched }
            ctx.focus = smoothers.focus.step(smoothers.lastFocus, at: time)
            ctx.presence = Double(smoothers.presence.step(CGPoint(x: touched == nil ? 0 : 1, y: 0), at: time).x)
        }
        if inputs.contains(.drag) {
            ctx.drag = smoothers.drag.step(Xeerpe.normalizedDrag(dragTranslation, in: size), at: time)
        }
        if inputs.contains(.tilt) {
            var raw = touched ?? .zero
            #if os(iOS) || os(watchOS)
            if deviceTilt { raw = XeerpeMotionSource.shared.tilt }
            #endif
            ctx.tilt = smoothers.tilt.step(raw, at: time)
        }
        return ctx
    }

    private func settle() {
        settling = true
        settleToken += 1
        let token = settleToken
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            if token == settleToken { settling = false }
        }
    }

    private func listening(_ content: AnyView) -> AnyView {
        var view = AnyView(content)
        // Transparent areas of the frame count as part of the view for listeners.
        if !inputs.isDisjoint(with: [.hover, .pointer, .tap, .press, .touch, .drag, .tilt]) {
            view = AnyView(view.contentShape(Rectangle()))
        }
        if usesVectors {
            view = AnyView(view.background(GeometryReader { g in
                Color.clear.onAppear { size = g.size }.onChange(of: g.size) { _, s in size = s }
            }))
        }
        #if !os(tvOS) && !os(watchOS)
        if inputs.contains(.hover) { view = AnyView(view.onHover { isHovering = $0 }) }
        if !inputs.isDisjoint(with: [.pointer, .touch, .tilt]) {
            view = AnyView(view.onContinuousHover { phase in
                switch phase {
                case .active(let p): pointer = p
                case .ended: pointer = nil; settle()
                }
            })
        }
        if inputs.contains(.tap) {
            // Simultaneous: buttons and gestures underneath still get the tap.
            view = AnyView(view.simultaneousGesture(
                SpatialTapGesture().onEnded { value in
                    let now = Date().timeIntervalSince(start)
                    tap = XeerpeTap(location: value.location, time: now)
                    tapActive = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(Xeerpe.rippleLifetime))
                        if let t = tap, Date().timeIntervalSince(start) - t.time >= Xeerpe.rippleLifetime { tapActive = false }
                    }
                }
            ))
        }
        #endif
        #if !os(tvOS)
        if !inputs.isDisjoint(with: [.touch, .drag]) || (inputs.contains(.tilt) && !deviceTilt) {
            // Simultaneous, so controls inside still respond. A zero minimum
            // distance reports touches at once; inside a ScrollView prefer
            // `.drag`, which only starts after a short movement.
            let minimum: CGFloat = inputs.contains(.touch) || inputs.contains(.tilt) ? 0 : 6
            view = AnyView(view.simultaneousGesture(
                DragGesture(minimumDistance: minimum)
                    .onChanged { v in dragLocation = v.location; dragTranslation = v.translation }
                    .onEnded { _ in dragLocation = nil; dragTranslation = .zero; settle() }
            ))
        }
        // tvOS has no long-press gesture: press stays at its `from` value there.
        if inputs.contains(.press) {
            // Simultaneous and never completing: buttons, scrolling and
            // selection underneath keep working.
            // A long press that never completes never calls onEnded, so plain
            // state would stay set; gesture state resets on release and cancel.
            view = AnyView(view.simultaneousGesture(
                LongPressGesture(minimumDuration: .infinity, maximumDistance: 20)
                    .updating($pressing) { current, state, _ in state = current }
            ))
        }
        #endif
        return view
    }
}

/// Holds the accelerometer on while a view that reads tilt is on screen.
private struct MotionLifetime: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        #if os(iOS) || os(watchOS)
        if active {
            content.onAppear { XeerpeMotionSource.shared.acquire() }.onDisappear { XeerpeMotionSource.shared.release() }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

extension View {
    /// Applies a chain built line by line from effects, presets and chains
    /// kept in variables.
    ///
    ///     card.xeerpe {
    ///         .preset(.midnight, reacting: .tilt)
    ///         .scale(.press(from: 1, to: 0.96))
    ///         .feedback(.impact, sound: .pop, on: .press)
    ///     }
    public func xeerpe(@XeerpeBuilder _ build: () -> XeerpeChain) -> some View {
        modifier(XeerpeModifier(chain: build()))
    }

    /// Applies `chain` to the view.
    ///
    ///     photo.xeerpe(.film().without(.lightLeak))
    public func xeerpe(_ chain: XeerpeChain) -> some View {
        modifier(XeerpeModifier(chain: chain))
    }

    /// Draws the chain once at a fixed context, with no listeners and no
    /// clock: the same context gives the same picture. For snapshots and for
    /// exporting frames, where time, tilt and touch come from the caller.
    @MainActor
    public func xeerpe(_ chain: XeerpeChain, at context: XeerpeContext) -> some View {
        chain.render(AnyView(self), context: context)
    }
}
