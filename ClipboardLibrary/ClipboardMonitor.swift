import AppKit

final class ClipboardMonitor {

    // One and only one monitor for the entire application.
    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int = 0

    private var lastCapturedText: String?
    private var lastCapturedTime: Date = Date.distantPast

    private let lock = NSLock()

    private var onNewClipboardText: ((String) -> Void)?
    private var ignoredChangeCount: Int = -1
    private var ignoredContent: String?

    private init() {
    }

    // MARK: - Programmatic Change Coordination

    func ignoreChange(changeCount: Int, content: String) {
        lock.lock()
        defer { lock.unlock() }
        self.ignoredChangeCount = changeCount
        self.ignoredContent = content
        self.lastChangeCount = changeCount
        self.lastCapturedText = content
        self.lastCapturedTime = Date()
    }

    func ignoreNextChange() {
        lock.lock()
        defer { lock.unlock() }
        self.ignoredChangeCount = NSPasteboard.general.changeCount
    }

    // MARK: - Configure

    func configure(
        onNewClipboardText: @escaping (String) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }

        self.onNewClipboardText = onNewClipboardText
    }

    // MARK: - Start Monitoring

    func startMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        // Never create a second monitoring timer.
        guard timer == nil else {
            print("📋 Clipboard monitor is already running.")
            return
        }

        let pasteboard = NSPasteboard.general

        lastChangeCount = pasteboard.changeCount
        lastCapturedText = pasteboard.string(forType: .string)

        timer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            self?.checkClipboard()
        }

        print("📋 Clipboard monitor started.")
    }

    var isMonitoring: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timer != nil
    }

    // MARK: - Stop Monitoring

    func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        timer?.invalidate()
        timer = nil

        print("📋 Clipboard monitor stopped.")
    }

    // MARK: - Clipboard Check

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        // Nothing changed on the system pasteboard.
        guard currentChangeCount != lastChangeCount else {
            return
        }

        lock.lock()
        // Check if this change was triggered programmatically by our app
        if currentChangeCount == ignoredChangeCount || (ignoredContent != nil && pasteboard.string(forType: .string) == ignoredContent) {
            lastChangeCount = currentChangeCount
            ignoredChangeCount = -1
            ignoredContent = nil
            lock.unlock()
            print("📋 Ignored programmatic clipboard change.")
            return
        }
        lock.unlock()

        lastChangeCount = currentChangeCount

        // Read clipboard text safely - ignores unsupported non-text types
        guard let text = pasteboard.string(forType: .string) else {
            return
        }

        // Ignore empty content and whitespace-only strings safely
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let now = Date()

        // Ignore the exact same text if detected within 1.2s (system/event bounce)
        if text == lastCapturedText && now.timeIntervalSince(lastCapturedTime) < 1.2 {
            print("📋 Rapid duplicate clipboard event ignored (< 1.2s bounce).")
            return
        }

        lastCapturedText = text
        lastCapturedTime = now

        // Technical logging only - never log actual user clipboard content
        print("📋 Captured new clipboard text (\(text.count) characters).")

        lock.lock()
        let handler = onNewClipboardText
        lock.unlock()

        handler?(text)
    }
}
