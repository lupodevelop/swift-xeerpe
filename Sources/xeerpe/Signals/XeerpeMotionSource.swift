#if os(iOS) || os(watchOS)
import CoreMotion
import CoreGraphics

/// Shared accelerometer reader. Starts with the first view that needs tilt
/// and stops with the last. Tilt is measured from the pose the device had
/// when it started, so holding the phone at any angle reads as zero.
@MainActor
final class XeerpeMotionSource {
    static let shared = XeerpeMotionSource()
    private let manager = CMMotionManager()
    private var users = 0
    private var neutral: CMAcceleration?
    private(set) var tilt: CGPoint = .zero
    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func acquire() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        neutral = nil
        manager.deviceMotionUpdateInterval = Xeerpe.frameInterval(lowPower: XeerpePowerSource.shared.isLowPower)
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let g = motion?.gravity else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                let n = self.neutral ?? g
                self.neutral = n
                let clamp = { (v: Double) in Swift.min(Swift.max(v, -1), 1) }
                self.tilt = CGPoint(x: clamp((g.x - n.x) * 2.2), y: clamp((n.y - g.y) * 2.2))
            }
        }
    }

    func release() {
        users = Swift.max(users - 1, 0)
        if users == 0 { manager.stopDeviceMotionUpdates(); tilt = .zero }
    }
}
#endif
