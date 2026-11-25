import SwiftUI

enum Mood { case idle, happy, sleepy, surprised }

/// Snip: ClipSnap's little clipboard mascot. Drawn entirely with shapes, so it is
/// resolution independent, themeable via the accent color, and fully original.
struct Mascot: View {
    var mood: Mood = .idle
    var size: CGFloat = 40

    @State private var blink = false
    @State private var bob = false

    var body: some View {
        let u = size / 40
        ZStack {
            Capsule()
                .fill(Color.primary.opacity(0.35))
                .frame(width: 16 * u, height: 7 * u)
                .offset(y: -19 * u)
            RoundedRectangle(cornerRadius: 12 * u, style: .continuous)
                .fill(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.68)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 34 * u, height: 38 * u)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 6 * u, y: 3 * u)
            face(u).offset(y: 2 * u)
            Text("z")
                .font(.system(size: 11 * u, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .offset(x: 22 * u, y: bob ? -20 * u : -14 * u)
                .opacity(mood == .sleepy ? 1 : 0)
        }
        .frame(width: size * 1.2, height: size * 1.15)
        .offset(y: bob ? -1.5 * u : 1.5 * u)
        .animation(.easeInOut(duration: mood == .sleepy ? 2.4 : 1.6).repeatForever(autoreverses: true), value: bob)
        .scaleEffect(mood == .happy ? 1.12 : 1)
        .rotationEffect(.degrees(mood == .happy ? -7 : mood == .surprised ? 4 : 0))
        .animation(.spring(response: 0.35, dampingFraction: 0.45), value: mood)
        .task {
            bob = true
            await blinkLoop()
        }
    }

    // MARK: Face

    private func face(_ u: CGFloat) -> some View {
        VStack(spacing: 5 * u) {
            HStack(spacing: 9 * u) {
                eye(u)
                eye(u)
            }
            mouth(u)
        }
    }

    @ViewBuilder
    private func eye(_ u: CGFloat) -> some View {
        if mood == .happy {
            Smile(depth: -1)
                .stroke(.white, style: StrokeStyle(lineWidth: 1.8 * u, lineCap: .round))
                .frame(width: 7 * u, height: 4 * u)
        } else if mood == .sleepy || blink {
            Capsule().fill(.white).frame(width: 7 * u, height: 1.6 * u)
        } else {
            ZStack {
                Circle().fill(.white)
                Circle().fill(Color.black.opacity(0.8)).frame(width: 3.4 * u, height: 3.4 * u)
            }
            .frame(width: mood == .surprised ? 8.5 * u : 7 * u, height: mood == .surprised ? 8.5 * u : 7 * u)
        }
    }

    @ViewBuilder
    private func mouth(_ u: CGFloat) -> some View {
        switch mood {
        case .idle:
            Smile(depth: 1).stroke(.white, style: StrokeStyle(lineWidth: 1.7 * u, lineCap: .round))
                .frame(width: 8 * u, height: 3 * u)
        case .happy:
            Smile(depth: 1).fill(.white).frame(width: 11 * u, height: 6 * u)
        case .sleepy:
            Capsule().fill(.white.opacity(0.9)).frame(width: 5 * u, height: 1.7 * u)
        case .surprised:
            Ellipse().fill(.white).frame(width: 4.5 * u, height: 6 * u)
        }
    }

    @MainActor
    private func blinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64.random(in: 2_000_000_000...4_500_000_000))
            withAnimation(.easeInOut(duration: 0.08)) { blink = true }
            try? await Task.sleep(nanoseconds: 130_000_000)
            withAnimation(.easeInOut(duration: 0.08)) { blink = false }
        }
    }
}

/// A curved line (smile when depth > 0, arch when depth < 0). Fillable as a half moon.
struct Smile: Shape {
    var depth: CGFloat = 1
    func path(in r: CGRect) -> Path {
        var p = Path()
        let y = depth > 0 ? r.minY : r.maxY
        p.move(to: CGPoint(x: r.minX, y: y))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: y),
                       control: CGPoint(x: r.midX, y: y + (depth > 0 ? r.height * 2 : -r.height * 2)))
        return p
    }
}

// MARK: - Copy and headers

/// Time-aware greeting using the macOS account's first name.
enum Voice {
    static var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 5 ? "Still up" : h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : h < 22 ? "Good evening" : "Night owl"
        let name = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
        return name.isEmpty ? part : "\(part), \(name)"
    }

    static func clipboardQuip(count: Int, paused: Bool) -> String {
        if paused { return "Zzz… I'm not watching" }
        if count == 0 { return "Copy something, I'm ready" }
        let options = ["\(count) clips, all safe with me", "Everything is one search away",
                       "\(count) things remembered", "Your clipboard has a memory now"]
        return options[count % options.count]
    }
}

/// Header with Snip on the left, a title, a one-line quip and trailing actions.
struct PersonalHeader<Trailing: View>: View {
    let mood: Mood
    let title: String
    let quip: String
    let trailing: Trailing

    init(mood: Mood, title: String, quip: String, @ViewBuilder trailing: () -> Trailing) {
        self.mood = mood; self.title = title; self.quip = quip; self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            Mascot(mood: mood, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(quip)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .id(quip)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            Spacer(minLength: 4)
            HStack(spacing: 8) { trailing }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.2), value: quip)
    }
}

extension PersonalHeader where Trailing == EmptyView {
    init(mood: Mood, title: String, quip: String) {
        self.init(mood: mood, title: title, quip: quip) { EmptyView() }
    }
}
