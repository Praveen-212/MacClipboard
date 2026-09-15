import Foundation
import SwiftData
import AppKit

enum ClipboardStoreError: LocalizedError {
    case saveFailed(String)
    case deleteFailed(String)
    case clearHistoryFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Unable to save this clipboard item. Please try again."
        case .deleteFailed:
            return "Unable to delete this clipboard item. Please try again."
        case .clearHistoryFailed:
            return "Unable to clear clipboard history. Please try again."
        }
    }

    var failureReason: String? {
        switch self {
        case .saveFailed(let reason), .deleteFailed(let reason), .clearHistoryFailed(let reason):
            return reason
        }
    }
}

enum DeletionPeriod: String, CaseIterable, Identifiable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case last90Days = "Last 90 Days"
    case allHistory = "All History"

    var id: String { rawValue }
    var title: String { rawValue }

    func matches(date: Date, calendar: Calendar = .current) -> Bool {
        let now = Date()
        switch self {
        case .today:
            return calendar.isDateInToday(date)
        case .yesterday:
            return calendar.isDateInYesterday(date)
        case .thisWeek:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
                return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            }
            return weekInterval.contains(date)
        case .thisMonth:
            guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            }
            return monthInterval.contains(date)
        case .last90Days:
            let startOfToday = calendar.startOfDay(for: now)
            guard let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: startOfToday) else {
                return true
            }
            return date >= ninetyDaysAgo && date <= now
        case .allHistory:
            return true
        }
    }

    var confirmationTitle: String {
        switch self {
        case .today: return "Delete Today's History?"
        case .yesterday: return "Delete Yesterday's History?"
        case .thisWeek: return "Delete This Week's History?"
        case .thisMonth: return "Delete This Month's History?"
        case .last90Days: return "Delete Last 90 Days of History?"
        case .allHistory: return "Clear All Clipboard History?"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .today:
            return "This will permanently delete clipboard history from today. Your Favorites will NOT be deleted."
        case .yesterday:
            return "This will permanently delete clipboard history from yesterday. Your Favorites will NOT be deleted."
        case .thisWeek:
            return "This will permanently delete clipboard history from this week. Your Favorites will NOT be deleted."
        case .thisMonth:
            return "This will permanently delete clipboard history from this month. Your Favorites will NOT be deleted."
        case .last90Days:
            return "This will permanently delete clipboard history from the last 90 days. Your Favorites will NOT be deleted."
        case .allHistory:
            return "This will permanently delete all normal clipboard history. Your Favorites will NOT be deleted."
        }
    }
}

@MainActor
final class ClipboardStore {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Save

    func save(content: String, sourceApplication: String? = nil) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        // Check if an existing favorite already has this content
        var fetchAllDescriptor = FetchDescriptor<ClipboardItem>()
        if let allItems = try? modelContext.fetch(fetchAllDescriptor) {
            if let existingFavorite = allItems.first(where: { $0.isFavorite && $0.content == content }) {
                // Restore to history and bump timestamp
                existingFavorite.isInHistory = true
                existingFavorite.createdAt = Date()
                if let sourceApplication {
                    existingFavorite.sourceApplication = sourceApplication
                }
                try? modelContext.save()
                print("⭐ Restored existing favorite item to history top.")
                return
            }
        }

        // Prevent rapid duplicate consecutive entries from OS events
        var fetchDescriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        fetchDescriptor.fetchLimit = 1

        do {
            if let latest = try modelContext.fetch(fetchDescriptor).first {
                if latest.content == content {
                    let elapsed = Date().timeIntervalSince(latest.createdAt)
                    if elapsed < 1.2 {
                        print("📋 Rapid duplicate clipboard event ignored (\(String(format: "%.2f", elapsed))s).")
                        return
                    } else {
                        // Bumping timestamp for intentional user re-copy of the same text
                        latest.createdAt = Date()
                        latest.isInHistory = true
                        try modelContext.save()
                        print("📋 Bumped existing top clipboard item to current time.")
                        return
                    }
                }
            }
        } catch {
            print("⚠️ Failed to check latest clipboard item: \(error)")
        }

        let item = ClipboardItem(
            content: content,
            sourceApplication: sourceApplication
        )

        modelContext.insert(item)

        do {
            try modelContext.save()
            print("💾 Saved clipboard item (\(trimmedContent.count) characters).")
        } catch {
            print("❌ Failed to save clipboard item: \(error)")
        }
    }

    // MARK: - Delete Item

    func deleteItem(_ item: ClipboardItem) throws {
        if item.shortcut != nil {
            GlobalShortcutManager.shared.unregisterShortcut(for: item.id)
        }

        modelContext.delete(item)

        do {
            try modelContext.save()
            print("🗑️ Permanently deleted clipboard item: \(item.id)")
        } catch {
            print("❌ Failed to delete item: \(error)")
            throw ClipboardStoreError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Clear / Period Deletion Preserving Favorites

    @discardableResult
    func deleteHistory(
        for period: DeletionPeriod,
        preserveFavorites: Bool = true
    ) throws -> (deletedCount: Int, preservedFavoritesCount: Int) {
        var fetchDescriptor = FetchDescriptor<ClipboardItem>()
        let calendar = Calendar.current

        do {
            let items = try modelContext.fetch(fetchDescriptor)
            var deletedCount = 0
            var preservedCount = 0

            for item in items {
                guard period.matches(date: item.createdAt, calendar: calendar) else {
                    continue
                }

                // If already removed from history and not favorite, skip
                if !(item.isInHistory ?? true) && !item.isFavorite {
                    continue
                }

                if item.isFavorite {
                    if preserveFavorites {
                        // Mark as removed from history view while preserving in Favorites
                        item.isInHistory = false
                        preservedCount += 1
                    } else {
                        if item.shortcut != nil {
                            GlobalShortcutManager.shared.unregisterShortcut(for: item.id)
                        }
                        modelContext.delete(item)
                        deletedCount += 1
                    }
                } else {
                    // Normal history item: permanently remove
                    if item.shortcut != nil {
                        GlobalShortcutManager.shared.unregisterShortcut(for: item.id)
                    }
                    modelContext.delete(item)
                    deletedCount += 1
                }
            }

            try modelContext.save()
            print("🧹 Deleted history for \(period.rawValue): \(deletedCount) deleted, \(preservedCount) favorites preserved.")
            return (deletedCount, preservedCount)
        } catch {
            print("❌ Failed to delete history for \(period.rawValue): \(error)")
            throw ClipboardStoreError.clearHistoryFailed(error.localizedDescription)
        }
    }

    @discardableResult
    func clearHistory(preserveFavorites: Bool = true) throws -> (deletedCount: Int, preservedFavoritesCount: Int) {
        try deleteHistory(for: .allHistory, preserveFavorites: preserveFavorites)
    }

    // MARK: - Safe Copy to Pasteboard

    func copyToPasteboard(content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        ClipboardMonitor.shared.ignoreChange(changeCount: pasteboard.changeCount, content: content)
        print("📋 Safely copied to system clipboard without creating history record.")
    }

    // MARK: - Favorites & Cleanup

    func toggleFavorite(_ item: ClipboardItem) {
        item.isFavorite.toggle()
        if item.isFavorite {
            if let shortcutStr = item.shortcut,
               let shortcut = GlobalShortcut.deserialize(from: shortcutStr) {
                _ = GlobalShortcutManager.shared.registerShortcut(shortcut, for: item)
            }
        } else {
            GlobalShortcutManager.shared.unregisterShortcut(for: item.id)
            if !(item.isInHistory ?? true) {
                modelContext.delete(item)
            }
        }

        do {
            try modelContext.save()
            print("⭐ Updated favorite status for item: \(item.isFavorite)")
        } catch {
            print("❌ Failed to save favorite status: \(error)")
        }
    }

    func cleanupDuplicates() {
        var fetchDescriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let items = try modelContext.fetch(fetchDescriptor)
            var previousContent: String?
            var toDelete: [ClipboardItem] = []

            for item in items {
                if let prev = previousContent, prev == item.content {
                    // Never delete a favorited item during duplicate cleanup
                    if !item.isFavorite {
                        toDelete.append(item)
                    }
                } else {
                    previousContent = item.content
                }
            }

            for item in toDelete {
                if item.shortcut != nil {
                    GlobalShortcutManager.shared.unregisterShortcut(for: item.id)
                }
                modelContext.delete(item)
            }

            if !toDelete.isEmpty {
                try modelContext.save()
                print("🧹 Cleaned up \(toDelete.count) existing duplicate clipboard items.")
            }
        } catch {
            print("⚠️ Failed to clean up duplicate items: \(error)")
        }
    }
}
