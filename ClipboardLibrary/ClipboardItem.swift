import Foundation
import SwiftData

@Model
final class ClipboardItem {

    var id: UUID
    var content: String
    var createdAt: Date
    var sourceApplication: String?
    var isFavorite: Bool
    var shortcut: String?
    var isInHistory: Bool?

    init(
        content: String,
        sourceApplication: String? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.createdAt = Date()
        self.sourceApplication = sourceApplication
        self.isFavorite = false
        self.shortcut = nil
        self.isInHistory = true
    }
}

