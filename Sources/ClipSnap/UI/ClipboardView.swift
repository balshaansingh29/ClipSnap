import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: ClipStore
    @EnvironmentObject var monitor: ClipboardMonitor

    @State private var query = ""
    @State private var selection = 0
    @State private var flash = false
    @FocusState private var searchFocused: Bool

    private var mood: Mood {
        if monitor.paused { return .sleepy }
        if flash { return .happy }
        if results.isEmpty && !query.isEmpty { return .surprised }
        return .idle
    }

    private var results: [ClipItem] { store.filtered(query) }
    private var hasPinned: Bool { results.contains(where: \.pinned) }

    var body: some View {
        VStack(spacing: 0) {
            PersonalHeader(mood: mood, title: Voice.greeting,
                           quip: Voice.clipboardQuip(count: store.items.count, paused: monitor.paused)) {
                CircleIconButton(symbol: monitor.paused ? "play.fill" : "pause.fill",
                                 tint: monitor.paused ? .orange : .accentColor) {
                    withAnimation(Theme.spring) { monitor.paused.toggle() }
                }
                .help(monitor.paused ? "Resume capture" : "Pause capture")
                CircleIconButton(symbol: "trash", tint: .red) {
                    withAnimation(Theme.spring) { store.clearUnpinned() }
                }
                .help("Clear unpinned clips")
            }

            searchPill
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

            if results.isEmpty { emptyState } else { list }

            hintBar
        }
        .background(shortcuts)
        .onAppear { searchFocused = true }
        .onChange(of: query) { _, _ in selection = 0 }
        .onChange(of: model.openTick) { _, _ in
            // Fresh start each time the popover opens: clear search, focus the field.
            query = ""
            selection = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { searchFocused = true }
        }
        .onChange(of: store.items.first?.id) { _, _ in celebrate() }
    }

    /// Snip perks up for a moment whenever something new is copied.
    private func celebrate() {
        withAnimation { flash = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation { flash = false }
        }
    }

    // MARK: Search

    private var searchPill: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($searchFocused)
                .onSubmit { pasteSelected() }
                .onKeyPress(.downArrow) { move(1); return .handled }
                .onKeyPress(.upArrow) { move(-1); return .handled }
                .onKeyPress(.escape) {
                    if query.isEmpty { model.closePopover() } else { query = "" }
                    return .handled
                }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.07)))
        .animation(Theme.spring, value: query.isEmpty)
    }

    // MARK: List

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: 0) {
                            if let header = header(at: index) { SectionLabel(header) }
                            ClipRow(item: item, index: index, selected: index == selection)
                        }
                        .id(item.id)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)),
                                                removal: .opacity))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .animation(Theme.spring, value: results.map(\.id))
            }
            .onChange(of: selection) { _, new in
                if results.indices.contains(new) {
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(results[new].id) }
                }
            }
        }
    }

    private func header(at index: Int) -> String? {
        guard hasPinned else { return nil }
        let item = results[index]
        if index == 0 { return item.pinned ? "Pinned" : "Recent" }
        if !item.pinned && results[index - 1].pinned { return "Recent" }
        return nil
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Mascot(mood: query.isEmpty ? .happy : .surprised, size: 76)
                .frame(height: 96)
            Text(query.isEmpty ? "Nothing here yet" : "Hmm, nothing for “\(query)”")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(query.isEmpty ? "Copy something and watch me light up."
                               : "Try a different word, or clear the search.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    // MARK: Hints

    private var hintBar: some View {
        HStack(spacing: 12) {
            hint("↩", "Paste")
            hint("⌥↩", "Plain")
            hint("⌘⌫", "Delete")
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            KeyCap(key)
            Text(label).font(.system(size: 10.5)).foregroundStyle(.tertiary)
        }
    }

    /// Invisible buttons that carry ⌘1…⌘9 quick-paste and ⌘⌫ delete.
    private var shortcuts: some View {
        ZStack {
            ForEach(0..<9, id: \.self) { i in
                Button("") {
                    if results.indices.contains(i) { model.paste(results[i], plain: false) }
                }
                .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
            }
            Button("") {
                if results.indices.contains(selection) {
                    withAnimation(Theme.spring) { store.delete(results[selection]) }
                }
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
    }

    // MARK: Actions

    private func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = min(max(selection + delta, 0), results.count - 1)
    }

    private func pasteSelected() {
        guard results.indices.contains(selection) else { return }
        let plain = NSEvent.modifierFlags.contains(.option)
        model.paste(results[selection], plain: plain)
    }
}

// MARK: - Row

struct ClipRow: View {
    @EnvironmentObject var model: AppModel
    let item: ClipItem
    let index: Int
    let selected: Bool

    @State private var hovering = false
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                sourceIcon.frame(width: 30, height: 30)
                content
                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                model.paste(item, plain: NSEvent.modifierFlags.contains(.option))
            }

            trailing
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.20)
                      : hovering ? Color.primary.opacity(0.08) : Theme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(selected ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .animation(.easeOut(duration: 0.12), value: selected)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84).delay(Double(min(index, 8)) * 0.035)) {
                appeared = true
            }
        }
        .contextMenu { menu }
    }

    // MARK: Pieces

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 3) {
            if item.kind == .image, let name = item.imageFile,
               let image = ThumbnailCache.image(at: model.store.blobURL(name)) {
                Image(nsImage: image)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 54, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Text(item.preview)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Text(subtitle)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if hovering {
            HStack(spacing: 6) {
                miniButton(item.pinned ? "pin.slash.fill" : "pin.fill", .orange) {
                    withAnimation(Theme.spring) { model.store.togglePin(item) }
                }
                miniButton("trash.fill", .red) {
                    withAnimation(Theme.spring) { model.store.delete(item) }
                }
            }
            .transition(.opacity)
        } else if item.pinned {
            Image(systemName: "pin.fill")
                .font(.system(size: 10)).foregroundStyle(.orange)
        } else if index < 9 {
            KeyCap("⌘\(index + 1)")
        }
    }

    private func miniButton(_ symbol: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.opacity(0.15)))
        }
        .buttonStyle(PressableStyle(scale: 0.86))
    }

    @ViewBuilder
    private var menu: some View {
        Button("Paste") { model.paste(item, plain: false) }
        if item.kind == .text { Button("Paste as Plain Text") { model.paste(item, plain: true) } }
        Button("Copy Only") { model.copyOnly(item, plain: false) }
        Divider()
        Button(item.pinned ? "Unpin" : "Pin") { model.store.togglePin(item) }
        Button("Delete", role: .destructive) { model.store.delete(item) }
    }

    private var subtitle: String {
        let rel = item.date.formatted(.relative(presentation: .named))
        if let n = item.sourceName { return "\(n) · \(rel)" }
        return rel
    }

    @ViewBuilder
    private var sourceIcon: some View {
        if let id = item.sourceBundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            AppIconBadge(symbol: item.kind == .image ? "photo.fill" : "text.alignleft",
                         tint: item.kind == .image ? .pink : .gray, size: 30)
        }
    }
}
