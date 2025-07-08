import SwiftUI

/// A ViewModifier that automatically tracks a SwiftUI View's geometry and reports it to the `NFOTracker`.
fileprivate struct NFOTrackingModifier: ViewModifier {

    @State private var viewId = UUID()
    let place: NFOPlace

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { updateFrame(geometry: geometry) }
                        .onChange(of: geometry.frame(in: .global)) { _ in
                            updateFrame(geometry: geometry)
                        }
                }
            )
            .onDisappear {
                NFOTracker.shared.unregister(id: viewId)
            }
    }

    private func updateFrame(geometry: GeometryProxy) {
        let globalFrame = geometry.frame(in: .global)
        NFOTracker.shared.registerOrUpdate(id: viewId, frame: globalFrame, place: place, isVisible: true)
    }
}

public extension View {
    /// Marks this SwiftUI View as a "NonFriendlyObstructor" (NFO) to be tracked.
    func trackAsNFO(place: NFOPlace) -> some View {
        self.modifier(NFOTrackingModifier(place: place))
    }
}
