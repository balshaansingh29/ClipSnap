import Foundation
import ServiceManagement

/// Single place for user preferences, backed by UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let d = UserDefaults.standard

    @Published var maxHistory: Int { didSet { d.set(maxHistory, forKey: "maxHistory") } }
    @Published var pasteAutomatically: Bool { didSet { d.set(pasteAutomatically, forKey: "pasteAutomatically") } }
    @Published var captureImages: Bool { didSet { d.set(captureImages, forKey: "captureImages") } }
    @Published var excludedApps: [String] { didSet { d.set(excludedApps, forKey: "excludedApps") } }

    @Published var dragSnapEnabled: Bool { didSet { d.set(dragSnapEnabled, forKey: "dragSnapEnabled") } }
    @Published var cycleOnRepeat: Bool { didSet { d.set(cycleOnRepeat, forKey: "cycleOnRepeat") } }
    @Published var windowGap: Double { didSet { d.set(windowGap, forKey: "windowGap") } }
    @Published var almostMaxFraction: Double { didSet { d.set(almostMaxFraction, forKey: "almostMaxFraction") } }
    @Published var shakeToSnap: Bool { didSet { d.set(shakeToSnap, forKey: "shakeToSnap") } }
    @Published var hasOnboarded: Bool { didSet { d.set(hasOnboarded, forKey: "hasOnboarded") } }
    @Published var showHUD: Bool { didSet { d.set(showHUD, forKey: "showHUD") } }

    /// Apps whose copies are never recorded (password managers etc.).
    static let defaultExcluded = [
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.lastpass.LastPass",
        "com.apple.keychainaccess",
    ]

    private init() {
        d.register(defaults: [
            "maxHistory": 200,
            "pasteAutomatically": true,
            "captureImages": true,
            "excludedApps": AppSettings.defaultExcluded,
            "dragSnapEnabled": true,
            "cycleOnRepeat": true,
            "windowGap": 0.0,
            "almostMaxFraction": 0.9,
            "shakeToSnap": true,
            "hasOnboarded": false,
            "showHUD": true,
        ])
        maxHistory = d.integer(forKey: "maxHistory")
        pasteAutomatically = d.bool(forKey: "pasteAutomatically")
        captureImages = d.bool(forKey: "captureImages")
        excludedApps = d.stringArray(forKey: "excludedApps") ?? AppSettings.defaultExcluded
        dragSnapEnabled = d.bool(forKey: "dragSnapEnabled")
        cycleOnRepeat = d.bool(forKey: "cycleOnRepeat")
        windowGap = d.double(forKey: "windowGap")
        almostMaxFraction = d.double(forKey: "almostMaxFraction")
        shakeToSnap = d.bool(forKey: "shakeToSnap")
        hasOnboarded = d.bool(forKey: "hasOnboarded")
        showHUD = d.bool(forKey: "showHUD")
    }

    // MARK: Launch at login (works once the app runs from a real .app bundle)

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("ClipSnap: launch-at-login change failed: \(error)")
            }
        }
    }
}
