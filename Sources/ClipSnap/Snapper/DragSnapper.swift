import AppKit

/// Drag a window to a screen edge or corner to snap it, with a translucent
/// footprint preview (the same interaction Rectangle and Magnet offer).
@MainActor
final class DragSnapper {
    private let windows: WindowManager
    private let settings = AppSettings.shared
    private var monitors: [Any] = []

    private var dragged: AXWindow?
    private var startFrame: CGRect?
    private var isMoving = false
    private var pending: (action: WindowAction, screen: NSScreen)?
    private var footprint: NSWindow?
    private let palette = SnapPalette()
    private var footprintTask: Task<Void, Never>?
    private var shake = ShakeDetector()

    init(windows: WindowManager) { self.windows = windows }

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        if let m = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let type = event.type
            let location = NSEvent.mouseLocation
            Task { @MainActor in self?.handle(type, at: location) }
        }) {
            monitors.append(m)
        }
    }

    // MARK: Event handling

    private func handle(_ type: NSEvent.EventType, at point: CGPoint) {
        guard settings.dragSnapEnabled, Permissions.accessibilityGranted else { return }
        switch type {
        case .leftMouseDown:
            reset()
            guard let win = AXWindow.at(axPoint: ScreenGeometry.flip(point)), win.isStandardWindow else { return }
            dragged = win
            startFrame = win.frame

        case .leftMouseDragged:
            guard let win = dragged, let start = startFrame, let now = win.frame else { return }
            if !isMoving {
                // Only treat it as a window drag once the window itself has moved
                // without changing size (so resizing and in-window drags are ignored).
                let moved = abs(now.minX - start.minX) > 4 || abs(now.minY - start.minY) > 4
                let sameSize = abs(now.width - start.width) < 2 && abs(now.height - start.height) < 2
                guard moved, sameSize else { return }
                isMoving = true
            }
            // Shake the mouse mid-drag to pop up the layout palette at the cursor.
            if settings.shakeToSnap, !palette.isVisible,
               shake.add(x: point.x, at: ProcessInfo.processInfo.systemUptime) {
                palette.show(at: point)
            }
            updateFootprint(for: point)

        case .leftMouseUp:
            defer { reset() }
            guard isMoving, let win = dragged, let target = pending else { return }
            windows.perform(target.action, on: win)

        default:
            break
        }
    }

    // MARK: Zones

    private func zone(at p: CGPoint) -> (WindowAction, NSScreen)? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(p) }) else { return nil }
        let f = screen.frame
        let edge: CGFloat = 5
        let corner: CGFloat = 40

        let l = p.x - f.minX, r = f.maxX - p.x
        let t = f.maxY - p.y, b = p.y - f.minY
        let eL = l < edge, eR = r < edge, eT = t < edge, eB = b < edge
        guard eL || eR || eT || eB else { return nil }

        if (eL && t < corner) || (eT && l < corner) { return (.topLeft, screen) }
        if (eR && t < corner) || (eT && r < corner) { return (.topRight, screen) }
        if (eL && b < corner) || (eB && l < corner) { return (.bottomLeft, screen) }
        if (eR && b < corner) || (eB && r < corner) { return (.bottomRight, screen) }
        if eL { return (.leftHalf, screen) }
        if eR { return (.rightHalf, screen) }
        if eT { return (.maximize, screen) }
        return (.bottomHalf, screen)
    }

    // MARK: Footprint overlay

    private func updateFootprint(for point: CGPoint) {
        // A tile under the pointer wins; otherwise fall back to screen-edge zones.
        if palette.isVisible {
            palette.updateHover(at: point)
            if let action = palette.hovered,
               let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main {
                present(action, on: screen)
                return
            }
        }
        guard let (action, screen) = zone(at: point) else {
            pending = nil
            hideFootprint()
            return
        }
        present(action, on: screen)
    }

    /// Records the drop target immediately (so releasing always works), but shows the
    /// blue box a beat later so it reads as a response to the selector.
    private func present(_ action: WindowAction, on screen: NSScreen) {
        guard let unit = action.unitRect() else {
            pending = nil
            hideFootprint()
            return
        }
        // Same target as before: leave the pending reveal alone.
        if let p = pending, p.action == action, p.screen == screen { return }
        pending = (action, screen)

        let ax = ScreenGeometry.resolve(unit: unit, in: ScreenGeometry.visibleAX(screen),
                                        gap: CGFloat(settings.windowGap))
        let rect = ScreenGeometry.flip(ax).insetBy(dx: 4, dy: 4)

        let alreadyShowing = (footprint?.isVisible == true) && (footprint?.alphaValue ?? 0) > 0.5
        let delay: UInt64 = alreadyShowing ? 70_000_000 : 170_000_000

        footprintTask?.cancel()
        footprintTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self?.showFootprint(rect)
        }
    }

    private func showFootprint(_ rect: CGRect) {
        let w = footprint ?? makeFootprint()
        footprint = w
        if w.isVisible && w.alphaValue > 0.05 {
            w.setFrame(rect, display: true, animate: true)   // glide between regions
        } else {
            w.setFrame(rect, display: true, animate: false)
            w.alphaValue = 0
            w.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            w.animator().alphaValue = 1
        }
    }

    /// Fades the box out (used when the pointer leaves every target mid-drag).
    private func hideFootprint() {
        footprintTask?.cancel()
        guard let w = footprint, w.isVisible else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            w.animator().alphaValue = 0
        }
        Task { [weak self, weak w] in
            try? await Task.sleep(nanoseconds: 160_000_000)
            if self?.pending == nil { w?.orderOut(nil) }
        }
    }

    private func makeFootprint() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
                         styleMask: .borderless, backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = true
        w.level = .statusBar
        w.alphaValue = 0
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        v.wantsLayer = true
        v.autoresizingMask = [.width, .height]
        v.layer?.cornerRadius = 12
        v.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
        v.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.7).cgColor
        v.layer?.borderWidth = 2
        w.contentView = v
        return w
    }

    private func reset() {
        dragged = nil
        startFrame = nil
        isMoving = false
        pending = nil
        footprintTask?.cancel()
        footprint?.alphaValue = 0
        footprint?.orderOut(nil)
        palette.hide()
        shake.reset()
    }
}
