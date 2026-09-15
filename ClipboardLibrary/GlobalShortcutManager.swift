import Foundation
import Combine
import Carbon
import AppKit
import SwiftData

final class GlobalShortcutManager: ObservableObject {

    static let shared = GlobalShortcutManager()

    // Accessibility permission status for UI binding
    @Published var isAccessibilityGranted: Bool = false

    // Registered hotkeys map: ID -> (EventHotKeyRef, UUID, String (content))
    private var registeredHotKeys: [UInt32: (ref: EventHotKeyRef, itemID: UUID, content: String)] = [:]
    private var itemToHotKeyID: [UUID: UInt32] = [:]
    private var nextHotKeyID: UInt32 = 1

    private var eventHandlerInstalled = false
    private var carbonEventHandlerRef: EventHandlerRef?
    private let lock = NSLock()

    private init() {
        checkAccessibilityPermission()
        installCarbonEventHandler()
    }

    // MARK: - Permissions

    @discardableResult
    func checkAccessibilityPermission() -> Bool {
        let granted = AXIsProcessTrusted()
        DispatchQueue.main.async {
            self.isAccessibilityGranted = granted
        }
        return granted
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        checkAccessibilityPermission()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Carbon Global Event Handler

    private func installCarbonEventHandler() {
        guard !eventHandlerInstalled else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if status == noErr {
                    GlobalShortcutManager.shared.handleHotKeyTriggered(id: hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &carbonEventHandlerRef
        )

        if status == noErr {
            eventHandlerInstalled = true
            print("⌨️ Carbon global hotkey event handler installed successfully.")
        } else {
            print("❌ Failed to install Carbon event handler: \(status)")
        }
    }

    // MARK: - HotKey Trigger Action

    func handleHotKeyTriggered(id: UInt32) {
        lock.lock()
        guard let entry = registeredHotKeys[id] else {
            lock.unlock()
            return
        }
        let content = entry.content
        lock.unlock()

        print("⌨️ Global hotkey triggered for item: \(entry.itemID)")

        // 1. Write item's content to NSPasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)

        // 2. Tell ClipboardMonitor to ignore this programmatic change
        ClipboardMonitor.shared.ignoreChange(changeCount: pasteboard.changeCount, content: content)

        // 3. Simulate Cmd+V to paste into the active frontmost app
        simulatePaste()
    }

    func simulatePaste() {
        // If Accessibility permission is not granted, the text is still copied to clipboard
        guard AXIsProcessTrusted() else {
            print("⚠️ Accessibility permission not granted; text is copied to clipboard, but cannot auto-paste.")
            checkAccessibilityPermission()
            return
        }

        // Small delay to ensure the target app is ready to receive input
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
                return
            }

            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Shortcut Registration

    func registerShortcut(_ shortcut: GlobalShortcut, for item: ClipboardItem) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // Unregister any previous shortcut for this item
        if let existingID = itemToHotKeyID[item.id] {
            if let entry = registeredHotKeys[existingID] {
                UnregisterEventHotKey(entry.ref)
            }
            registeredHotKeys.removeValue(forKey: existingID)
            itemToHotKeyID.removeValue(forKey: item.id)
        }

        let hotKeyIDNumber = nextHotKeyID
        nextHotKeyID += 1

        let hotKeyID = EventHotKeyID(
            signature: OSType(0x434C4950), // 'CLIP'
            id: hotKeyIDNumber
        )

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            registeredHotKeys[hotKeyIDNumber] = (ref: ref, itemID: item.id, content: item.content)
            itemToHotKeyID[item.id] = hotKeyIDNumber
            print("⌨️ Registered global shortcut '\(shortcut.display)' for item: \(item.id)")
            return true
        } else {
            print("❌ Failed to register global shortcut '\(shortcut.display)': status \(status)")
            return false
        }
    }

    func unregisterShortcut(for itemID: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard let hotKeyID = itemToHotKeyID[itemID] else { return }
        if let entry = registeredHotKeys[hotKeyID] {
            UnregisterEventHotKey(entry.ref)
        }
        registeredHotKeys.removeValue(forKey: hotKeyID)
        itemToHotKeyID.removeValue(forKey: itemID)
        print("⌨️ Unregistered shortcut for item: \(itemID)")
    }

    func unregisterAll() {
        lock.lock()
        defer { lock.unlock() }

        for (_, entry) in registeredHotKeys {
            UnregisterEventHotKey(entry.ref)
        }
        registeredHotKeys.removeAll()
        itemToHotKeyID.removeAll()

        if let handlerRef = carbonEventHandlerRef {
            RemoveEventHandler(handlerRef)
            carbonEventHandlerRef = nil
            eventHandlerInstalled = false
        }
        print("⌨️ All global shortcuts cleanly unregistered.")
    }

    func updateContent(_ content: String, for itemID: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard let hotKeyID = itemToHotKeyID[itemID],
              let entry = registeredHotKeys[hotKeyID] else { return }
        registeredHotKeys[hotKeyID] = (ref: entry.ref, itemID: entry.itemID, content: content)
    }

    // MARK: - Bulk Registration & Conflict Detection

    func registerAllFavorites(from modelContext: ModelContext) {
        var fetchDescriptor = FetchDescriptor<ClipboardItem>()
        do {
            let items = try modelContext.fetch(fetchDescriptor)
            var count = 0
            for item in items where item.isFavorite {
                if let shortcutString = item.shortcut,
                   let shortcut = GlobalShortcut.deserialize(from: shortcutString) {
                    if registerShortcut(shortcut, for: item) {
                        count += 1
                    }
                }
            }
            print("⌨️ Registered \(count) global shortcuts from favorites on launch.")
        } catch {
            print("⚠️ Failed to load favorites for global shortcuts: \(error)")
        }
    }

    func isShortcutTaken(
        _ shortcut: GlobalShortcut,
        excludingItemID: UUID?,
        in modelContext: ModelContext
    ) -> (taken: Bool, conflictingItemContent: String?) {
        var fetchDescriptor = FetchDescriptor<ClipboardItem>()
        guard let allItems = try? modelContext.fetch(fetchDescriptor) else {
            return (false, nil)
        }

        for item in allItems where item.isFavorite && item.id != excludingItemID {
            if let existingStr = item.shortcut,
               let existing = GlobalShortcut.deserialize(from: existingStr) {
                if existing.keyCode == shortcut.keyCode && existing.carbonModifiers == shortcut.carbonModifiers {
                    return (true, item.content)
                }
            }
        }
        return (false, nil)
    }
}
