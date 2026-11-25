import SwiftUI

/// First-run welcome tour, shown over the popover until finished or skipped.
struct OnboardingView: View {
    @EnvironmentObject var settings: AppSettings

    @State private var page = 0
    @State private var forward = true

    private struct Page {
        let mood: Mood
        let title: String
        let body: String
        let keys: [String]
    }

    private let pages: [Page] = [
        Page(mood: .happy, title: "Hi, I'm Snip!",
             body: "I live in your menu bar and keep two things tidy: everything you copy, and all your windows.",
             keys: []),
        Page(mood: .idle, title: "Your clipboard, remembered",
             body: "Copy like normal. Open me any time, type to search, and press return to paste.",
             keys: ["⌃⇧V"]),
        Page(mood: .surprised, title: "Windows that snap",
             body: "Drag a window and shake your mouse: layouts pop up right at your cursor. Drop on one to snap. Shortcuts work too.",
             keys: ["⌃⌥←", "⌃⌥→", "⌃⌥↩"]),
        Page(mood: .happy, title: "One last thing",
             body: "Allow Accessibility so I can move windows and paste for you. You can also do it later.",
             keys: []),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ZStack {
                    pageView(pages[page])
                        .id(page)
                        .transition(.asymmetric(
                            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
                }
                .frame(height: 300)
                .clipped()

                dots.padding(.top, 6)
                Spacer(minLength: 0)
                buttons.padding(.horizontal, 24).padding(.bottom, 22)
            }
        }
    }

    // MARK: Pieces

    private func pageView(_ p: Page) -> some View {
        VStack(spacing: 14) {
            Mascot(mood: p.mood, size: 84)
                .frame(height: 110)
            Text(p.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(p.body)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 36)
            if !p.keys.isEmpty {
                HStack(spacing: 6) { ForEach(p.keys, id: \.self) { KeyCap($0) } }
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.accentColor : Color.primary.opacity(0.18))
                    .frame(width: i == page ? 18 : 6, height: 6)
            }
        }
        .animation(Theme.spring, value: page)
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            Button {
                if isLast { finish() } else { go(page + 1) }
            } label: {
                Text(isLast ? "Let's go" : "Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
            .buttonStyle(PressableStyle())
            .keyboardShortcut(.defaultAction)

            if isLast {
                Button("Allow Accessibility…") { Permissions.promptForAccessibility() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(height: 22)
                    .transition(.opacity)
            } else {
                Button("Skip") { finish() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(height: 22)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLast)
    }

    // MARK: Actions

    private func go(_ new: Int) {
        forward = new > page
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { page = new }
    }

    private func finish() {
        withAnimation(.easeInOut(duration: 0.3)) { settings.hasOnboarded = true }
    }
}
