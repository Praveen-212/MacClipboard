import SwiftUI
import SwiftData
import AppKit

enum NavigationSection: String, CaseIterable, Identifiable {
    case library = "Library"
    case favorites = "Favorites"
    case calendar = "Calendar"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .library: return "doc.on.clipboard"
        case .favorites: return "star.fill"
        case .calendar: return "calendar"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.createdAt, order: .reverse)
    private var clipboardItems: [ClipboardItem]

    @ObservedObject private var shortcutManager = GlobalShortcutManager.shared

    @State private var selectedSection: NavigationSection = .library
    @State private var selectedCalendarDate: Date = Date()
    @State private var searchText = ""
    @State private var showGraphicalCalendar = false

    @State private var selectedItemForDetail: ClipboardItem?
    @State private var itemForShortcutConfig: ClipboardItem?
    @State private var confirmDeletionPeriod: DeletionPeriod?
    @State private var userErrorMessage: String?

    // MARK: - Computed Counts

    private var todayCount: Int {
        let calendar = Calendar.current
        return clipboardItems.filter { (item: ClipboardItem) in
            (item.isInHistory ?? true) && calendar.isDateInToday(item.createdAt)
        }.count
    }

    private var favoriteCount: Int {
        clipboardItems.filter { $0.isFavorite }.count
    }

    private var calendarCount: Int {
        let calendar = Calendar.current
        return clipboardItems.filter { (item: ClipboardItem) in
            (item.isInHistory ?? true) && calendar.isDate(item.createdAt, inSameDayAs: selectedCalendarDate)
        }.count
    }

    // MARK: - Items Filtering

    private var todayItems: [ClipboardItem] {
        let calendar = Calendar.current
        return clipboardItems.filter { (item: ClipboardItem) in
            (item.isInHistory ?? true) && calendar.isDateInToday(item.createdAt)
        }
    }

    private var favoriteItems: [ClipboardItem] {
        clipboardItems.filter { $0.isFavorite }
    }

    private var calendarItems: [ClipboardItem] {
        let calendar = Calendar.current
        return clipboardItems.filter { (item: ClipboardItem) in
            (item.isInHistory ?? true) && calendar.isDate(item.createdAt, inSameDayAs: selectedCalendarDate)
        }
    }

    private var displayedItems: [ClipboardItem] {
        let baseItems: [ClipboardItem]
        switch selectedSection {
        case .library:
            baseItems = todayItems
        case .favorites:
            baseItems = favoriteItems
        case .calendar:
            baseItems = calendarItems
        case .settings:
            return []
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return baseItems
        }

        return baseItems.filter {
            $0.content.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            // Sidebar Navigation
            sidebarView
        } detail: {
            // Detail Content
            detailView
        }
        .frame(minWidth: 700, idealWidth: 840, minHeight: 540, idealHeight: 640)
        .sheet(item: $selectedItemForDetail) { item in
            ClipboardItemDetailView(item: item) {
                selectedItemForDetail = nil
            }
        }
        .sheet(item: $itemForShortcutConfig) { item in
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
        .confirmationDialog(
            confirmDeletionPeriod?.confirmationTitle ?? "Delete History?",
            isPresented: Binding(
                get: { confirmDeletionPeriod != nil },
                set: { if !$0 { confirmDeletionPeriod = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let period = confirmDeletionPeriod {
                Button("Delete", role: .destructive) {
                    deleteHistory(for: period)
                }
                Button("Cancel", role: .cancel) {
                    confirmDeletionPeriod = nil
                }
            }
        } message: {
            if let period = confirmDeletionPeriod {
                Text(period.confirmationMessage)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectNavigationSection)) { notification in
            if let section = notification.object as? NavigationSection {
                withAnimation {
                    selectedSection = section
                }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        List(selection: $selectedSection) {
            Section("Clipboard") {
                NavigationLink(value: NavigationSection.library) {
                    HStack {
                        Label("Library", systemImage: NavigationSection.library.icon)
                        Spacer()
                        Text("\(todayCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .tag(NavigationSection.library)

                NavigationLink(value: NavigationSection.favorites) {
                    HStack {
                        Label("Favorites", systemImage: NavigationSection.favorites.icon)
                            .foregroundStyle(selectedSection == .favorites ? Color.yellow : Color.primary)
                        Spacer()
                        Text("\(favoriteCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .tag(NavigationSection.favorites)

                NavigationLink(value: NavigationSection.calendar) {
                    HStack {
                        Label("Calendar", systemImage: NavigationSection.calendar.icon)
                        Spacer()
                        if selectedSection == .calendar {
                            Text("\(calendarCount)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
                .tag(NavigationSection.calendar)
            }

            Section("Preferences") {
                NavigationLink(value: NavigationSection.settings) {
                    Label("Settings", systemImage: NavigationSection.settings.icon)
                }
                .tag(NavigationSection.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 240)
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailView: some View {
        if selectedSection == .settings {
            SettingsView()
                .navigationTitle("Settings")
        } else {
            clipboardListView
        }
    }

    private var clipboardListView: some View {
        VStack(spacing: 0) {
            // Accessibility banner in Favorites tab
            if selectedSection == .favorites && !shortcutManager.isAccessibilityGranted && favoriteCount > 0 {
                accessibilityNoticeBanner
            }

            // Error banner if operation failed
            if let error = userErrorMessage {
                errorBanner(message: error)
            }

            // Calendar Navigation Header (if Calendar section active)
            if selectedSection == .calendar {
                calendarHeaderBar
            }

            // Content Items or Empty State
            Group {
                if displayedItems.isEmpty {
                    emptyStateView
                } else {
                    List {
                        Section(sectionHeaderTitle) {
                            ForEach(displayedItems) { item in
                                ClipboardItemRow(
                                    item: item,
                                    isFavoriteTab: selectedSection == .favorites,
                                    onToggleFavorite: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            toggleFavorite(item)
                                        }
                                    },
                                    onSelect: {
                                        selectedItemForDetail = item
                                    }
                                )
                                .contextMenu {
                                    Button {
                                        copyToClipboard(item.content)
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }

                                    Button {
                                        selectedItemForDetail = item
                                    } label: {
                                        Label("View Full Content", systemImage: "doc.text.magnifyingglass")
                                    }

                                    Divider()

                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            toggleFavorite(item)
                                        }
                                    } label: {
                                        Label(
                                            item.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                            systemImage: item.isFavorite ? "star.slash" : "star"
                                        )
                                    }

                                    if item.isFavorite {
                                        Button {
                                            itemForShortcutConfig = item
                                        } label: {
                                            Label(
                                                item.shortcut != nil ? "Change Shortcut..." : "Assign Shortcut...",
                                                systemImage: "keyboard"
                                            )
                                        }

                                        if item.shortcut != nil {
                                            Button(role: .destructive) {
                                                item.shortcut = nil
                                                GlobalShortcutManager.shared.unregisterShortcut(for: item.id)
                                                try? modelContext.save()
                                            } label: {
                                                Label("Remove Shortcut", systemImage: "keyboard.badge.ellipsis")
                                            }
                                        }
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        deleteItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onDelete { indexSet in
                                withAnimation {
                                    let store = ClipboardStore(modelContext: modelContext)
                                    for index in indexSet {
                                        try? store.deleteItem(displayedItems[index])
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: searchPrompt
        )
        .toolbar {
            // Delete History by Period Menu
            ToolbarItem(placement: .automatic) {
                Menu {
                    Section("Delete History by Period") {
                        Button("Delete Today...") {
                            confirmDeletionPeriod = .today
                        }
                        Button("Delete Yesterday...") {
                            confirmDeletionPeriod = .yesterday
                        }
                        Button("Delete This Week...") {
                            confirmDeletionPeriod = .thisWeek
                        }
                        Button("Delete This Month...") {
                            confirmDeletionPeriod = .thisMonth
                        }
                        Button("Delete Last 90 Days...") {
                            confirmDeletionPeriod = .last90Days
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        confirmDeletionPeriod = .allHistory
                    } label: {
                        Label("Clear All History...", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete History Options")
            }

            // Settings button
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation {
                        selectedSection = .settings
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
        }
    }

    // MARK: - Calendar Header Bar

    private var calendarHeaderBar: some View {
        HStack(spacing: 12) {
            // Date Picker (Compact)
            DatePicker(
                "Date",
                selection: $selectedCalendarDate,
                in: ...Date(),
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .labelsHidden()

            // Popover Button for Graphical Calendar
            Button {
                showGraphicalCalendar.toggle()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
            }
            .buttonStyle(.bordered)
            .help("Browse Calendar Month")
            .popover(isPresented: $showGraphicalCalendar) {
                VStack(spacing: 8) {
                    DatePicker(
                        "Calendar",
                        selection: $selectedCalendarDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .frame(width: 270, height: 260)
                    .padding(10)

                    HStack {
                        Spacer()
                        Button("Jump to Today") {
                            selectedCalendarDate = Date()
                            showGraphicalCalendar = false
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }

            Text(formattedDateHeader)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            // Return to Today button
            if !Calendar.current.isDateInToday(selectedCalendarDate) {
                Button {
                    withAnimation {
                        selectedCalendarDate = Date()
                    }
                } label: {
                    Label("Today", systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Return to Today's Date")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Subviews & Banners

    private var accessibilityNoticeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Accessibility permission is needed to paste snippets into other apps.")
                .font(.caption)
                .foregroundStyle(.primary)

            Spacer()

            Button("Grant Permission") {
                GlobalShortcutManager.shared.openAccessibilitySettings()
            }
            .font(.caption2)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)

            Spacer()

            Button {
                userErrorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.1))
    }

    @ViewBuilder
    private var emptyStateView: some View {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            ContentUnavailableView {
                Label("No Results", systemImage: "magnifyingglass")
            } description: {
                Text("No clipboard items match your search.")
            }
        } else {
            switch selectedSection {
            case .library:
                ContentUnavailableView {
                    Label("No Clipboard History Today", systemImage: "doc.on.clipboard")
                } description: {
                    Text("Text you copy will appear here.")
                }

            case .favorites:
                ContentUnavailableView {
                    Label("No Favorites Yet", systemImage: "star")
                } description: {
                    Text("Star a clipboard item to keep it here.")
                }

            case .calendar:
                ContentUnavailableView {
                    Label("No Clipboard History on This Date", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text("No clipboard items were recorded on \(formattedDateHeader).")
                }

            case .settings:
                EmptyView()
            }
        }
    }

    // MARK: - Actions

    private func toggleFavorite(_ item: ClipboardItem) {
        let store = ClipboardStore(modelContext: modelContext)
        store.toggleFavorite(item)
    }

    private func deleteItem(_ item: ClipboardItem) {
        withAnimation {
            let store = ClipboardStore(modelContext: modelContext)
            do {
                try store.deleteItem(item)
            } catch {
                userErrorMessage = error.localizedDescription
            }
        }
    }

    private func deleteHistory(for period: DeletionPeriod) {
        withAnimation {
            let store = ClipboardStore(modelContext: modelContext)
            do {
                try store.deleteHistory(for: period, preserveFavorites: true)
                userErrorMessage = nil
                confirmDeletionPeriod = nil
            } catch {
                userErrorMessage = error.localizedDescription
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        let store = ClipboardStore(modelContext: modelContext)
        store.copyToPasteboard(content: text)
    }

    // MARK: - Helpers

    private var navigationTitle: String {
        switch selectedSection {
        case .library: return "Clipboard Library"
        case .favorites: return "Favorites"
        case .calendar: return "Calendar History"
        case .settings: return "Settings"
        }
    }

    private var sectionHeaderTitle: String {
        switch selectedSection {
        case .library:
            return "Today (\(displayedItems.count))"
        case .favorites:
            return "Favorites (\(displayedItems.count))"
        case .calendar:
            return "\(formattedDateHeader) (\(displayedItems.count))"
        case .settings:
            return ""
        }
    }

    private var formattedDateHeader: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedCalendarDate) {
            return "Today"
        } else if calendar.isDateInYesterday(selectedCalendarDate) {
            return "Yesterday"
        } else {
            return selectedCalendarDate.formatted(
                .dateTime
                    .month(.wide)
                    .day()
                    .year()
            )
        }
    }

    private var searchPrompt: String {
        switch selectedSection {
        case .library: return "Search today's clipboard..."
        case .favorites: return "Search favorites..."
        case .calendar: return "Search items on \(formattedDateHeader)..."
        case .settings: return "Search settings..."
        }
    }
}

