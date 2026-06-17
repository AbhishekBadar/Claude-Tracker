import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var manager: MenuBarManager
    @Environment(\.colorScheme) private var systemScheme
    @State private var sessionKeyInput: String = ""
    @State private var profileNameInput: String = ""
    @State private var spinRefresh = false
    @State private var selectedTab: Tab = .usage
    @State private var showDeleteAllConfirm = false

    private enum Tab: String, CaseIterable, Identifiable {
        case usage = "Usage"
        case manage = "Manage"

        var id: String { rawValue }
    }

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// Light or dark, after applying the user's choice (System resolves to the OS setting).
    private var scheme: ColorScheme {
        manager.appearanceMode.colorScheme ?? systemScheme
    }

    private var palette: Palette { Palette(scheme) }
    private var accent: Color { manager.accentTheme.color }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 14) {
                header
                tabBar
                if selectedTab == .usage {
                    usageSection
                } else {
                    manageSection
                }
            }
            .padding(14)
        }
        .frame(width: 300)
        .tint(accent)
        .preferredColorScheme(manager.appearanceMode.colorScheme)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Claude Tracker")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(palette.primaryText)
                Text(manager.profileUsages.isEmpty ? "Waiting for data" : "Updated \(lastUpdatedText)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(palette.secondaryText)
            }

            Spacer()

            Button {
                manager.refreshAll()
                withAnimation(.easeInOut(duration: 0.6)) {
                    spinRefresh.toggle()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(.degrees(spinRefresh ? 360 : 0))
                    .foregroundColor(accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(palette.controlFill))
                    .overlay(Circle().stroke(palette.cardStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(manager.isRefreshing)
            .accessibilityLabel("Refresh usage")
        }
        .padding(12)
        .background(cardBackground)
    }

    private var usageSection: some View {
        VStack(spacing: 10) {
            if manager.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            if manager.profiles.isEmpty {
                emptyState("Add a profile to fetch usage.")
            } else if manager.profileUsages.isEmpty {
                emptyState("Loading usage…")
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(manager.profileUsages) { profileUsage in
                            ProfileUsageCard(profileUsage: profileUsage, palette: palette, onDelete: {
                                manager.removeProfile(id: profileUsage.id)
                            })
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
        }
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundColor(palette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(palette.cardFill)
            )
    }

    private var tabBar: some View {
        Picker("", selection: $selectedTab) {
            ForEach(Tab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var manageSection: some View {
        ScrollView {
            VStack(spacing: 12) {
                keySection
                themeSection
            }
        }
        .frame(maxHeight: 360)
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add profile")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(palette.secondaryText)

            TextField("Profile name", text: $profileNameInput)
                .textFieldStyle(.roundedBorder)

            SecureField("Session key (sk-...)", text: $sessionKeyInput)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Button("Add Profile") {
                    manager.addProfile(name: profileNameInput, sessionKey: sessionKeyInput)
                    profileNameInput = ""
                    sessionKeyInput = ""
                }
                .buttonStyle(PrimaryCapsuleButton(accent: accent))
                .disabled(
                    profileNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                Spacer()

                if manager.hasProfiles {
                    Button("Delete All") {
                        showDeleteAllConfirm = true
                    }
                    .buttonStyle(GhostCapsuleButton(palette: palette))
                }

                Button("Quit") {
                    manager.quit()
                }
                .buttonStyle(GhostCapsuleButton(palette: palette))
            }
        }
        .confirmationDialog(
            "Delete all profiles?",
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                manager.clearAllProfiles()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all stored session keys.")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appearance")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(palette.secondaryText)

            Picker("", selection: $manager.appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("Accent")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(palette.secondaryText)

            HStack(spacing: 10) {
                ForEach(AccentTheme.allCases) { theme in
                    Button {
                        manager.accentTheme = theme
                    } label: {
                        Circle()
                            .fill(theme.color)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(palette.primaryText,
                                            lineWidth: manager.accentTheme == theme ? 2 : 0)
                                    .padding(1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(theme.label) accent")
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }

    private var lastUpdatedText: String {
        let latest = manager.profileUsages
            .compactMap { $0.usage?.lastUpdated }
            .sorted(by: >)
            .first
        guard let lastUpdated = latest else { return "just now" }
        return timeFormatter.string(from: lastUpdated)
    }
}

private struct ProfileUsageCard: View {
    let profileUsage: ProfileUsage
    let palette: Palette
    let onDelete: () -> Void
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(profileUsage.name)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(palette.primaryText)
                Spacer()
                if let usage = profileUsage.usage {
                    let value = Int(usage.sessionPercentage.rounded())
                    Text("\(value)%")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(UsageLevel(percentage: value).color)
                }
                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(palette.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(profileUsage.name)")
            }

            if let usage = profileUsage.usage {
                ProgressCapsule(value: Int(usage.sessionPercentage.rounded()), track: palette.track)

                if let resetTime = usage.sessionResetTime {
                    Text("Resets in \(relativeReset(resetTime))")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(palette.secondaryText)
                }

                if let weekly = usage.weeklyPercentage {
                    let weeklyValue = Int(weekly.rounded())
                    HStack(spacing: 4) {
                        Text("Weekly")
                            .foregroundColor(palette.secondaryText)
                        Text("\(weeklyValue)%")
                            .foregroundColor(UsageLevel(percentage: weeklyValue).color)
                        if let weeklyReset = usage.weeklyResetTime {
                            Text("· Resets in \(relativeReset(weeklyReset))")
                                .foregroundColor(palette.secondaryText)
                        }
                    }
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                }
            } else if let error = profileUsage.errorMessage {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text(error)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(UsageLevel(percentage: 100).color)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
        .confirmationDialog(
            "Delete \(profileUsage.name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the session key for this profile.")
        }
    }

    private func relativeReset(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "now" }

        let totalMinutes = Int(interval / 60)
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes % (60 * 24)) / 60
        let minutes = totalMinutes % 60

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

private struct ProgressCapsule: View {
    let value: Int
    let track: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fill = max(0, min(1, CGFloat(value) / 100.0))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(track)
                    .frame(height: 8)

                Capsule()
                    .fill(UsageLevel(percentage: value).color)
                    .frame(width: width * fill, height: 8)
            }
        }
        .frame(height: 8)
    }
}

private struct PrimaryCapsuleButton: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(accent)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

private struct GhostCapsuleButton: ButtonStyle {
    let palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundColor(palette.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(palette.controlFill)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
