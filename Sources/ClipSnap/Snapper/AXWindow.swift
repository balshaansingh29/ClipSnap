import AppKit
import ApplicationServices

/// Thin wrapper over an AXUIElement window.
struct AXWindow {
    let element: AXUIElement
    let pid: pid_t

    var identity: CFHashCode { CFHash(element) }

    // MARK: Lookup

    static func focused(of app: NSRunningApplication) -> AXWindow? {
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        for attr in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            var ref: CFTypeRef?
            if AXUIElementCopyAttributeValue(appEl, attr as CFString, &ref) == .success,
               let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() {
                return AXWindow(element: ref as! AXUIElement, pid: app.processIdentifier)
            }
        }
        return nil
    }

    /// The window under a point given in AX coordinates (used by drag-to-snap).
    static func at(axPoint p: CGPoint) -> AXWindow? {
        let system = AXUIElementCreateSystemWide()
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(p.x), Float(p.y), &hit) == .success,
              let hit else { return nil }

        var pid: pid_t = 0
        AXUIElementGetPid(hit, &pid)

        if string(hit, kAXRoleAttribute) == kAXWindowRole as String {
            return AXWindow(element: hit, pid: pid)
        }
        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(hit, kAXWindowAttribute as CFString, &ref) == .success,
           let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() {
            return AXWindow(element: ref as! AXUIElement, pid: pid)
        }
        return nil
    }

    // MARK: Geometry

    var frame: CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return nil }
        var p = CGPoint.zero
        var s = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &p)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &s)
        return CGRect(origin: p, size: s)
    }

    var isResizable: Bool {
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &settable)
        return settable.boolValue
    }

    var isStandardWindow: Bool {
        let sub = AXWindow.string(element, kAXSubroleAttribute)
        return sub == nil || sub == (kAXStandardWindowSubrole as String)
            || sub == (kAXDialogSubrole as String)
    }

    /// Moves and resizes. Size is set before and after the move because some apps
    /// clamp size against the screen the window is currently on.
    func setFrame(_ rect: CGRect) {
        let appEl = AXUIElementCreateApplication(pid)
        let enhanced = AXWindow.bool(appEl, "AXEnhancedUserInterface")
        if enhanced { AXUIElementSetAttributeValue(appEl, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse) }
        defer {
            if enhanced { AXUIElementSetAttributeValue(appEl, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) }
        }

        var size = rect.size
        var origin = rect.origin
        let resizable = isResizable
        if resizable, let v = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, v)
        }
        if let v = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, v)
        }
        if resizable, let v = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, v)
        }
    }

    // MARK: Attribute helpers

    private static func string(_ el: AXUIElement, _ attr: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &ref) == .success else { return nil }
        return ref as? String
    }

    private static func bool(_ el: AXUIElement, _ attr: String) -> Bool {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &ref) == .success,
              let ref else { return false }
        return (ref as? Bool) ?? false
    }
}
