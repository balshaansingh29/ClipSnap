import SwiftUI

enum PopoverTab: String, CaseIterable, Identifiable {
    case clipboard = "Clipboard"
    case windows = "Windows"
    case settings = "Settings"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .clipboard: "doc.on.clipboard"
        case .windows: "rectangle.split.2x2"
        case .settings: "gearshape"
        }
    }

    var filledSymbol: String {
        switch self {
        case .clipboard: "doc.on.clipboard.fill"
        case .windows: "rectangle.split.2x2.fill"
        case .settings: "gearshape.fill"
        }
    }

    var index: Int { PopoverTab.allCases.firstIndex(of: self) ?? 0 }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: AppSettings
    private var tab: PopoverTab {
        get { model.currentTab }
        nonmutating set { model.currentTab = newValue }
    }
    @State private var previous: PopoverTab = .clipboard
    @State private var entered = false

    private var forward: Bool { tab.index >= previous.index }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack {
                    switch tab {
                    case .clipboard: ClipboardView().transition(slide)
                    case .windows: SnapView().transition(slide)
                    case .settings: SettingsView().transition(slide)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                TabBar(selection: Binding(get: { tab }, set: { tab = $0 }), previous: $previous)
            }

            // Hidden shortcuts: ⌘⌥1/2/3 jump between tabs.
            ZStack {
                ForEach(PopoverTab.allCases) { t in
                    Button("") { select(t) }
                        .keyboardShortcut(KeyEquivalent(Character("\(t.index + 1)")), modifiers: [.command, .option])
                }
            }
            .opacity(0).allowsHitTesting(false)

            if !settings.hasOnboarded {
                OnboardingView()
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
                    .zIndex(1)
            }
        }
        .frame(width: 380, height: 560)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: tab)
        // Entrance: content eases down and fades in each time the popover opens.
        .scaleEffect(entered ? 1 : 0.94, anchor: .top)
        .opacity(entered ? 1 : 0)
        .offset(y: entered ? 0 : -10)
        .onAppear { enter() }
        .onChange(of: model.currentTab) { old, _ in previous = old }
        .onChange(of: model.openTick) { _, _ in
            entered = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { enter() }
        }
    }

    private func enter() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { entered = true }
    }

    private var slide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    private func select(_ t: PopoverTab) {
        guard t != tab else { return }
        previous = tab
        tab = t
    }
}

/// Bottom tab bar with a sliding highlight and bouncing icons.
struct TabBar: View {
    @Binding var selection: PopoverTab
    @Binding var previous: PopoverTab
    @Namespace private var ns

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.6)
            HStack(spacing: 4) {
                ForEach(PopoverTab.allCases) { t in
                    let active = selection == t
                    Button {
                        guard t != selection else { return }
                        previous = selection
                        selection = t
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: active ? t.filledSymbol : t.symbol)
                                .font(.system(size: 17, weight: .medium))
                                .symbolEffect(.bounce, value: active)
                            Text(t.rawValue)
                                .font(.system(size: 10, weight: active ? .semibold : .medium))
                        }
                        .foregroundStyle(active ? Color.accentColor : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.13))
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle(scale: 0.92))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }
}
