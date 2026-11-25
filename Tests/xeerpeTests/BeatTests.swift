import SwiftUI
import Testing
@testable import xeerpe

@Suite struct BeatTests {
    /// One swell per cycle that reaches 1, rests at the end of the cycle,
    /// and has no second peak as strong as the first.
    @Test func shapeHasOneSoftPeakPerCycle() {
        let samples = (0..<1000).map { Xeerpe.beatShape(Double($0) / 1000) }
        #expect(abs((samples.max() ?? 0) - 1) < 1e-3)
        #expect(samples.allSatisfy { (0...1).contains($0) })
        #expect(samples[800...].allSatisfy { $0 < 1e-9 })
        // After the main swell has fallen, nothing comes back above a quarter.
        let peak = samples.firstIndex { $0 > 0.999 }!
        let fallen = samples[peak...].firstIndex { $0 < 0.2 }!
        #expect(samples[fallen...].allSatisfy { $0 < 0.25 })
        // Soft: no step between neighbouring samples is a jump.
        #expect(zip(samples, samples.dropFirst()).allSatisfy { abs($0 - $1) < 0.03 })
        #expect(Xeerpe.beatShape(.nan) == 0)
    }

    /// The clock integrates the rate, so a changing rate never makes the
    /// phase jump back, and the beat count matches the integral.
    @Test func clockIntegratesAChangingRate() {
        for _ in 0..<20 {
            let clock = XeerpeBeatClock()
            var t = 0.0, expected = 0.0, last = clock.advance(to: 0, bpm: 60)
            for _ in 0..<300 {
                let dt = Double.random(in: 0.001...0.05), bpm = Double.random(in: 30...180)
                t += dt
                expected += bpm / 60 * dt
                let now = clock.advance(to: t, bpm: bpm)
                #expect(now >= last)
                last = now
            }
            #expect(abs(last - expected) < 1e-6)
        }
    }

    @Test func badInputsDoNotMoveTheClock() {
        let clock = XeerpeBeatClock()
        _ = clock.advance(to: 1, bpm: 60)
        #expect(clock.advance(to: 0.5, bpm: 60) == 0)
        #expect(clock.advance(to: 2, bpm: .nan) == 0)
        #expect(clock.advance(to: 3, bpm: -50) == 0)
    }

    @MainActor @Test func beatReadsTimeAndItsRate() {
        #expect(XeerpeValue.beat(.hover(from: 60, to: 120)).inputs.isSuperset(of: [.time, .hover]))
        #expect(XeerpeTrigger.beat(72).signal.inputs.contains(.time))
    }
}
