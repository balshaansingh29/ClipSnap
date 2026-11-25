import AppKit

/// Owns the long-lived services and is shared with the SwiftUI views.
@MainActor
final class AppModel: ObservableObject {
    let store = ClipStore()
    let monitor: ClipboardMonitor
    let windows = WindowManager()
    let settings = AppSettings.shared
    let paster: Paster
    let dragSnapper: DragSnapper
    let hud = HUDController()

    /// Bumped every time the popover opens so the UI can replay its entrance.
    @Published var openTick = 0
    /// The tab currently shown; the paste hotkey sets this to .clipboard.
    @Published var currentTab: PopoverTab = .clipboard

    /// The app that was frontmost when the popover opened; pastes go here.
    var previousApp: NSRunningApplication?
    /// Set by AppDelegate so views can dismiss the popover.
    var closePopover: () -> Void = {}

    init() {
        let monitor = ClipboardMonitor(store: store)
        self.monitor = monitor
        self.paster = Paster(store: store, monitor: monitor)
        self.dragSnapper = DragSnapper(windows: windows)
    }

    func start() {
        windows.onPerformed = { [weak self] action in
            self?.hud.show(action.title, detail: Bindings.label(for: action), mood: .happy)
        }
        monitor.start()
        dragSnapper.start()
        registerHotkeys()
        if !Permissions.accessibilityGranted { Permissions.promptForAccessibility() }
    }

    // MARK: Actions used by the UI

    func paste(_ item: ClipItem, plain: Bool) {
        let target = previousApp
        closePopover()
        paster.paste(item, plain: plain, into: target)
        if settings.pasteAutomatically && !Permissions.accessibilityGranted {
            hud.show("Copied", detail: "Allow Accessibility to paste for you", mood: .surprised)
        } else {
            hud.show(settings.pasteAutomatically ? (plain ? "Pasted as plain text" : "Pasted") : "Copied",
                     detail: Self.detail(for: item), mood: .happy)
        }
    }

    func copyOnly(_ item: ClipItem, plain: Bool) {
        paster.copy(item, plain: plain)
        closePopover()
        hud.show("Copied", detail: Self.detail(for: item), mood: .happy)
    }

    private static func detail(for item: ClipItem) -> String {
        item.kind == .image ? "Image" : String(item.preview.prefix(36))
    }

    func snap(_ action: WindowAction) {
        let target = previousApp
        closePopover() // popoverDidClose clears windows.targetApp, so pass the target explicitly below
        target?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.windows.targetApp = target
            self.windows.perform(action)
            self.windows.targetApp = nil
        }
    }

    // MARK: Hotkeys

    private func registerHotkeys() {
        for b in Bindings.snaps {
            HotkeyCenter.shared.register(keyCode: b.keyCode, modifiers: b.modifiers) { [weak self] in
                self?.windows.targetApp = nil // use whatever is frontmost right now
                self?.windows.perform(b.action)
            }
        }
        HotkeyCenter.shared.register(keyCode: Bindings.clipboardKeyCode,
                                     modifiers: Bindings.clipboardModifiers) {
            (NSApp.delegate as? AppDelegate)?.togglePopover(tab: .clipboard)
        }
    }
}
