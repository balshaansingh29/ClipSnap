import AppKit

/// Conversions between AppKit screen coordinates (origin bottom-left of the
/// primary display) and Accessibility coordinates (origin top-left).
enum ScreenGeometry {
    static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Converts a rect between the two spaces. The conversion is its own inverse.
    static func flip(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    static func flip(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x, y: primaryHeight - p.y)
    }

    /// Usable area (excludes menu bar and Dock) of a screen, in AX space.
    static func visibleAX(_ screen: NSScreen) -> CGRect { flip(screen.visibleFrame) }

    /// Full frame of a screen, in AX space.
    static func frameAX(_ screen: NSScreen) -> CGRect { flip(screen.frame) }

    /// The screen where most of `axRect` sits.
    static func screen(for axRect: CGRect) -> NSScreen? {
        var best: (NSScreen, CGFloat)?
        for s in NSScreen.screens {
            let i = frameAX(s).intersection(axRect)
            let area = i.isNull ? 0 : i.width * i.height
            if best == nil || area > best!.1 { best = (s, area) }
        }
        return best?.0 ?? NSScreen.main
    }

    /// Screens ordered left to right, so "next display" is spatially predictable.
    static var screensLeftToRight: [NSScreen] {
        NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
    }

    /// Resolves a unit rect against a visible area, with an optional gap.
    static func resolve(unit: CGRect, in area: CGRect, gap: CGFloat) -> CGRect {
        let r = CGRect(x: area.minX + unit.minX * area.width,
                       y: area.minY + unit.minY * area.height,
                       width: unit.width * area.width,
                       height: unit.height * area.height)
        return gap > 0 ? r.insetBy(dx: gap / 2, dy: gap / 2) : r
    }
}
