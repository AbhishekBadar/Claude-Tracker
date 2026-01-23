import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var manager: MenuBarManager
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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                header
                tabBar
                if selectedTab == .usage {
                    usageSection
                } else {
                    keySection
                }
            }
            .padding(14)
        }
        .frame(width: 300)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Claude Tracker")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Text(manager.profileUsages.isEmpty ? "Waiting for data" : "Updated \(lastUpdatedText)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
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
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(manager.isRefreshing)
        }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
    }

    private var usageSection: some View {
        VStack(spacing: 10) {
            if manager.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            if manager.profileUsages.isEmpty {
                Text("Add a profile to fetch usage.")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                    )
            } else {
                ForEach(manager.profileUsages) { profileUsage in
                    ProfileUsageCard(profileUsage: profileUsage, onDelete: {
                        manager.removeProfile(id: profileUsage.id)
                    })
                }
            }
        }
    }

    private var tabBar: some View {
        Picker("", selection: $selectedTab) {
            ForEach(Tab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add profile")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

            TextField("Profile name", text: $profileNameInput)
                .textFieldStyle(.roundedBorder)

            SecureField("Session key (sk-...)", text: $sessionKeyInput)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Button("Save Key") {
                    manager.addProfile(name: profileNameInput, sessionKey: sessionKeyInput)
                    profileNameInput = ""
                    sessionKeyInput = ""
                }
                .buttonStyle(PrimaryCapsuleButton())
                .disabled(
                    profileNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                Spacer()

                if manager.hasProfiles {
                    Button("Delete All") {
                        showDeleteAllConfirm = true
                    }
                    .buttonStyle(GhostCapsuleButton())
                }

                Button("Quit") {
                    manager.quit()
                }
                .buttonStyle(GhostCapsuleButton())
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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
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
    let onDelete: () -> Void
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(profileUsage.name)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                if let usage = profileUsage.usage {
                    Text("\(Int(usage.sessionPercentage.rounded()))%")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            if let usage = profileUsage.usage {
                ProgressCapsule(value: Int(usage.sessionPercentage.rounded()))

                if let resetTime = usage.sessionResetTime {
                    Text("Reset \(formatTime(resetTime))")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }

                if let weekly = usage.weeklyPercentage {
                    Text("Weekly \(Int(weekly.rounded()))%")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if let error = profileUsage.errorMessage {
                Text(error)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
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

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct ProgressCapsule: View {
    let value: Int

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fill = max(0, min(1, CGFloat(value) / 100.0))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 8)

                Capsule()
                    .fill(
                        Color.white
                    )
                    .frame(width: width * fill, height: 8)
            }
        }
        .frame(height: 8)
    }
}

private struct PrimaryCapsuleButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

private struct GhostCapsuleButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
