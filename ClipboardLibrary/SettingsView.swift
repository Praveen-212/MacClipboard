import SwiftUI
import SwiftData

struct SettingsView: View {

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag("general")

            ShortcutSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag("shortcuts")

            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }
                .tag("privacy")

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag("about")
        }
        .frame(width: 520, height: 480)
    }
}

// MARK: - 1. General Settings Tab

struct GeneralSettingsView: View {

    @AppStorage("isMonitoringEnabled") private var isMonitoringEnabled = true
    @ObservedObject private var loginManager = LaunchAtLoginManager.shared

    var body: some View {
        Form {
            Section("Clipboard Monitoring") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Enable Clipboard Monitoring", isOn: $isMonitoringEnabled)
                        .onChange(of: isMonitoringEnabled) { _, newValue in
                            if newValue {
                                ClipboardMonitor.shared.startMonitoring()
                            } else {
                                ClipboardMonitor.shared.stopMonitoring()
                            }
                        }

                    Text("Automatically captures text copied in other applications to your clipboard history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(isMonitoringEnabled ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)

                        Text(isMonitoringEnabled ? "Monitoring Active" : "Monitoring Paused")
                            .font(.caption2.bold())
                            .foregroundStyle(isMonitoringEnabled ? .green : .secondary)
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 4)
            }

            Section("Launch Options") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Launch Clipboard Library at Login", isOn: Binding(
                        get: { loginManager.isEnabled },
                        set: { loginManager.setLaunchAtLogin(enabled: $0) }
                    ))

                    Text("Starts Clipboard Library in the background automatically when you log into your Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if loginManager.requiresApproval {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Approval required in macOS Login Items settings.")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Button("Open Settings") {
                                loginManager.openLoginItemsSettings()
                            }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 2)
                    }

                    if let error = loginManager.errorMessage {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loginManager.refreshStatus()
        }
    }
}

// MARK: - 2. Shortcut Settings Tab

struct ShortcutSettingsView: View {

    @ObservedObject private var shortcutManager = GlobalShortcutManager.shared
    @Query(filter: #Predicate<ClipboardItem> { $0.isFavorite && $0.shortcut != nil })
    private var shortcutItems: [ClipboardItem]

    var body: some View {
        Form {
            Section("Accessibility Permission") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Global Paste Simulation")
                            .font(.body.bold())

                        Spacer()

                        if shortcutManager.isAccessibilityGranted {
                            Label("Granted", systemImage: "checkmark.circle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        } else {
                            Label("Permission Required", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                    }

                    Text("Global shortcuts use macOS Accessibility permissions to paste favorite snippets directly into active apps. Text is always copied to clipboard regardless of permission.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !shortcutManager.isAccessibilityGranted {
                        HStack(spacing: 8) {
                            Button("Request Permission") {
                                shortcutManager.requestAccessibilityPermission()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Open System Settings") {
                                shortcutManager.openAccessibilitySettings()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Active Global Shortcuts (\(shortcutItems.count))") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Favorites with an assigned shortcut can be pasted into any application with a single keystroke.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if shortcutItems.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Image(systemName: "keyboard")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text("No shortcuts assigned yet.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Click 'Add Shortcut' on any favorite item to assign one.")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 12)
                            Spacer()
                        }
                    } else {
                        ForEach(shortcutItems) { item in
                            HStack(spacing: 8) {
                                if let shortcutDisplay = GlobalShortcut.displayString(from: item.shortcut) {
                                    Text(shortcutDisplay)
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.12))
                                        .foregroundStyle(Color.accentColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }

                                Text(item.content)
                                    .font(.callout)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            shortcutManager.checkAccessibilityPermission()
        }
    }
}

// MARK: - 3. Privacy Settings Tab

struct PrivacySettingsView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ClipboardItem]

    @State private var confirmPeriod: DeletionPeriod?
    @State private var clearSuccessMessage: String?
    @State private var clearErrorMessage: String?

    private var historyCount: Int {
        allItems.filter { $0.isInHistory ?? true }.count
    }

    private var favoriteCount: Int {
        allItems.filter { $0.isFavorite }.count
    }

    var body: some View {
        Form {
            Section("Data Privacy & Local Storage") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.green)
                        Text("Your clipboard data stays on this Mac.")
                            .font(.body.bold())
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        privacyBullet(icon: "internaldrive", text: "Stored locally on this device in standard SwiftData storage.")
                        privacyBullet(icon: "lock.slash", text: "Database is unencrypted at rest; protected by macOS user account permissions and FileVault.")
                        privacyBullet(icon: "network.slash", text: "Zero network connections: clipboard text is never sent over any network.")
                        privacyBullet(icon: "person.crop.circle.badge.xmark", text: "No accounts, logins, or cloud synchronization.")
                        privacyBullet(icon: "chart.line.downtrend.xyaxis", text: "Zero telemetry, analytics, or background tracking.")
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }

            Section("Sensitive Clipboard Content") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.shield")
                            .foregroundStyle(.orange)
                        Text("Sensitive Information Advisory")
                            .font(.callout.bold())
                    }

                    Text("Clipboard Library captures all text copied while monitoring is active. The app does not attempt to automatically filter out passwords, tokens, or private keys. If you need to copy sensitive credentials, pause monitoring in General settings or clear history afterwards.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("History Management & Deletion") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Delete clipboard history by time period. Favorites will NOT be deleted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Button("Delete Today...") {
                                confirmPeriod = .today
                            }
                            .buttonStyle(.bordered)

                            Button("Delete Yesterday...") {
                                confirmPeriod = .yesterday
                            }
                            .buttonStyle(.bordered)

                            Button("Delete This Week...") {
                                confirmPeriod = .thisWeek
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack(spacing: 8) {
                            Button("Delete This Month...") {
                                confirmPeriod = .thisMonth
                            }
                            .buttonStyle(.bordered)

                            Button("Delete Last 90 Days...") {
                                confirmPeriod = .last90Days
                            }
                            .buttonStyle(.bordered)
                        }

                        Divider()
                            .padding(.vertical, 2)

                        HStack {
                            Button(role: .destructive) {
                                confirmPeriod = .allHistory
                            } label: {
                                Label("Clear All History (\(historyCount))", systemImage: "trash")
                            }
                            .disabled(historyCount == 0)

                            if favoriteCount > 0 {
                                Text("(\(favoriteCount) favorites preserved)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let success = clearSuccessMessage {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(success)
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }

                    if let error = clearErrorMessage {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            confirmPeriod?.confirmationTitle ?? "Delete History?",
            isPresented: Binding(
                get: { confirmPeriod != nil },
                set: { if !$0 { confirmPeriod = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let period = confirmPeriod {
                Button("Delete", role: .destructive) {
                    deleteHistory(for: period)
                }
                Button("Cancel", role: .cancel) {
                    confirmPeriod = nil
                }
            }
        } message: {
            if let period = confirmPeriod {
                Text(period.confirmationMessage)
            }
        }
    }

    private func privacyBullet(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func deleteHistory(for period: DeletionPeriod) {
        let store = ClipboardStore(modelContext: modelContext)
        do {
            let result = try store.deleteHistory(for: period, preserveFavorites: true)
            clearSuccessMessage = "Deleted \(result.deletedCount) items from \(period.rawValue.lowercased()). \(result.preservedFavoritesCount) favorites preserved."
            clearErrorMessage = nil
            confirmPeriod = nil
        } catch {
            clearErrorMessage = "Failed to delete history: \(error.localizedDescription)"
            clearSuccessMessage = nil
        }
    }
}

// MARK: - 4. About Tab

struct AboutSettingsView: View {

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)

                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text("Clipboard Library")
                    .font(.title2.bold())

                Text("Version 1.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("“Copy once. Find it whenever you need it.”")
                .font(.callout.italic())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Divider()
                .frame(width: 240)

            VStack(spacing: 3) {
                Text("Native macOS Utility")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Built with SwiftUI & SwiftData")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
