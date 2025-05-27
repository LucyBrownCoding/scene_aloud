import SwiftUI

/// Wraps any view with a top-right hamburger button.
/// When tapped, toggles `showSideMenu`.
struct HamburgerOverlay<Content: View>: View {
    @Binding var showSideMenu: Bool
    let content: Content

    init(showSideMenu: Binding<Bool>, @ViewBuilder content: () -> Content) {
        _showSideMenu = showSideMenu
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content

            Button {
                withAnimation { showSideMenu.toggle() }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .padding(12)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Main menu")
        }
    }
}
