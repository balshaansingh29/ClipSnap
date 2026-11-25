import SwiftUI

struct SnapView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: AppSettings

    @State private var hovered: WindowAction?

    private let sections: [(String, [WindowAction])] = [
        ("Halves", [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
        ("Quarters", [.topLeft, .topRight, .bottomLeft, .bottomRight]),
        ("Thirds", [.firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds]),
        ("More", [.maximize, .almostMaximize, .center, .restore, .previousDisplay, .nextDisplay]),
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            PersonalHeader(mood: hovered == nil ? .idle : .happy, title: "Windows",
                           quip: hovered.map { "\($0.title)?  Easy." } ?? "Pick a layout, I'll do the rest")

            ScrollView {
                VStack(spacing: 4) {
                    if !Permissions.accessibilityGranted { permissionBanner }

                    preview.padding(.bottom, 4)

                    ForEach(sections, id: \.0) { title, actions in
                        SectionLabel(title)
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(actions) { action in
                                SnapTile(action: action) { model.snap(action) }
                                    .onHover { inside in
                                        withAnimation(.easeOut(duration: 0.14)) {
                                            hovered = inside ? action : (hovered == action ? nil : hovered)
                                        }
                                    }
                            }
                        }
                    }

                    tip.padding(.top, 10)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: Live preview

    /// A miniature display that highlights the region of whichever tile is hovered.
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color.accentColor.opacity(0.10), Color.primary.opacity(0.04)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            GeometryReader { geo in
                let inset: CGFloat = 10
                let w = geo.size.width - inset * 2
                let h = geo.size.height - inset * 2
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                    if let unit = hovered?.unitRect() ?? (hovered == nil ? nil : CGRect(x: 0.3, y: 0.25, width: 0.4, height: 0.5)) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.accentColor.opacity(0.85))
                            .frame(width: max(unit.width * w - 4, 4), height: max(unit.height * h - 4, 4))
                            .offset(x: unit.minX * w + 2, y: unit.minY * h + 2)
                            .shadow(color: Color.accentColor.opacity(0.35), radius: 6, y: 2)
                            .transition(.opacity)
                    }
                }
                .frame(width: w, height: h)
                .offset(x: inset, y: inset)
            }
            if hovered == nil {
                Text("Hover a layout to preview")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
        .frame(height: 96)
    }

    private var tip: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 11)).foregroundStyle(.yellow)
            Text("Drag a window and shake your mouse to pop up layouts at your cursor, or drag to a screen edge. Press a shortcut twice to cycle ½ → ⅔ → ⅓.")
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            AppIconBadge(symbol: "exclamationmark.triangle.fill", tint: .orange, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility access needed")
                    .font(.system(size: 13, weight: .semibold))
                Text("Required to move windows and paste for you.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Allow") { Permissions.openAccessibilitySettings() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .fill(Color.orange.opacity(0.13)))
        .padding(.bottom, 6)
    }
}

// MARK: - Tile

struct SnapTile: View {
    let action: WindowAction
    let perform: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: perform) {
            VStack(spacing: 6) {
                SnapGlyph(action: action, highlighted: hovering)
                    .frame(width: 46, height: 30)
                Text(action.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let hint = Bindings.label(for: action) {
                    Text(hint)
                        .font(.system(size: 9.5, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                    .fill(hovering ? Color.accentColor.opacity(0.14) : Theme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                    .strokeBorder(hovering ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// A miniature screen with the target region filled in.
struct SnapGlyph: View {
    let action: WindowAction
    var highlighted = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(highlighted ? 0.9 : 0.6), lineWidth: 1)
                if let unit = action.unitRect() {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Color.accentColor.opacity(highlighted ? 1 : 0.8))
                        .frame(width: unit.width * geo.size.width - 4,
                               height: unit.height * geo.size.height - 4)
                        .offset(x: unit.minX * geo.size.width + 2,
                                y: unit.minY * geo.size.height + 2)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var symbol: String {
        switch action {
        case .center: "plus.viewfinder"
        case .restore: "arrow.uturn.backward"
        case .nextDisplay: "arrow.right.to.line"
        case .previousDisplay: "arrow.left.to.line"
        default: "rectangle"
        }
    }
}
