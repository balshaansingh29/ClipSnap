import AppKit

/// Applies WindowActions to the focused window of the "target" app, i.e. the app
/// that was frontmost before ClipSnap's popover or a hotkey took over.
@MainActor
final class WindowManager: ObservableObject {
    /// Set by the popover when it opens so we act on the right app.
    var targetApp: NSRunningApplication?

    /// Fired after any action runs (used for the on-screen confirmation).
    var onPerformed: ((WindowAction) -> Void)?

    private let settings = AppSettings.shared
    private var originals: [CFHashCode: CGRect] = [:]
    private var last: (action: WindowAction, id: CFHashCode, rect: CGRect, step: Int)?

    // MARK: Entry points

    func perform(_ action: WindowAction) {
        guard Permissions.accessibilityGranted else {
            Permissions.promptForAccessibility()
            return
        }
        guard let win = focusedWindow(), win.isStandardWindow, let current = win.frame else { return }
        perform(action, on: win, current: current)
    }

    /// Used directly by drag-to-snap, which already knows the window.
    func perform(_ action: WindowAction, on win: AXWindow, current: CGRect? = nil) {
        guard let current = current ?? win.frame else { return }
        defer { onPerformed?(action) }
        let id = win.identity

        // Remember the pre-snap frame unless this is a repeat of our own last move.
        let isRepeatOfLast = last.map { $0.id == id && Self.near($0.rect, current) } ?? false
        if action != .restore, !isRepeatOfLast { originals[id] = current }

        let screen = ScreenGeometry.screen(for: current) ?? NSScreen.main
        guard let screen else { return }
        let area = ScreenGeometry.visibleAX(screen)
        let gap = CGFloat(settings.windowGap)

        switch action {
        case .restore:
            if let original = originals[id] { win.setFrame(original); last = nil }

        case .center:
            let size = CGSize(width: min(current.width, area.width), height: min(current.height, area.height))
            let rect = CGRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2,
                              width: size.width, height: size.height)
            apply(rect, action, win, id, step: 0)

        case .nextDisplay, .previousDisplay:
            moveToAdjacentDisplay(win, current: current, from: screen, forward: action == .nextDisplay)

        default:
            let step = (settings.cycleOnRepeat && action.cycles && isRepeatOfLast && last?.action == action)
                ? (last?.step ?? 0) + 1 : 0
            guard let unit = action.unitRect(step: step, almostMax: settings.almostMaxFraction) else { return }
            apply(ScreenGeometry.resolve(unit: unit, in: area, gap: gap), action, win, id, step: step)
        }
    }

    // MARK: Helpers

    private func apply(_ rect: CGRect, _ action: WindowAction, _ win: AXWindow, _ id: CFHashCode, step: Int) {
        win.setFrame(rect)
        // Record what the window actually ended up as: apps with min sizes may differ.
        last = (action, id, win.frame ?? rect, step)
    }

    private func moveToAdjacentDisplay(_ win: AXWindow, current: CGRect, from screen: NSScreen, forward: Bool) {
        let screens = ScreenGeometry.screensLeftToRight
        guard screens.count > 1, let idx = screens.firstIndex(of: screen) else { return }
        let next = screens[(idx + (forward ? 1 : screens.count - 1)) % screens.count]

        let from = ScreenGeometry.visibleAX(screen)
        let to = ScreenGeometry.visibleAX(next)
        let rx = (current.minX - from.minX) / from.width
        let ry = (current.minY - from.minY) / from.height
        let size = CGSize(width: min(current.width, to.width), height: min(current.height, to.height))
        let origin = CGPoint(x: min(to.minX + rx * to.width, to.maxX - size.width),
                             y: min(to.minY + ry * to.height, to.maxY - size.height))
        win.setFrame(CGRect(origin: origin, size: size))
        last = nil
    }

    private func focusedWindow() -> AXWindow? {
        let me = NSRunningApplication.current.processIdentifier
        var app = targetApp
        if app == nil || app?.isTerminated == true {
            app = NSWorkspace.shared.frontmostApplication
        }
        guard let app, app.processIdentifier != me else { return nil }
        return AXWindow.focused(of: app)
    }

    private static func near(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 3) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }
}
