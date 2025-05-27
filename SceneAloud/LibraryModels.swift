import Foundation

struct ScriptSettings: Codable, Equatable {
    var selectedCharacters: [String]
    var displayLinesAsRead: Bool
    var displayMyLines: Bool
}

struct SavedScript: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String          // “scene1.txt” or “Typed Script”
    var rawText: String        // full script text
    var settings: ScriptSettings
    var progressIndex: Int     // user’s last line index
    var dateSaved: Date
}
