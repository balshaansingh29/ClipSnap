# ClipSnap

One menu bar icon, two tools: a searchable **clipboard history** and a **window snapper**.
Native Swift/SwiftUI, macOS 14+, no third-party dependencies, no network access.

## Build and run

```bash
./build.sh          # needs Xcode command line tools
open build/ClipSnap.app
```

On first launch, grant **Accessibility** access (System Settings → Privacy & Security → Accessibility).
It is needed to move other apps' windows and to send ⌘V when pasting.
Global hotkeys and clipboard capture work without it.

Ad-hoc signing (the default) makes macOS forget the Accessibility grant after each rebuild.
To keep it, sign with a stable local certificate: `SIGN_ID="My Local Cert" ./build.sh`.

## Using it

- Click the icon (or press **⌃⇧V**) for the popover. Right-click or ⌥-click the icon for pause and quit.
- **Clipboard:** type to filter, ↑/↓ to move, ↩ to paste, ⌥↩ or ⌥-click for plain text,
  ⌘1–9 for quick paste, ⌘⌫ to delete, right-click to pin.
- **Windows:** click a layout, use a global shortcut (⌃⌥ + arrows, U/I/J/K, D/F/G, ↩, C, ⌫),
  or drag a window to an edge or corner. Repeat a half or third shortcut to cycle ½ → ⅔ → ⅓.

## What was borrowed, and from where

| Idea | Source |
|---|---|
| Poll `NSPasteboard.changeCount` about every 0.4 s; skip transient and concealed types | Maccy (open source) |
| Per-app exclusion list (password managers) | Maccy |
| Paste via synthesized ⌘V, plain-text paste with ⌥ | Maccy |
| Halves → thirds cycling on repeated shortcuts, restore, next display, almost-maximize | Rectangle (open source) |
| Drag-to-edge snap with a footprint preview | Rectangle / Magnet |
| Pinned clips, source-app icon and name, image clips, ⌘1–9 | Paste / PastePal (paid) |
| Mini screen glyphs on each layout button | Magnet (paid) |
| Unified popover with iOS-style tab bar, large titles, inset grouped settings | Raycast (paid) and iOS Settings |

No code was copied from any of these apps; the behaviors were reimplemented from their public documentation.

## Layout

```
Sources/ClipSnap/
  Clipboard/  ClipItem, ClipStore (JSON + blob files), ClipboardMonitor, Paster
  Snapper/    WindowAction (geometry), AXWindow (Accessibility wrapper), WindowManager,
              DragSnapper (edge zones + overlay), ScreenGeometry (coordinate flipping)
  Core/       AppDelegate (status item + popover), AppModel, HotkeyCenter (Carbon), Bindings, Settings
  UI/         Theme (design tokens, shared components), RootView (tab bar), ClipboardView, SnapView, SettingsView
```

## Personality and polish

- **Snip**, the mascot, is drawn in code (`UI/Mascot.swift`). It blinks, bobs, falls asleep when capture is paused,
  perks up when you copy something, and looks surprised when a search finds nothing.
- **Pop-up feedback** (`UI/HUD.swift`): a small floating "Pasted" / "Left Half" confirmation that appears even after the
  popover closes. Turn it off in Settings.
- **Welcome tour** on first launch (replay it from Settings), with the Accessibility prompt on the last step.
- **Animations:** sliding tab highlight, directional tab transitions, staggered list entrance, springy presses,
  hover previews on the Windows tab.
- **Shake to snap:** while dragging a window, shake the mouse and a layout palette pops up at the cursor. Hover a tile to preview the region, release to snap. Dragging to a screen edge still works. Toggle in Settings.
- **Popover entrance:** content eases down and fades in each time it opens.
- **Paste shortcut:** ⌃⇧V always opens the Clipboard tab with a clean, focused search field; pressing it again closes the popover (or jumps back to Clipboard from another tab).
- **Shortcuts:** ⌘⌥1/2/3 switch tabs while the popover is open.

## Known limits and next steps

- **Not yet compiled.** This was written without a Swift toolchain, so expect a few compile fixes on first build.
- Shortcuts are a table in `Core/Bindings.swift`; there is no in-app shortcut recorder yet.
- Only text, RTF and images are captured (no files or multi-item pastes).
- History is stored unencrypted in `~/Library/Application Support/ClipSnap`.
- Not sandboxed. The Accessibility API does not work inside the App Sandbox, so Mac App Store distribution is not possible.
