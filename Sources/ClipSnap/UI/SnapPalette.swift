import SwiftUI
import AppKit

/// Geometry shared by the palette view and its hit-testing, so what you see is
/// exactly what you can drop onto. All rects use a top-left origin inside the card.
enum PaletteLayout {
    static let actions: [[WindowAction]] = [
        [.leftHalf, .rightHalf, .topHalf, .bottomHalf],
        [.topLeft, .topRight, .bottomLeft, .bottomRight],
        [.firstThird, .centerThird, .lastThird, .maximize],
    ]
    static let columns = 4
    static let tile = CGSize(width: 58, height: 44)
    static let gap: CGFloat = 6
    static let pad: CGFloat = 12
    static let captionHeight: CGFloat = 26
    static let margin: CGFloat = 26   // room around the card for its shadow

    static var cardSize: CGSize {
        CGSize(width: CGFloat(columns) * tile.width + CGFloat(columns - 1) * gap + pad * 2,
               height: CGFloat(actions.count) * tile.height + CGFloat(actions.count - 1) * gap
                       + pad * 2 + captionHeight)
    }

    static var panelSize: CGSize {
        CGSize(width: cardSize.width + margin * 2, height: cardSize.height + margin * 2)
    }

    static func rect(row: Int, col: Int) -> CGRect {
        CGRect(x: pad + CGFloat(col) * (tile.width + gap),
               y: pad + CGFloat(row) * (tile.height + gap),
               width: tile.width, height: tile.height)
    }
}

@MainActor
final class PaletteState: ObservableObject {
    @Published var shown = false
    @Published var hovered: WindowAction?
}

/// Floating layout picker that appears at the cursor when you shake a dragged
/// window. It ignores the mouse itself; DragSnapper hit-tests it by position.
@MainActor
final class SnapPalette {
    let state = PaletteState()
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    var isVisible: Bool { state.shown }
    var hovered: WindowAction? { state.hovered }

    func show(at p: CGPoint) {
        hideTask?.cancel()
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let size = PaletteLayout.panelSize
        let m = PaletteLayout.margin
        var origin = CGPoint(x: p.x - size.width / 2, y: p.y - size.height / 2)
        if let area = (NSScreen.screens.first { $0.frame.contains(p) } ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, area.minX - m), area.maxX - size.width + m)
            origin.y = min(max(origin.y, area.minY - m), area.maxY - size.height + m)
        }

        state.hovered = nil
        state.shown = false
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        // Flip on the next turn so SwiftUI animates from the hidden state.
        DispatchQueue.main.async { [weak self] in self?.state.shown = true }
    }

    func hide() {
        guard state.shown else { return }
        state.shown = false
        state.hovered = nil
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            if !Task.isCancelled { self?.panel?.orderOut(nil) }
        }
    }

    /// Updates which tile is under the pointer (AppKit screen coordinates).
    func updateHover(at p: CGPoint) {
        guard let panel, state.shown else { return }
        let m = PaletteLayout.margin
        let local = CGPoint(x: p.x - panel.frame.minX - m,
                            y: (panel.frame.maxY - p.y) - m)
        var found: WindowAction?
        outer: for (r, row) in PaletteLayout.actions.enumerated() {
            for (c, action) in row.enumerated()
            where PaletteLayout.rect(row: r, col: c).insetBy(dx: -3, dy: -3).contains(local) {
                found = action
                break outer
            }
        }
        if state.hovered != found { state.hovered = found }
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: PaletteLayout.panelSize),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        p.contentView = NSHostingView(rootView: PaletteView(state: state))
        return p
    }
}

struct PaletteView: View {
    @ObservedObject var state: PaletteState

    var body: some View {
        let card = PaletteLayout.cardSize
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.28), radius: 20, y: 8)
                .frame(width: card.width, height: card.height)

            ForEach(Array(PaletteLayout.actions.enumerated()), id: \.offset) { r, row in
                ForEach(Array(row.enumerated()), id: \.offset) { c, action in
                    let rect = PaletteLayout.rect(row: r, col: c)
                    tile(action, index: r * PaletteLayout.columns + c)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }

            caption
                .frame(width: card.width, height: PaletteLayout.captionHeight)
                .offset(y: card.height - PaletteLayout.pad - PaletteLayout.captionHeight + 4)
        }
        .frame(width: card.width, height: card.height, alignment: .topLeading)
        .scaleEffect(state.shown ? 1 : 0.55)
        .opacity(state.shown ? 1 : 0)
        .animation(.spring(response: 0.38, dampingFraction: 0.66), value: state.shown)
        .frame(width: PaletteLayout.panelSize.width, height: PaletteLayout.panelSize.height)
    }

    private func tile(_ action: WindowAction, index: Int) -> some View {
        let hot = state.hovered == action
        return SnapGlyph(action: action, highlighted: hot)
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hot ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(hot ? Color.accentColor : .clear, lineWidth: 1.5)
            )
            .scaleEffect(hot ? 1.1 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: hot)
            .scaleEffect(state.shown ? 1 : 0.3)
            .opacity(state.shown ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.62).delay(Double(index) * 0.02),
                       value: state.shown)
    }

    private var caption: some View {
        HStack(spacing: 6) {
            Mascot(mood: state.hovered == nil ? .surprised : .happy, size: 14)
            Text(state.hovered.map { "Drop for \($0.title)" } ?? "Drop on a layout")
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .id(state.hovered?.rawValue ?? "none")
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.15), value: state.hovered)
    }
}
