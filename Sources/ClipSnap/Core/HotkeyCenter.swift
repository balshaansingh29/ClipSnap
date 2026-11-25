import AppKit
import Carbon.HIToolbox

/// Global hotkeys via Carbon's RegisterEventHotKey: no Accessibility permission
/// needed, and it's what Rectangle/Maccy-style apps rely on under the hood.
final class HotkeyCenter: @unchecked Sendable {
    static let shared = HotkeyCenter()

    typealias Handler = @MainActor () -> Void

    private var handlers: [UInt32: Handler] = [:]
    private var refs: [EventHotKeyRef] = []
    private var nextID: UInt32 = 1
    private var installed = false

    private init() {}

    @discardableResult
    func register(keyCode: Int, modifiers: Int, handler: @escaping Handler) -> Bool {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C5350), id: id) // 'CLSP'
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            NSLog("ClipSnap: could not register hotkey (code \(keyCode), status \(status))")
            return false
        }
        refs.append(ref)
        handlers[id] = handler
        return true
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        handlers.removeAll()
    }

    fileprivate func fire(_ id: UInt32) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.handlers[id]?() }
        }
    }

    private func installHandlerIfNeeded() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hk = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hk)
            if status == noErr { HotkeyCenter.shared.fire(hk.id) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
