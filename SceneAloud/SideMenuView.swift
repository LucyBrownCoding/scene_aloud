import SwiftUI

struct SideMenuView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Library") {
                    LibraryListView()
                }
            }
            .navigationTitle("Menu")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}


// MARK: - Library List ---------------------------------------------------

struct LibraryListView: View {
    @EnvironmentObject var library: LibraryManager
    @Environment(\.dismiss) private var dismiss

    // Sort newest first
    private var sortedScripts: [SavedScript] {
        library.scripts.sorted { $0.dateSaved > $1.dateSaved }
    }

    var body: some View {
        List {
            ForEach(sortedScripts) { script in
                Button {
                    library.select(script) 
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(script.title)
                                .font(.headline)
                            Text(script.dateSaved, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        // Simple progress indicator
                        Text("\(script.progressIndex + 1)/\(script.rawText.split(separator: "\n").count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: library.delete)
        }
        .navigationTitle("Library")
        .toolbar {
            EditButton()      // enables swipe-to-delete on iOS
        }
    }
}
