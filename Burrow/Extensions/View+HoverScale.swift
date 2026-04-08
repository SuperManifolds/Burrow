import SwiftUI

extension View {
    /// Adds a subtle scale effect on hover for interactive elements.
    func hoverScale(_ scale: CGFloat = 1.02) -> some View {
        modifier(HoverScaleModifier(hoverScale: scale))
    }
}

private struct HoverScaleModifier: ViewModifier {
    let hoverScale: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? hoverScale : 1.0)
            .animation(.spring(duration: 0.2), value: isHovered)
            .onHover { isHovered = $0 }
    }
}
