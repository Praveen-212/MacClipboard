import SwiftUI
import Carbon
import AppKit
import SwiftData

struct ShortcutRecorderView: View {

    let item: ClipboardItem
    let onSave: (GlobalShortcut?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var recordedShortcut: GlobalShortcut?
    @State private var conflictMessage: String?
    @State private var isListening = true
    @State private var localMonitor: Any?

    // Common quick presets
    private let presets: [(display: String, keyCode: UInt32, modifiers: UInt32)] = [
        ("⌘⇧1", 18, UInt32(cmdKey | shiftKey)),
        ("⌘⇧2", 19, UInt32(cmdKey | shiftKey)),
        ("⌘⇧3", 20, UInt32(cmdKey | shiftKey)),
        ("⌘⇧4", 21, UInt32(cmdKey | shiftKey)),
        ("⌘⇧5", 23, UInt32(cmdKey | shiftKey)),
        ("⌥⌘1", 18, UInt32(cmdKey | optionKey)),
        ("⌥⌘2", 19, UInt32(cmdKey | optionKey)),
        ("⌥⌘3", 20, UInt32(cmdKey | optionKey)),
        ("⌃⌥1", 18, UInt32(controlKey | optionKey)),
        ("⌃⌥2", 19, UInt32(controlKey | optionKey))
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "keyboard")
                        .font(.title2)
                        .foregroundStyle(.tint)
                    Text("Configure Global Shortcut")
                        .font(.headline)
                }

                Text("Press a key combination to paste this snippet from any app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Snippet Preview
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                Text(item.content)
                    .font(.callout)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Recording Display Box
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    conflictMessage != nil ? Color.red : (isListening ? Color.accentColor : Color.secondary.opacity(0.3)),
                                    lineWidth: isListening ? 2 : 1
                                )
                        )

                    if let shortcut = recordedShortcut {
                        Text(shortcut.display)
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(conflictMessage != nil ? .red : .primary)
                    } else {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Press shortcut keys on your keyboard...")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 70)

                // Conflict error message or modifier guidance
                if let conflict = conflictMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(conflict)
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                } else if recordedShortcut == nil {
                    Text("Shortcut must include at least one modifier key (⌘, ⌥, or ⌃)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Quick Presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Presets:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(presets, id: \.display) { preset in
                            Button {
                                selectPreset(preset)
                            } label: {
                                Text(preset.display)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Divider()

            // Action Buttons
            HStack {
                if item.shortcut != nil {
                    Button(role: .destructive) {
                        onSave(nil)
                        dismiss()
                    } label: {
                        Label("Remove Shortcut", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save Shortcut") {
                    if let recordedShortcut, conflictMessage == nil {
                        onSave(recordedShortcut)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(recordedShortcut == nil || conflictMessage != nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear {
            setupInitialState()
            startKeyboardMonitoring()
        }
        .onDisappear {
            stopKeyboardMonitoring()
        }
    }

    // MARK: - Helpers

    private func setupInitialState() {
        if let stored = item.shortcut,
           let shortcut = GlobalShortcut.deserialize(from: stored) {
            recordedShortcut = shortcut
        }
    }

    private func selectPreset(_ preset: (display: String, keyCode: UInt32, modifiers: UInt32)) {
        let shortcut = GlobalShortcut(
            display: preset.display,
            keyCode: preset.keyCode,
            carbonModifiers: preset.modifiers
        )
        validateAndSetShortcut(shortcut)
    }

    private func validateAndSetShortcut(_ shortcut: GlobalShortcut) {
        recordedShortcut = shortcut

        let (taken, conflictingText) = GlobalShortcutManager.shared.isShortcutTaken(
            shortcut,
            excludingItemID: item.id,
            in: modelContext
        )

        if taken {
            let preview = (conflictingText ?? "Another item").prefix(25)
            conflictMessage = "Already assigned to \"\(preview)...\""
        } else {
            conflictMessage = nil
        }
    }

    private func startKeyboardMonitoring() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handleKeyEvent(event)
            return nil // Consume key event inside recorder
        }
    }

    private func stopKeyboardMonitoring() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let carbonMods = GlobalShortcut.carbonModifiers(from: flags)

        // Must include at least Command, Option, or Control
        guard flags.contains(.command) || flags.contains(.option) || flags.contains(.control) else {
            return
        }

        let keyString = GlobalShortcut.keyString(for: event.keyCode)
        guard !keyString.isEmpty else { return }

        let modSymbols = GlobalShortcut.modifierSymbols(from: flags)
        let display = "\(modSymbols)\(keyString)"

        let shortcut = GlobalShortcut(
            display: display,
            keyCode: UInt32(event.keyCode),
            carbonModifiers: carbonMods
        )

        validateAndSetShortcut(shortcut)
    }
}
