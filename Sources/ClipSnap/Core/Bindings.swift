import Carbon.HIToolbox

/// Default global shortcuts, modelled on Rectangle's defaults. Edit this table to
/// rebind; a recorder UI is the obvious next feature.
enum Bindings {
    static let ctrlOpt = controlKey | optionKey

    struct Snap {
        let action: WindowAction
        let keyCode: Int
        let modifiers: Int
        let label: String
    }

    static let snaps: [Snap] = [
        Snap(action: .leftHalf, keyCode: kVK_LeftArrow, modifiers: ctrlOpt, label: "⌃⌥←"),
        Snap(action: .rightHalf, keyCode: kVK_RightArrow, modifiers: ctrlOpt, label: "⌃⌥→"),
        Snap(action: .topHalf, keyCode: kVK_UpArrow, modifiers: ctrlOpt, label: "⌃⌥↑"),
        Snap(action: .bottomHalf, keyCode: kVK_DownArrow, modifiers: ctrlOpt, label: "⌃⌥↓"),
        Snap(action: .topLeft, keyCode: kVK_ANSI_U, modifiers: ctrlOpt, label: "⌃⌥U"),
        Snap(action: .topRight, keyCode: kVK_ANSI_I, modifiers: ctrlOpt, label: "⌃⌥I"),
        Snap(action: .bottomLeft, keyCode: kVK_ANSI_J, modifiers: ctrlOpt, label: "⌃⌥J"),
        Snap(action: .bottomRight, keyCode: kVK_ANSI_K, modifiers: ctrlOpt, label: "⌃⌥K"),
        Snap(action: .firstThird, keyCode: kVK_ANSI_D, modifiers: ctrlOpt, label: "⌃⌥D"),
        Snap(action: .centerThird, keyCode: kVK_ANSI_F, modifiers: ctrlOpt, label: "⌃⌥F"),
        Snap(action: .lastThird, keyCode: kVK_ANSI_G, modifiers: ctrlOpt, label: "⌃⌥G"),
        Snap(action: .firstTwoThirds, keyCode: kVK_ANSI_E, modifiers: ctrlOpt, label: "⌃⌥E"),
        Snap(action: .lastTwoThirds, keyCode: kVK_ANSI_T, modifiers: ctrlOpt, label: "⌃⌥T"),
        Snap(action: .maximize, keyCode: kVK_Return, modifiers: ctrlOpt, label: "⌃⌥↩"),
        Snap(action: .almostMaximize, keyCode: kVK_ANSI_A, modifiers: ctrlOpt, label: "⌃⌥A"),
        Snap(action: .center, keyCode: kVK_ANSI_C, modifiers: ctrlOpt, label: "⌃⌥C"),
        Snap(action: .restore, keyCode: kVK_Delete, modifiers: ctrlOpt, label: "⌃⌥⌫"),
        Snap(action: .previousDisplay, keyCode: kVK_LeftArrow, modifiers: ctrlOpt | cmdKey, label: "⌃⌥⌘←"),
        Snap(action: .nextDisplay, keyCode: kVK_RightArrow, modifiers: ctrlOpt | cmdKey, label: "⌃⌥⌘→"),
    ]

    /// Opens the clipboard popover.
    static let clipboardKeyCode = kVK_ANSI_V
    static let clipboardModifiers = controlKey | shiftKey
    static let clipboardLabel = "⌃⇧V"

    static func label(for action: WindowAction) -> String? {
        snaps.first { $0.action == action }?.label
    }
}
