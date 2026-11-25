import Foundation
import SwiftUI
import Observation

/// Follows the system Low Power Mode. Observable: views that read
/// `isLowPower` update when the mode changes.
@MainActor @Observable
final class XeerpePowerSource {
    static let shared = XeerpePowerSource()
    private(set) var isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private init() {
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
        }
    }
}

extension Xeerpe {
    /// Seconds between chain frames: half the rate in Low Power Mode, and
    /// lower on the watch.
    static func frameInterval(lowPower: Bool) -> TimeInterval {
        #if os(watchOS)
        (lowPower ? 2.0 : 1.0) / 15
        #else
        (lowPower ? 2.0 : 1.0) / 60
        #endif
    }
}

/// A timeline at the chain's frame rate for views that animate on their
/// own; hands its content the seconds since the reference date.
struct XeerpeTicker<Content: View>: View {
    let paused: Bool
    @ViewBuilder let content: (TimeInterval) -> Content

    var body: some View {
        TimelineView(.animation(minimumInterval: Xeerpe.frameInterval(lowPower: XeerpePowerSource.shared.isLowPower), paused: paused)) {
            content($0.date.timeIntervalSinceReferenceDate)
        }
    }
}
