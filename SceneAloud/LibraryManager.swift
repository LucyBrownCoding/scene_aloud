import Foundation
import Combine

/// Keeps an in-memory list of saved scripts and persists them to a JSON file.
final class LibraryManager: ObservableObject {
    /// Current cache of saved scripts (sorted is up to the UI)
    @Published private(set) var scripts: [SavedScript] = []
    @Published var selectedScript: SavedScript? = nil

    // Location of library.json in the Documents folder
    private let saveURL: URL

    // MARK: - Init / Load ---------------------------------------------------

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask).first!
        saveURL = docs.appendingPathComponent("library.json")
        loadFromDisk()
    }

    // MARK: - CRUD ----------------------------------------------------------

    func add(_ script: SavedScript) {
        scripts.append(script)
        persist()
    }

    func update(_ script: SavedScript) {
        guard let idx = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[idx] = script
        persist()
    }

    func delete(at offsets: IndexSet) {
        scripts.remove(atOffsets: offsets)
        persist()
    }
    
    // MARK: - Selection
    func select(_ script: SavedScript) {
        selectedScript = script
    }

    // MARK: - Persistence helpers ------------------------------------------

    private func persist() {
        do {
            let data = try JSONEncoder().encode(scripts)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            print("❌ Error saving library:", error)
        }
    }

    private func loadFromDisk() {
        guard
            let data = try? Data(contentsOf: saveURL),
            let decoded = try? JSONDecoder().decode([SavedScript].self, from: data)
        else { return }
        scripts = decoded
    }
}

