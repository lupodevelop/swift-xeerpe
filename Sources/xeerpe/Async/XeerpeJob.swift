import SwiftUI
import Observation

/// Where an asynchronous job is.
public enum XeerpePhase: String, Sendable, CaseIterable, Hashable {
    /// Not started, or cancelled.
    case idle
    /// Started, nothing reported yet.
    case pending
    /// Reporting progress or partial values.
    case streaming
    /// Finished with a value.
    case done
    /// Finished with an error.
    case failed
}

/// Any asynchronous work whose state drives effects: a network call, a
/// model response, a file load, a sensor reading. Views and signals read
/// it, so a change of phase, progress or value updates every effect that
/// depends on it.
///
/// `run` starts the work and cancels the run before it. Only the latest run
/// changes the job: a cancelled or older run that finishes late is ignored.
/// The work runs off the main actor; the job changes on the main actor.
@MainActor @Observable
public final class XeerpeJob<Value: Sendable> {
    public private(set) var phase: XeerpePhase = .idle
    /// The last value reported or returned. Kept when a later run fails.
    public private(set) var value: Value?
    /// 0...1: what the work reported, 1 when done.
    public private(set) var progress: Double = 0
    public private(set) var error: (any Error)?
    /// When the current phase began.
    public private(set) var phaseStart = Date()
    private var counts: [XeerpePhase: Int] = [:]

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    public init() {}

    /// What the work calls to report progress (0...1) and, optionally, a
    /// partial value. The first report moves the job to `.streaming`.
    public struct Report: Sendable {
        let send: @Sendable (Double?, Value?) async -> Void
        public func callAsFunction(_ progress: Double, _ partial: Value? = nil) async { await send(progress, partial) }
        public func callAsFunction(partial: Value) async { await send(nil, partial) }
    }

    /// How many times the job has entered `phase`.
    public func entries(_ phase: XeerpePhase) -> Int { counts[phase, default: 0] }

    /// Starts `work`, cancelling any run in progress.
    public func run(_ work: @escaping @Sendable (Report) async throws -> Value) {
        task?.cancel()
        generation += 1
        let gen = generation
        progress = 0
        error = nil
        enter(.pending)
        let report = Report { [weak self] p, v in await self?.update(gen, p, v) }
        task = Task { [weak self] in
            do {
                let v = try await work(report)
                self?.finish(gen, .success(v))
            } catch {
                self?.finish(gen, .failure(error))
            }
        }
    }

    /// Stops the current run and returns to `.idle`. Keeps the last value.
    public func cancel() {
        task?.cancel()
        task = nil
        generation += 1
        progress = 0
        enter(.idle)
    }

    private func update(_ gen: Int, _ p: Double?, _ v: Value?) {
        guard gen == generation else { return }
        if phase != .streaming { enter(.streaming) }
        if let p { progress = Xeerpe.clampUnit(p) }
        if let v { value = v }
    }

    private func finish(_ gen: Int, _ result: Result<Value, any Error>) {
        guard gen == generation else { return }
        task = nil
        switch result {
        case .success(let v):
            value = v
            progress = 1
            enter(.done)
        case .failure(let e):
            error = e
            enter(.failed)
        }
    }

    private func enter(_ p: XeerpePhase) {
        phase = p
        phaseStart = Date()
        counts[p, default: 0] += 1
    }
}

// MARK: Signals and triggers

extension XeerpeValueConvertible where Self == XeerpeValue {
    /// 1 while `job` is in `phase`, else 0. Mix it to fade between looks.
    public static func phase<V>(_ job: XeerpeJob<V>, is phase: XeerpePhase) -> XeerpeValue {
        .init { _ in MainActor.assumeIsolated { job.phase == phase ? 1 : 0 } }
    }

    /// Seconds since `job` entered its current phase: a wait can change look
    /// the longer it lasts. Runs frames.
    public static func phaseTime<V>(_ job: XeerpeJob<V>) -> XeerpeValue {
        .init(inputs: .time) { _ in MainActor.assumeIsolated { Date().timeIntervalSince(job.phaseStart) } }
    }

    /// Progress reported by `job`, 0...1.
    public static func progress<V>(_ job: XeerpeJob<V>) -> XeerpeValue {
        .init { _ in MainActor.assumeIsolated { job.progress } }
    }
}

extension XeerpeSignal {
    /// `job`'s value through `transform`, or `fallback` while there is none.
    public static func result<V>(_ job: XeerpeJob<V>, or fallback: Value, _ transform: @escaping (V) -> Value) -> XeerpeSignal<Value> {
        .init { _ in MainActor.assumeIsolated { job.value }.map(transform) ?? fallback }
    }
}

extension XeerpeTrigger {
    /// Fires each time `job` enters `phase`.
    public static func entered<V>(_ phase: XeerpePhase, of job: XeerpeJob<V>) -> XeerpeTrigger {
        XeerpeTrigger(.init { _ in MainActor.assumeIsolated { job.entries(phase) } }, risingOnly: true)
    }
}

// MARK: One chain per phase

extension XeerpeEffect {
    /// Renders the chain `build` returns for `job`'s current phase. When the
    /// phase changes the new look comes in with `transition` over the old
    /// one. During the transition both looks are drawn, and the content gets
    /// a new identity on each phase, so keep its state outside the view.
    public static func phases<V>(_ job: XeerpeJob<V>, transition: XeerpeReveal = .fluid, glow: Color = .white,
                                 duration: Double = 0.7,
                                 _ build: (XeerpePhase) -> XeerpeChain) -> XeerpeEffect {
        let chains = Dictionary(uniqueKeysWithValues: XeerpePhase.allCases.map { ($0, build($0)) })
        let inputs = chains.values.reduce(XeerpeInput()) { $0.union($1.inputs) }
        return XeerpeEffect(name: "phases", slot: .content, inputs: inputs) { view, ctx in
            let phase = job.phase
            return AnyView(ZStack {
                (chains[phase] ?? XeerpeChain()).render(view, context: ctx)
                    .id(phase)
                    .transition(.xeerpe(transition, glow: glow))
            }
            .animation(.easeInOut(duration: Swift.max(duration, 0)), value: phase))
        }
    }
}
