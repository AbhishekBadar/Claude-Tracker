import Cocoa
import SwiftUI
import Combine

class MenuBarManager: NSObject, ObservableObject {
    @Published private(set) var profiles: [ProfileRecord] = []
    @Published private(set) var profileUsages: [ProfileUsage] = []
    @Published private(set) var isRefreshing: Bool = false

    @Published var appearanceMode: AppearanceMode = .system {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: Self.appearanceKey) }
    }
    @Published var accentTheme: AccentTheme = .blue {
        didSet { UserDefaults.standard.set(accentTheme.rawValue, forKey: Self.accentKey) }
    }

    private static let appearanceKey = "appearanceMode"
    private static let accentKey = "accentTheme"

    private let service = UsageService()

    override init() {
        super.init()
        if let raw = UserDefaults.standard.string(forKey: Self.appearanceKey),
           let mode = AppearanceMode(rawValue: raw) {
            appearanceMode = mode
        }
        if let raw = UserDefaults.standard.string(forKey: Self.accentKey),
           let theme = AccentTheme(rawValue: raw) {
            accentTheme = theme
        }
    }
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var refreshTimer: Timer?
    private var eventMonitor: Any?

    func setup() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Claude Tracker") {
            image.isTemplate = true
            statusItem.button?.image = image
            statusItem.button?.imagePosition = .imageOnly
        } else {
            statusItem.button?.title = "Claude"
        }
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        self.statusItem = statusItem

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverContentView(manager: self))
        self.popover = popover

        reloadProfiles()
        refreshAll()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
    }

    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        popover?.close()
        popover = nil
        statusItem = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    var hasProfiles: Bool {
        service.hasProfiles
    }

    func addProfile(name: String, sessionKey: String) {
        do {
            try service.addProfile(name: name, sessionKey: sessionKey)
            reloadProfiles()
            refreshAll()
        } catch {
            profileUsages = [ProfileUsage(id: UUID(), name: "Error", usage: nil, errorMessage: error.localizedDescription)]
        }
    }

    func removeProfile(id: UUID) {
        service.removeProfile(id: id)
        reloadProfiles()
        refreshAll()
    }

    func clearAllProfiles() {
        service.clearAllProfiles()
        reloadProfiles()
        refreshAll()
    }

    func refreshAll() {
        isRefreshing = true
        let currentProfiles = profiles

        Task { @MainActor in
            var results: [ProfileUsage] = []

            await withTaskGroup(of: ProfileUsage.self) { group in
                for profile in currentProfiles {
                    group.addTask {
                        do {
                            let usage = try await self.service.fetchUsage(for: profile)
                            return ProfileUsage(id: profile.id, name: profile.name, usage: usage, errorMessage: nil)
                        } catch {
                            return ProfileUsage(id: profile.id, name: profile.name, usage: nil, errorMessage: error.localizedDescription)
                        }
                    }
                }

                for await result in group {
                    results.append(result)
                }
            }

            profileUsages = results.sorted { $0.name.lowercased() < $1.name.lowercased() }
            isRefreshing = false
            updateStatusItem()
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            closePopover(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startEventMonitor()
        }
    }

    private func closePopover(_ sender: Any?) {
        popover?.performClose(sender)
        stopEventMonitor()
    }

    private func startEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover(nil)
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }

        let percentages = profileUsages.compactMap { $0.usage?.sessionPercentage }
        guard let maxPercentage = percentages.max() else {
            // No usable data yet — show the icon on its own.
            button.imagePosition = .imageOnly
            button.attributedTitle = NSAttributedString(string: "")
            return
        }

        let value = Int(maxPercentage.rounded())
        button.imagePosition = .imageLeading
        button.attributedTitle = NSAttributedString(
            string: " \(value)%",
            attributes: [
                .foregroundColor: UsageLevel(percentage: value).nsColor,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            ]
        )
    }

    private func reloadProfiles() {
        profiles = service.loadProfiles()
        if profiles.isEmpty {
            profileUsages = []
        }
    }
}

/// Maps a usage percentage to an urgency level with matching colors for both
/// AppKit (menu bar) and SwiftUI (popover) surfaces.
enum UsageLevel {
    case low      // calm — plenty of headroom
    case medium   // getting close to the limit
    case high     // nearly or fully consumed

    init(percentage: Int) {
        switch percentage {
        case ..<70: self = .low
        case 70..<90: self = .medium
        default: self = .high
        }
    }

    var color: Color {
        switch self {
        case .low: return Color(red: 0.30, green: 0.85, blue: 0.46)
        case .medium: return Color(red: 1.0, green: 0.72, blue: 0.20)
        case .high: return Color(red: 1.0, green: 0.35, blue: 0.33)
        }
    }

    var nsColor: NSColor {
        switch self {
        case .low: return NSColor(red: 0.30, green: 0.85, blue: 0.46, alpha: 1)
        case .medium: return NSColor(red: 1.0, green: 0.72, blue: 0.20, alpha: 1)
        case .high: return NSColor(red: 1.0, green: 0.35, blue: 0.33, alpha: 1)
        }
    }
}

/// How the popover decides between light and dark.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// `nil` means "follow the system" — handed straight to `.preferredColorScheme`.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// User-selectable accent used for interactive chrome (buttons, refresh, tabs).
/// Urgency colors (green/amber/red) are intentionally NOT themed — they carry meaning.
enum AccentTheme: String, CaseIterable, Identifiable {
    case blue, purple, pink, orange, green, graphite

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .blue: return Color(red: 0.00, green: 0.48, blue: 1.00)
        case .purple: return Color(red: 0.58, green: 0.35, blue: 0.95)
        case .pink: return Color(red: 0.96, green: 0.28, blue: 0.55)
        case .orange: return Color(red: 1.00, green: 0.55, blue: 0.15)
        case .green: return Color(red: 0.20, green: 0.74, blue: 0.45)
        case .graphite: return Color(red: 0.45, green: 0.48, blue: 0.52)
        }
    }
}

/// Semantic colors resolved for the effective (light or dark) appearance, so
/// the popover reads correctly in both modes instead of being hardcoded.
struct Palette {
    let background: Color
    let primaryText: Color
    let secondaryText: Color
    let cardFill: Color
    let cardStroke: Color
    let controlFill: Color
    let track: Color

    init(_ scheme: ColorScheme) {
        if scheme == .light {
            background = Color(white: 0.96)
            primaryText = .black
            secondaryText = .black.opacity(0.6)
            cardFill = .black.opacity(0.04)
            cardStroke = .black.opacity(0.12)
            controlFill = .black.opacity(0.05)
            track = .black.opacity(0.1)
        } else {
            background = .black
            primaryText = .white
            secondaryText = .white.opacity(0.7)
            cardFill = .white.opacity(0.06)
            cardStroke = .white.opacity(0.2)
            controlFill = .white.opacity(0.05)
            track = .white.opacity(0.1)
        }
    }
}
