import SwiftUI

struct SideMenuView: View {
    @Binding var showSheet: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Library") {
                    LibraryListView(closeSheet: { showSheet = false })
                }
            }
            .navigationTitle("Menu")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showSheet = false }
                }
            }
        }
    }
}


// MARK: - Library List ---------------------------------------------------

struct LibraryListView: View {
    @EnvironmentObject var library: LibraryManager
    @State private var expandedID: UUID? = nil   // tracks which row is open
    let closeSheet: () -> Void

    // Sort newest first
    private var sortedScripts: [SavedScript] {
        library.scripts.sorted { $0.dateSaved > $1.dateSaved }
    }

    var body: some View {
        List {
            ForEach(sortedScripts) { script in
                VStack(alignment: .leading, spacing: 6) {
                    // ── Row header ────────────────────────────────
                    HStack {
                        Image(systemName: expandedID == script.id ? "chevron.down" : "chevron.right")
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                withAnimation {
                                    expandedID = (expandedID == script.id) ? nil : script.id
                                }
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(script.title)
                                .font(.headline)
                            Text(script.settings.selectedCharacters.isEmpty
                                 ? "Just Listening"
                                 : script.settings.selectedCharacters.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            expandedID = (expandedID == script.id) ? nil : script.id
                        }
                    }

                    // ── Drop‑down details ─────────────────────────
                    if expandedID == script.id {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Display lines as read: \(script.settings.displayLinesAsRead ? "On" : "Off")")
                            Text("Display my lines: \(script.settings.displayMyLines ? "On" : "Off")")
                            Text("Progress: \(script.progressIndex + 1)/\(script.rawText.split(separator: "\n").count)")
                            HStack {
                                Spacer()
                                Button("Open Save") {
                                    library.select(script)
                                    closeSheet()
                                }
                                .padding(.top, 6)
                            }
                        }
                        .font(.caption)
                        .padding(.leading, 26) // indent under chevron
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: library.delete)
        }
        .navigationTitle("Library")
        .toolbar {
            EditButton()      // enables swipe-to-delete on iOS
        }
    }
}
