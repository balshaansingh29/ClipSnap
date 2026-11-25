import AppKit
import ApplicationServices

/// Puts a clip back on the pasteboard and (optionally) pastes it into the app
/// that was frontmost before the popover opened.
@MainActor
struct Paster {
    let store: ClipStore
    let monitor: ClipboardMonitor

    func copy(_ item: ClipItem, plain: Bool) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text:
            pb.setString(item.text ?? "", forType: .string)
            if !plain, let name = item.rtfFile,
               let rtf = try? Data(contentsOf: store.blobURL(name)) {
                pb.setData(rtf, forType: .rtf)
            }
        case .image:
            if let name = item.imageFile,
               let png = try? Data(contentsOf: store.blobURL(name)) {
                pb.setData(png, forType: .png)
            }
        }
        monitor.suppressCurrentChange()
    }

    /// Copy, then paste into `target` with a synthesized ⌘V.
    func paste(_ item: ClipItem, plain: Bool, into target: NSRunningApplication?) {
        copy(item, plain: plain)
        guard AppSettings.shared.pasteAutomatically else { return }
        guard AXIsProcessTrusted() else {
            Permissions.promptForAccessibility()
            return
        }
        target?.activate()
        // Give the target app a moment to become frontmost before the keystroke.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            Self.sendCommandV()
        }
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
}

enum Permissions {
    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    static func promptForAccessibility() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
