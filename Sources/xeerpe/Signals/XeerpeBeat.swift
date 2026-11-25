import SwiftUI

extension Xeerpe {
    /// A heartbeat over one cycle (`phase` taken modulo 1): one soft swell
    /// that rises over the first 15% of the cycle and fades over the next
    /// 55%, with a faint echo after it, then rest. Peaks at 1.
    static func beatShape(_ phase: Double) -> Double {
        guard phase.isFinite else { return 0 }
        let p = phase - phase.rounded(.down)
        func swell(_ x: Double) -> Double {
            if x < 0 || x >= 0.7 { return 0 }
            if x < 0.15 { let s = sin(x / 0.15 * .pi / 2); return s * s }
            let c = cos((x - 0.15) / 0.55 * .pi / 2); return c * c
        }
        return Swift.min(Swift.max(swell(p), 0.22 * swell((p - 0.3) * 1.6)), 1)
    }
}

/// Counts beats by integrating a rate that may change at any time, so the
/// pulse speeds up or slows down smoothly instead of jumping.
final class XeerpeBeatClock: @unchecked Sendable {
    private var last: Double?
    private var beats = 0.0

    /// Beats elapsed at `time` seconds. Time going back, a non-finite rate
    /// or a negative one leaves the count where it is.
    func advance(to time: Double, bpm: Double) -> Double {
        defer { if time.isFinite, time >= (last ?? time) { last = time } }
        guard let l = last, time > l, bpm.isFinite, bpm > 0 else { return beats }
        beats += bpm / 60 * (time - l)
        return beats
    }
}

extension XeerpeValueConvertible where Self == XeerpeValue {
    /// Pulses like a heart, 0...1, at `bpm` beats per minute. The rate is a
    /// signal: a constant, the pointer, a value from a sensor or a job.
    /// With Reduce Motion it stays at 0.
    public static func beat(_ bpm: some XeerpeValueConvertible = 72) -> XeerpeValue {
        let bpm = bpm.xeerpeValue, clock = XeerpeBeatClock()
        return .init(inputs: bpm.inputs.union(.time)) { ctx in
            ctx.reduceMotion ? 0 : Xeerpe.beatShape(clock.advance(to: ctx.time, bpm: bpm.resolve(ctx)))
        }
    }
}

extension XeerpeTrigger {
    /// Fires on every beat at `bpm`: pair it with a haptic to feel the pulse.
    public static func beat(_ bpm: some XeerpeValueConvertible = 72) -> XeerpeTrigger {
        let bpm = bpm.xeerpeValue, clock = XeerpeBeatClock()
        return XeerpeTrigger(.init(inputs: bpm.inputs.union(.time)) { ctx in
            Int(clock.advance(to: ctx.time, bpm: bpm.resolve(ctx)).rounded(.down))
        }, risingOnly: true)
    }
}
