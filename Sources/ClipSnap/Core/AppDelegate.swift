import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let model = AppModel()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "ClipSnap")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 380, height: 560)
        popover.delegate = self
        let root = RootView()
            .environmentObject(model)
            .environmentObject(model.store)
            .environmentObject(model.monitor)
            .environmentObject(model.settings)
        popover.contentViewController = NSHostingController(rootView: root)

        model.closePopover = { [weak self] in self?.popover.performClose(nil) }
        model.start()
    }

    // MARK: Status item

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.option) == true {
            showMenu()
        } else {
            togglePopover()
        }
    }

    /// Toggles the popover. With `tab`, opening lands on that tab, and pressing the
    /// shortcut while another tab is showing switches to it instead of closing.
    func togglePopover(tab: PopoverTab? = nil) {
        if popover.isShown {
            if let tab, model.currentTab != tab {
                model.currentTab = tab
                model.openTick += 1   // replays focus and reset on the clipboard page
            } else {
                popover.performClose(nil)
            }
            return
        }
        if let tab { model.currentTab = tab }
        guard let button = statusItem.button else { return }

        // Remember who was frontmost so pastes and snaps go to the right app.
        let front = NSWorkspace.shared.frontmostApplication
        let me = NSRunningApplication.current
        let target = (front?.processIdentifier == me.processIdentifier) ? nil : front
        model.previousApp = target
        model.windows.targetApp = target

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showMenu() {
        let menu = NSMenu()
        let pause = NSMenuItem(title: model.monitor.paused ? "Resume Clipboard Capture" : "Pause Clipboard Capture",
                               action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit ClipSnap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        // Attach only for this click so left-click keeps toggling the popover.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func togglePause() {
        model.monitor.paused.toggle()
    }

    // MARK: NSPopoverDelegate

    func popoverWillShow(_ notification: Notification) {
        model.openTick += 1
    }

    func popoverDidClose(_ notification: Notification) {
        // Hotkeys should act on whatever is frontmost, not a stale target.
        model.windows.targetApp = nil
    }
}
