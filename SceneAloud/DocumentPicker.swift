import SwiftUI
import UIKit

struct DocumentPicker: UIViewControllerRepresentable {
    
    @Binding var filePath: URL?
    var allowedUTIs: [String] = ["public.text"] // Allows only plain text files
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Initialize with older initializer using UTIs
        let picker = UIDocumentPickerViewController(documentTypes: allowedUTIs, in: .import)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No update needed
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Handle the selected file
            guard let selectedURL = urls.first else { return }
            parent.filePath = selectedURL
            print("Selected file: \(selectedURL.absoluteString)")
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Handle cancellation if needed
            print("Document picker was cancelled")
        }
    }
}
