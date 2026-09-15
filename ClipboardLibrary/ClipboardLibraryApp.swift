import SwiftUI
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    var modelContext: ModelContext?

    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 Application terminating: stopping services cleanly.")
        ClipboardMonitor.shared.stopMonitoring()
        GlobalShortcutManager.shared.unregisterAll()

        if let context = modelContext {
            do {
                try context.save()
                print("💾 Saved pending SwiftData context cleanly on termination.")
            } catch {
                print("⚠️ Failed to save context on termination: \(error)")
            }
        }
    }
}

extension Notification.Name {
    static let selectNavigationSection = Notification.Name("selectNavigationSection")
}

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Clipboard Library") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
            NotificationCenter.default.post(name: .selectNavigationSection, object: NavigationSection.library)
        }
        .keyboardShortcut("1", modifiers: .command)

        Button("Favorites") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
            NotificationCenter.default.post(name: .selectNavigationSection, object: NavigationSection.favorites)
        }
        .keyboardShortcut("2", modifiers: .command)

        Divider()

        Button("Settings...") {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Clipboard Library") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

@main
struct ClipboardLibraryApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let container: ModelContainer

    init() {
        // Enforce single instance to prevent duplicate monitors running simultaneously
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            let bundleID = Bundle.main.bundleIdentifier ?? "com.praveen.ClipboardLibrary"
            let currentPID = ProcessInfo.processInfo.processIdentifier
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if let otherApp = runningApps.first(where: { $0.processIdentifier != currentPID }) {
                print("⚠️ Another instance of ClipboardLibrary is already running (PID: \(otherApp.processIdentifier)). Terminating duplicate instance.")
                if #available(macOS 14.0, *) {
                    // `ignoringOtherApps` has no effect on macOS 14+, so just activate with no options.
                    _ = otherApp.activate(options: [])
                } else {
                    // Prior to macOS 14, keep the previous behavior.
                    _ = otherApp.activate(options: .activateIgnoringOtherApps)
                }
                exit(0)
            }
        }

        do {
            container = try ModelContainer(
                for: ClipboardItem.self
            )
        } catch {
            print("⚠️ Primary ModelContainer failed to initialize: \(error). Falling back to safe memory container.")
            do {
                let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                container = try ModelContainer(for: ClipboardItem.self, configurations: memoryConfig)
            } catch {
                preconditionFailure("Failed to initialize SwiftData storage: \(error.localizedDescription)")
            }
        }

        let context = ModelContext(container)
        appDelegate.modelContext = context

        let store = ClipboardStore(
            modelContext: context
        )

        // Automatically clean up existing consecutive duplicate records
        Task { @MainActor in
            store.cleanupDuplicates()
        }

        // Register all persistent global shortcuts for favorites
        Task { @MainActor in
            GlobalShortcutManager.shared.registerAllFavorites(from: context)
        }

        ClipboardMonitor.shared.configure { text in

            Task { @MainActor in
                store.save(content: text)
            }
        }

        let isMonitoringEnabled = UserDefaults.standard.object(forKey: "isMonitoringEnabled") as? Bool ?? true
        if isMonitoringEnabled {
            ClipboardMonitor.shared.startMonitoring()
        } else {
            print("📋 Clipboard monitoring is paused by user preference.")
        }
    }


    var body: some Scene {

        WindowGroup(id: "main") {
            ContentView()
        }
        .modelContainer(container)

        Settings {
            SettingsView()
                .modelContainer(container)
        }

        MenuBarExtra("Clipboard Library", systemImage: "doc.on.clipboard") {
            MenuBarView()
                .modelContainer(container)
        }
    }
}

