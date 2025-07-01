import Foundation

struct ScriptSettings: Codable, Equatable {
    var selectedCharacters: [String]
    var displayLinesAsRead: Bool
    var displayMyLines: Bool
    var showHints: Bool
    var startingLineIndex: Int
    var characterOptions: [String: CharacterOptions]  // Add this new field
    
    // Add initializer to handle backwards compatibility
    init(selectedCharacters: [String], displayLinesAsRead: Bool, displayMyLines: Bool, showHints: Bool = true, startingLineIndex: Int = 0, characterOptions: [String: CharacterOptions] = [:]) {
        self.selectedCharacters = selectedCharacters
        self.displayLinesAsRead = displayLinesAsRead
        self.displayMyLines = displayMyLines
        self.showHints = showHints
        self.startingLineIndex = startingLineIndex
        self.characterOptions = characterOptions
    }
    
    // Custom decoder to handle old saved scripts that don't have new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedCharacters = try container.decode([String].self, forKey: .selectedCharacters)
        displayLinesAsRead = try container.decode(Bool.self, forKey: .displayLinesAsRead)
        displayMyLines = try container.decode(Bool.self, forKey: .displayMyLines)
        showHints = try container.decodeIfPresent(Bool.self, forKey: .showHints) ?? true
        startingLineIndex = try container.decodeIfPresent(Int.self, forKey: .startingLineIndex) ?? 0
        characterOptions = try container.decodeIfPresent([String: CharacterOptions].self, forKey: .characterOptions) ?? [:]
    }
}

struct SavedScript: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String          // “scene1.txt” or “Typed Script”
    var rawText: String        // full script text
    var settings: ScriptSettings
    var progressIndex: Int     // user’s last line index
    var dateSaved: Date
}
