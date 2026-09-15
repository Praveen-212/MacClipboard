import SwiftUI
import SwiftData
import AppKit

struct ClipboardItemDetailView: View {

    let item: ClipboardItem
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var isCopied = false
    @State private var showDeleteConfirmation = false
    @State private var showShortcutRecorder = false

    private var lineCount: Int {
        item.content.components(separatedBy: .newlines).count
    }

    private var charCount: Int {
        item.content.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clipboard Content")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Label(
                            item.createdAt.formatted(date: .abbreviated, time: .shortened),
                            systemImage: "calendar.badge.clock"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text("•")
                            .foregroundStyle(.tertiary)

                        Text("\(lineCount) \(lineCount == 1 ? "line" : "lines"), \(charCount) chars")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let source = item.sourceApplication, !source.isEmpty {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Label(source, systemImage: "app")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Shortcut pill if assigned
                if let shortcutDisplay = GlobalShortcut.displayString(from: item.shortcut) {
                    Button {
                        showShortcutRecorder = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "keyboard")
                                .font(.caption2)
                            Text(shortcutDisplay)
                                .font(.system(.caption, design: .monospaced, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Shortcut: \(shortcutDisplay). Click to change.")
                }

                // Close button
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Close (Esc)")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Scrollable Content View
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.content)
                        .font(.system(.body, design: .monospaced))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(20)
                }
            }
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))

            Divider()

            // Footer Toolbar Actions
            HStack(spacing: 12) {
                // Delete button
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.bordered)
                .help("Permanently delete this clipboard item")

                Spacer()

                // Favorite Toggle Button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        toggleFavorite()
                    }
                } label: {
                    Label(
                        item.isFavorite ? "Favorited" : "Favorite",
                        systemImage: item.isFavorite ? "star.fill" : "star"
                    )
                    .foregroundStyle(item.isFavorite ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.bordered)
                .help(item.isFavorite ? "Remove from Favorites" : "Save to Favorites")

                // Copy Button
                Button {
                    copyToClipboard()
                } label: {
                    Label(
                        isCopied ? "Copied!" : "Copy",
                        systemImage: isCopied ? "checkmark" : "doc.on.doc"
                    )
                    .foregroundStyle(isCopied ? Color.green : Color.primary)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("c", modifiers: .command)
                .help("Copy content to system clipboard (⌘C)")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 540, idealWidth: 640, minHeight: 400, idealHeight: 520)
        .confirmationDialog(
            "Delete Clipboard Item?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Item", role: .destructive) {
                deleteItem()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete this clipboard item? This action cannot be undone.")
        }
        .sheet(isPresented: $showShortcutRecorder) {
            ShortcutRecorderView(item: item) { newShortcut in
                if let newShortcut {
                    item.shortcut = newShortcut.serialize()
                    _ = GlobalShortcutManager.shared.registerShortcut(newShortcut, for: item)
                } else {
                    item.shortcut = nil
                    GlobalShortcutManager.shared.unregisterShortcut(for: item.id)
                }
                try? modelContext.save()
            }
        }
    }

    private func copyToClipboard() {
        let store = ClipboardStore(modelContext: modelContext)
        store.copyToPasteboard(content: item.content)

        withAnimation(.easeInOut(duration: 0.15)) {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.15)) {
                isCopied = false
            }
        }
    }

    private func toggleFavorite() {
        let store = ClipboardStore(modelContext: modelContext)
        store.toggleFavorite(item)
    }

    private func deleteItem() {
        let store = ClipboardStore(modelContext: modelContext)
        try? store.deleteItem(item)
        onDismiss()
    }
}
