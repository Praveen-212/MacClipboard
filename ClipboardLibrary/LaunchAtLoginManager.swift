import Foundation
import Combine
import ServiceManagement
import AppKit

final class LaunchAtLoginManager: ObservableObject {

    static let shared = LaunchAtLoginManager()

    @Published var isEnabled: Bool = false
    @Published var requiresApproval: Bool = false
    @Published var errorMessage: String? = nil

    private init() {
        refreshStatus()
    }

    func refreshStatus() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            DispatchQueue.main.async {
                self.isEnabled = (status == .enabled)
                self.requiresApproval = (status == .requiresApproval)
            }
        }
    }

    func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                        print("🚀 Launch at login successfully registered.")
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                        print("🚀 Launch at login successfully unregistered.")
                    }
                }
                errorMessage = nil
            } catch {
                print("❌ Failed to update launch at login: \(error)")
                errorMessage = "Could not update login item: \(error.localizedDescription)"
            }
            refreshStatus()
        }
    }

    func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else if let fallbackUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(fallbackUrl)
        }
    }
}
