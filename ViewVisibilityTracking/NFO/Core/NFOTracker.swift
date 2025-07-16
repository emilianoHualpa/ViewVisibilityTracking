import Foundation
import Combine

/// A thread-safe singleton responsible for tracking all "NonFriendlyObstructors" (NFOs).
///
/// This pattern integrates seamlessly with Combine and avoids the complex actor-bridging issues.
@MainActor
public final class NFOTracker: ObservableObject, NFOTracking {

    /// The shared singleton instance for global access.
    public static let shared = NFOTracker()

    /// The dictionary of all currently tracked NFOs. The `@Published` wrapper
    /// automatically notifies subscribers of any changes.
    @Published public private(set) var obstructions: [UUID: NFOInfo] = [:]

    // Private initializer to enforce the singleton pattern.
    private init() {}

    /// Registers or updates a view's obstruction information.
    public func registerOrUpdate(id: UUID, frame: CGRect, place: NFOPlace, isVisible: Bool) {
        let info = NFOInfo(id: id, place: place, frame: frame, isVisible: isVisible)
        // This assignment is already protected by @MainActor and will trigger
        // the @Published property wrapper to send an update.
        obstructions[id] = info
    }

    /// Unregisters a view, removing it from the tracker.
    public func unregister(id: UUID) {
        _ = obstructions.removeValue(forKey: id)
    }

    /// Returns all tracked obstructions for a specific place.
    public func obstructions(in place: NFOPlace) -> [NFOInfo] {
        // Access is protected by @MainActor.
        return obstructions.values.filter { $0.place == place }
    }

    /// Finds all tracked obstructions in a specific place that intersect with a given frame.
    public func obstructions(in place: NFOPlace, thatIntersect frame: CGRect) -> [NFOInfo] {
        // Access is protected by @MainActor.
        return obstructions.values.filter { $0.place == place && $0.frame.intersects(frame) }
    }

    /// A helper method for tests to reset the state of the singleton.
    func reset() {
        obstructions = [:]
    }
}
