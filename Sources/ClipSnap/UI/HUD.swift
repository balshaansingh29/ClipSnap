import SwiftUI
import AppKit

@MainActor
final class HUDState: ObservableObject {
    @Published var shown = false
    @Published var text = ""
    @Published var detail: String?
    @Published var mood: Mood = .happy
}

/// Small floating confirmation ("Pasted", "Left Half") that works even after the
/// popover has closed, like the macOS volume HUD.
@MainActor
final class HUDController {
    private let state = HUDState()
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(_ text: String, detail: String? = nil, mood: Mood = .happy) {
        guard AppSettings.shared.showHUD else { return }
        let panel = panel ?? makePanel()
        self.panel = panel

        state.text = text
        state.detail = detail
        state.mood = mood
        position(panel)
        panel.orderFrontRegardless()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) { state.shown = true }

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled, let self else { return }
            withAnimation(.easeIn(duration: 0.22)) { self.state.shown = false }
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled { self.panel?.orderOut(nil) }
        }
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 96),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        p.contentView = NSHostingView(rootView: HUDView(state: state))
        return p
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: area.midX - 160, y: area.minY + 56))
    }
}

struct HUDView: View {
    @ObservedObject var state: HUDState

    var body: some View {
        HStack(spacing: 10) {
            Mascot(mood: state.mood, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(state.text)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                if let d = state.detail {
                    Text(d).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.leading, 14).padding(.trailing, 20)
        .frame(height: 52)
        .background(Capsule().fill(.regularMaterial))
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .scaleEffect(state.shown ? 1 : 0.7)
        .opacity(state.shown ? 1 : 0)
        .offset(y: state.shown ? 0 : 14)
        .frame(width: 320, height: 96)
    }
}
