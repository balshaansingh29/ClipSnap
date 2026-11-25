import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: ClipStore
    @State private var newExcluded = ""

    var body: some View {
        VStack(spacing: 0) {
            PersonalHeader(mood: .idle, title: "Settings", quip: "Make me yours")

            ScrollView {
                VStack(spacing: 4) {
                    SectionLabel("Clipboard")
                    group {
                        ToggleRow(symbol: "arrow.down.doc.fill", tint: .blue,
                                  title: "Paste Automatically", isOn: $settings.pasteAutomatically)
                        ToggleRow(symbol: "photo.fill", tint: .pink,
                                  title: "Keep Images", isOn: $settings.captureImages)
                        StepperRow(symbol: "clock.fill", tint: .gray, title: "History Size",
                                   value: $settings.maxHistory, range: 50...1000, step: 50)
                        ValueRow(symbol: "command", tint: .indigo, title: "Open With",
                                 value: Bindings.clipboardLabel)
                    }

                    SectionLabel("Windows")
                    group {
                        ToggleRow(symbol: "cursorarrow.motionlines", tint: .green,
                                  title: "Snap by Dragging", isOn: $settings.dragSnapEnabled)
                        ToggleRow(symbol: "hand.point.up.left.fill", tint: .purple,
                                  title: "Shake to Show Layouts", isOn: $settings.shakeToSnap)
                        ToggleRow(symbol: "arrow.triangle.2.circlepath", tint: .teal,
                                  title: "Cycle on Repeat", isOn: $settings.cycleOnRepeat)
                        SliderRow(symbol: "square.split.2x2.fill", tint: .orange, title: "Window Gap",
                                  display: "\(Int(settings.windowGap)) pt",
                                  value: $settings.windowGap, range: 0...24, step: 2)
                        SliderRow(symbol: "arrow.up.left.and.arrow.down.right", tint: .purple,
                                  title: "Almost Maximize",
                                  display: "\(Int(settings.almostMaxFraction * 100))%",
                                  value: $settings.almostMaxFraction, range: 0.6...0.98, step: 0.01)
                    }

                    SectionLabel("Privacy")
                    group {
                        ForEach(settings.excludedApps, id: \.self) { id in
                            ExcludedRow(bundleID: id) {
                                withAnimation(Theme.spring) { settings.excludedApps.removeAll { $0 == id } }
                            }
                        }
                        addExcludedRow
                    }
                    Text("Copies from these apps, and anything a password manager marks as secret, are never recorded.")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6).padding(.top, 2)

                    SectionLabel("General")
                    group {
                        ToggleRow(symbol: "power", tint: .gray, title: "Launch at Login",
                                  isOn: Binding(get: { settings.launchAtLogin },
                                                set: { settings.launchAtLogin = $0 }))
                        ToggleRow(symbol: "sparkles", tint: .yellow,
                                  title: "Show Pop-up Feedback", isOn: $settings.showHUD)
                        accessibilityRow
                        Button {
                            withAnimation { settings.hasOnboarded = false }
                        } label: {
                            HStack(spacing: 10) {
                                AppIconBadge(symbol: "hand.wave.fill", tint: .blue)
                                Text("Replay Welcome Tour")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                            }
                            .font(.system(size: 13))
                            .rowPadding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button { NSApp.terminate(nil) } label: {
                            HStack {
                                AppIconBadge(symbol: "xmark", tint: .red)
                                Text("Quit ClipSnap").foregroundStyle(.red)
                                Spacer()
                            }
                            .rowPadding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("ClipSnap 0.1.0")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                        .padding(.top, 12).padding(.bottom, 6)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: Pieces

    /// iOS-style inset grouped list: rows in one rounded card separated by hairlines.
    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.top, -0.5)   // pushes the first row's top hairline out of frame
            .clipped()
            .cardSurface()
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var addExcludedRow: some View {
        HStack(spacing: 10) {
            AppIconBadge(symbol: "plus", tint: .green)
            TextField("Add bundle ID", text: $newExcluded)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit(addExcluded)
            if !newExcluded.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Add", action: addExcluded)
                    .buttonStyle(.borderless)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .rowPadding()
    }

    private func addExcluded() {
        let id = newExcluded.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !settings.excludedApps.contains(id) else { return }
        withAnimation(Theme.spring) { settings.excludedApps.append(id) }
        newExcluded = ""
    }

    @ViewBuilder
    private var accessibilityRow: some View {
        let granted = Permissions.accessibilityGranted
        Button {
            if !granted { Permissions.openAccessibilitySettings() }
        } label: {
            HStack(spacing: 10) {
                AppIconBadge(symbol: "hand.raised.fill", tint: granted ? .green : .orange)
                Text("Accessibility")
                Spacer()
                Text(granted ? "Allowed" : "Not Allowed")
                    .foregroundStyle(.secondary)
                if !granted {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                }
            }
            .font(.system(size: 13))
            .rowPadding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row building blocks

private extension View {
    func rowPadding() -> some View {
        padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 44)
            .rowHairline()
    }

    /// Hairline along the top edge, inset past the icon like iOS Settings.
    func rowHairline() -> some View {
        overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 0.5).padding(.leading, 48)
        }
    }
}

private struct ToggleRow: View {
    let symbol: String
    let tint: Color
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            AppIconBadge(symbol: symbol, tint: tint)
            Text(title).font(.system(size: 13))
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
        .rowPadding()
    }
}

private struct ValueRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            AppIconBadge(symbol: symbol, tint: tint)
            Text(title).font(.system(size: 13))
            Spacer()
            KeyCap(value)
        }
        .rowPadding()
    }
}

private struct StepperRow: View {
    let symbol: String
    let tint: Color
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: 10) {
            AppIconBadge(symbol: symbol, tint: tint)
            Text(title).font(.system(size: 13))
            Spacer()
            Text("\(value)").font(.system(size: 13)).foregroundStyle(.secondary).monospacedDigit()
            Stepper("", value: $value, in: range, step: step).labelsHidden()
        }
        .rowPadding()
    }
}

private struct SliderRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let display: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                AppIconBadge(symbol: symbol, tint: tint)
                Text(title).font(.system(size: 13))
                Spacer()
                Text(display).font(.system(size: 13)).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: $value, in: range, step: step).controlSize(.small).padding(.leading, 36)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .rowHairline()
    }
}

private struct ExcludedRow: View {
    let bundleID: String
    let remove: () -> Void

    private var appURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }

    private var name: String {
        if let url = appURL { return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "") }
        return bundleID.split(separator: ".").last.map(String.init)?.capitalized ?? bundleID
    }

    var body: some View {
        HStack(spacing: 10) {
            if let url = appURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable().frame(width: 26, height: 26)
            } else {
                AppIconBadge(symbol: "app.dashed", tint: .gray)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(.system(size: 13))
                Text(bundleID).font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer()
            Button(action: remove) {
                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .rowPadding()
    }
}
