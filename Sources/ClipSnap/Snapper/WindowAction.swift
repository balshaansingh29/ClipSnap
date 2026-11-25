import AppKit

/// Every layout the snapper can apply. All geometry here is in "AX space":
/// origin at the top-left of the primary display, y increasing downward,
/// which is what the Accessibility API uses for window frames.
enum WindowAction: String, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case firstThird, centerThird, lastThird, firstTwoThirds, lastTwoThirds
    case maximize, almostMaximize, center
    case restore, nextDisplay, previousDisplay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .firstThird: "First Third"
        case .centerThird: "Center Third"
        case .lastThird: "Last Third"
        case .firstTwoThirds: "First Two Thirds"
        case .lastTwoThirds: "Last Two Thirds"
        case .maximize: "Maximize"
        case .almostMaximize: "Almost Maximize"
        case .center: "Center"
        case .restore: "Restore"
        case .nextDisplay: "Next Display"
        case .previousDisplay: "Previous Display"
        }
    }

    /// Region of the screen this action fills, as fractions (x, y, w, h) with a
    /// top-left origin. Nil for actions that don't have a fixed region.
    func unitRect(step: Int = 0, almostMax: Double = 0.9) -> CGRect? {
        let cycle: [CGFloat] = [1.0 / 2, 2.0 / 3, 1.0 / 3]
        let f = cycle[step % cycle.count]
        switch self {
        case .leftHalf: return CGRect(x: 0, y: 0, width: f, height: 1)
        case .rightHalf: return CGRect(x: 1 - f, y: 0, width: f, height: 1)
        case .topHalf: return CGRect(x: 0, y: 0, width: 1, height: f)
        case .bottomHalf: return CGRect(x: 0, y: 1 - f, width: 1, height: f)
        case .topLeft: return CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .topRight: return CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .bottomLeft: return CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRight: return CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .firstThird:
            // Repeated presses walk across the screen: first -> center -> last.
            let i = CGFloat(step % 3)
            return CGRect(x: i / 3, y: 0, width: 1.0 / 3, height: 1)
        case .lastThird:
            let i = CGFloat(2 - (step % 3))
            return CGRect(x: i / 3, y: 0, width: 1.0 / 3, height: 1)
        case .centerThird: return CGRect(x: 1.0 / 3, y: 0, width: 1.0 / 3, height: 1)
        case .firstTwoThirds: return CGRect(x: 0, y: 0, width: 2.0 / 3, height: 1)
        case .lastTwoThirds: return CGRect(x: 1.0 / 3, y: 0, width: 2.0 / 3, height: 1)
        case .maximize: return CGRect(x: 0, y: 0, width: 1, height: 1)
        case .almostMaximize:
            let m = CGFloat(almostMax)
            return CGRect(x: (1 - m) / 2, y: (1 - m) / 2, width: m, height: m)
        case .center, .restore, .nextDisplay, .previousDisplay: return nil
        }
    }

    /// Whether pressing the same shortcut again should cycle sizes.
    var cycles: Bool {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf, .firstThird, .lastThird: true
        default: false
        }
    }
}
