//import SwiftUI
//
///// Wraps any view with a top-right hamburger button.
///// When tapped, toggles `showSideMenu`.
//struct HamburgerOverlay<Content: View>: View {
//    @Binding var showSideMenu: Bool
//    let content: Content
//
//    init(showSideMenu: Binding<Bool>, @ViewBuilder content: () -> Content) {
//        _showSideMenu = showSideMenu
//        self.content = content()
//    }
//
//    var body: some View {
//        ZStack(alignment: .topTrailing) {
//            content
//
//            Button {
//                withAnimation { showSideMenu.toggle() }
//            } label: {
//                Image(systemName: "line.3.horizontal")
//                    .font(.title2)
//                    .foregroundColor(.primary)
//                    .padding(12)
//                    .background(Color(UIColor.systemBackground).opacity(0.9))
//                    .clipShape(Circle())
//                    .contentShape(Rectangle())
//            }
//            .padding(.top, 60) // Position below the status bar but above navigation title
//            .padding(.trailing, 16)
//            .zIndex(1000)
//            .accessibilityLabel("Main menu")
//        }
//        .ignoresSafeArea(.container, edges: .top) // Allow positioning in the top safe area
//    }
//}
