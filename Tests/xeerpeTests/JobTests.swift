import SwiftUI
import Testing
@testable import xeerpe

/// Lets a test decide when a job's work finishes.
actor Gate<T: Sendable> {
    private var waiting: CheckedContinuation<T, any Error>?
    private var ready: Result<T, any Error>?
    func wait() async throws -> T {
        if let ready { return try ready.get() }
        return try await withCheckedThrowingContinuation { waiting = $0 }
    }
    func open(_ r: Result<T, any Error>) {
        if let waiting { waiting.resume(with: r); self.waiting = nil } else { ready = r }
    }
}

struct Boom: Error {}

@MainActor
func settle(_ job: XeerpeJob<Int>, until phase: XeerpePhase) async {
    for _ in 0..<500 where job.phase != phase { await Task.yield(); try? await Task.sleep(for: .milliseconds(1)) }
}

@MainActor
@Suite struct JobTests {
    @Test func startsIdle() {
        let job = XeerpeJob<Int>()
        #expect(job.phase == .idle)
        #expect(job.value == nil)
    }

    @Test func runGoesPendingThenDone() async {
        let job = XeerpeJob<Int>()
        let gate = Gate<Int>()
        let n = Int.random(in: 1...1000)
        job.run { _ in try await gate.wait() }
        #expect(job.phase == .pending)
        await gate.open(.success(n))
        await settle(job, until: .done)
        #expect(job.phase == .done)
        #expect(job.value == n)
        #expect(job.progress == 1)
    }

    @Test func progressStreamsAndIsClamped() async {
        let job = XeerpeJob<Int>()
        let gate = Gate<Int>()
        job.run { report in
            await report(0.3, 7)
            await report(5)
            return try await gate.wait()
        }
        await settle(job, until: .streaming)
        for _ in 0..<50 where job.progress < 1 { await Task.yield() }
        #expect(job.phase == .streaming)
        #expect(job.progress == 1)
        #expect(job.value == 7)
        await gate.open(.success(8))
        await settle(job, until: .done)
        #expect(job.value == 8)
    }

    @Test func failureEndsFailedAndKeepsLastValue() async {
        let job = XeerpeJob<Int>()
        job.run { _ in 1 }
        await settle(job, until: .done)
        job.run { _ in throw Boom() }
        await settle(job, until: .failed)
        #expect(job.phase == .failed)
        #expect(job.error is Boom)
        #expect(job.value == 1)
    }

    /// Latest wins: a run started earlier and finishing later never lands.
    @Test func newerRunWinsOverLateOlderRun() async {
        let job = XeerpeJob<Int>()
        let first = Gate<Int>(), second = Gate<Int>()
        job.run { _ in try await first.wait() }
        job.run { _ in try await second.wait() }
        await second.open(.success(2))
        await settle(job, until: .done)
        await first.open(.success(1))
        for _ in 0..<50 { await Task.yield() }
        #expect(job.value == 2)
    }

    @Test func cancelReturnsToIdle() async {
        let job = XeerpeJob<Int>()
        let gate = Gate<Int>()
        job.run { _ in try await gate.wait() }
        job.cancel()
        #expect(job.phase == .idle)
        await gate.open(.success(9))
        for _ in 0..<50 { await Task.yield() }
        #expect(job.phase == .idle)
        #expect(job.value == nil)
    }

    @Test func countsEveryEntryIntoAPhase() async {
        let job = XeerpeJob<Int>()
        let runs = Int.random(in: 1...6)
        for i in 0..<runs {
            job.run { _ in i }
            await settle(job, until: .done)
        }
        #expect(job.entries(.done) == runs)
        #expect(job.entries(.pending) == runs)
        #expect(job.entries(.failed) == 0)
    }
}

@MainActor
@Suite struct JobSignalTests {
    @Test func signalsReadTheJob() async {
        let job = XeerpeJob<Int>()
        let ctx = XeerpeContext()
        #expect(XeerpeValue.phase(job, is: .idle).value(in: ctx) == 1)
        #expect(XeerpeValue.phase(job, is: .done).value(in: ctx) == 0)
        job.run { _ in 4 }
        await settle(job, until: .done)
        #expect(XeerpeValue.phase(job, is: .done).value(in: ctx) == 1)
        #expect(XeerpeValue.progress(job).value(in: ctx) == 1)
        #expect(XeerpeSignal.result(job, or: 0) { Double($0) * 2 }.value(in: ctx) == 8)
        #expect(XeerpeValue.phaseTime(job).inputs.contains(.time))
    }

    @Test func enteredTriggerChangesOnEachEntry() async {
        let job = XeerpeJob<Int>()
        let t = XeerpeTrigger.entered(.done, of: job)
        let ctx = XeerpeContext()
        let before = t.signal.value(in: ctx)
        job.run { _ in 1 }
        await settle(job, until: .done)
        #expect(Xeerpe.fires(from: before, to: t.signal.value(in: ctx), risingOnly: t.risingOnly))
    }

    @Test func phasesEffectWiresInputsOfEveryPhase() {
        let job = XeerpeJob<Int>()
        let e = XeerpeEffect.phases(job) { phase in
            switch phase {
            case .pending: XeerpeChain.breathe()
            case .done: XeerpeChain.scale(.hover(from: 1, to: 1.1))
            default: XeerpeChain()
            }
        }
        #expect(e.inputs.contains(.time))
        #expect(e.inputs.contains(.hover))
    }
}
