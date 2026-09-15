import SwiftUI
import AppKit
import SwiftData

struct ClipboardItemRow: View {

    let item: ClipboardItem
    var isFavoriteTab: Bool = false
    var onToggleFavorite: (() -> Void)?
    var onSelect: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    @State private var isCopied = false
    @State private var isHovered = false
    @State private var showShortcutRecorder = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // Content preview & metadata (Click to open full content view)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.content)
                    .lineLimit(3)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    // Timestamp
                    Label(
                        item.createdAt.formatted(
                            date: .omitted,
                            time: .shortened
                        ),
                        systemImage: "clock"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    // Characters or lines count pill
                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(metadataLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let source = item.sourceApplication, !source.isEmpty {
                        Text("•")
                            .foregroundStyle(.tertiary)

                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if item.isFavorite {
                        Text("•")
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.yellow)
                            Text("Favorited")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Shortcut badge if assigned
                    if let shortcutDisplay = GlobalShortcut.displayString(from: item.shortcut) {
                        Text("•")
                            .foregroundStyle(.tertiary)

                        Button {
                            showShortcutRecorder = true
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "keyboard")
                                    .font(.system(size: 9))
                                Text(shortcutDisplay)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Global Shortcut: \(shortcutDisplay). Click to change.")
                    } else if item.isFavorite && isFavoriteTab {
                        // Quick button to add shortcut in Favorites view
                        Text("•")
                            .foregroundStyle(.tertiary)

                        Button {
                            showShortcutRecorder = true
                        } label: {
                            Label("Add Shortcut", systemImage: "plus")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(isHovered ? 0.15 : 0.08))
                                .foregroundStyle(.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .help("Assign a global keyboard shortcut to this favorite")
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect?()
            }

            Spacer(minLength: 8)

            // Action buttons
            HStack(spacing: 4) {
                // Shortcut button (if favorite but no shortcut yet)
                if item.isFavorite && item.shortcut == nil && !isFavoriteTab && isHovered {
                    Button {
                        showShortcutRecorder = true
                    } label: {
                        Image(systemName: "keyboard")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Assign Shortcut")
                }

                // Favorite Button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        if let onToggleFavorite {
                            onToggleFavorite()
                        } else {
                            toggleFavorite()
                        }
                    }
                } label: {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 13))
                        .foregroundStyle(item.isFavorite ? Color.yellow : Color.secondary.opacity(isHovered ? 0.85 : 0.4))
                        .symbolEffect(.bounce, value: item.isFavorite)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(item.isFavorite ? Color.yellow.opacity(0.12) : (isHovered ? Color.secondary.opacity(0.1) : Color.clear))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.isFavorite ? "Remove from Favorites" : "Add to Favorites")

                // Copy Button
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundStyle(isCopied ? Color.green : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(isCopied ? Color.green.opacity(0.12) : (isHovered ? Color.secondary.opacity(0.1) : Color.clear))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isCopied ? "Copied!" : "Copy to Clipboard")

                // Delete Button (visible on hover)
                if isHovered {
                    Button(role: .destructive) {
                        deleteItem()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.red.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Delete Item")
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
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

    private var metadataLabel: String {
        let lines = item.content.components(separatedBy: .newlines).count
        let charCount = item.content.count

        if lines > 1 {
            return "\(lines) lines, \(charCount) chars"
        } else {
            return "\(charCount) chars"
        }
    }

    private func toggleFavorite() {
        let store = ClipboardStore(modelContext: modelContext)
        store.toggleFavorite(item)
    }

    private func deleteItem() {
        withAnimation {
            let store = ClipboardStore(modelContext: modelContext)
            try? store.deleteItem(item)
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
}



