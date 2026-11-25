import CoreGraphics
import Foundation

/// Detects a quick back-and-forth mouse shake from a stream of x positions.
/// A shake is at least three direction reversals, each swing at least `swing`
/// points wide, inside a short time window.
struct ShakeDetector {
    private var samples: [(x: CGFloat, t: TimeInterval)] = []
    private let window: TimeInterval = 0.8
    private let swing: CGFloat = 45
    private let reversalsNeeded = 3

    mutating func reset() { samples.removeAll() }

    mutating func add(x: CGFloat, at t: TimeInterval) -> Bool {
        samples.append((x, t))
        samples.removeAll { t - $0.t > window }
        guard samples.count >= 6 else { return false }

        var reversals = 0
        var direction = 0
        var anchor = samples[0].x
        for s in samples.dropFirst() {
            let dx = s.x - anchor
            guard abs(dx) >= swing else { continue }
            let d = dx > 0 ? 1 : -1
            if direction != 0 && d != direction { reversals += 1 }
            direction = d
            anchor = s.x
        }
        if reversals >= reversalsNeeded {
            samples.removeAll()
            return true
        }
        return false
    }
}
