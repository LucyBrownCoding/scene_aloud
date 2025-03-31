import SwiftUI
import AVKit

struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: CustomVideoPlayer
        init(_ parent: CustomVideoPlayer) {
            self.parent = parent
        }
        
        override func observeValue(forKeyPath keyPath: String?,
                                   of object: Any?,
                                   change: [NSKeyValueChangeKey : Any]?,
                                   context: UnsafeMutableRawPointer?) {
            if keyPath == "readyForDisplay",
               let controller = object as? AVPlayerViewController,
               controller.isReadyForDisplay {
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.3) {
                        controller.view.alpha = 1.0
                    }
                }
            }
        }
    }
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        
        // Initially hide the video view.
        controller.view.alpha = 0
        
        // Observe the readyForDisplay property so we can fade in the video when ready.
        controller.addObserver(context.coordinator,
                               forKeyPath: "readyForDisplay",
                               options: [.new, .initial],
                               context: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
