import Cocoa
import SwiftUI
import Combine

class MenuBarManager: NSObject, ObservableObject {
    @Published private(set) var profiles: [ProfileRecord] = []
    @Published private(set) var profileUsages: [ProfileUsage] = []
    @Published private(set) var isRefreshing: Bool = false

    private let service = UsageService()
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
        if button.image == nil {
            button.title = "Claude Tracker"
        }
    }

    private func reloadProfiles() {
        profiles = service.loadProfiles()
        if profiles.isEmpty {
            profileUsages = []
        }
    }
}
