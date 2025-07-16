import Foundation
import Combine

/// A thread-safe singleton responsible for tracking all "NonFriendlyObstructors" (NFOs).
///
/// This pattern integrates seamlessly with Combine and avoids the complex actor-bridging issues.
@MainActor
public final class NFOTracker: ObservableObject {

    /// The shared singleton instance for global access.
    public static let shared = NFOTracker()

    // A lock to ensure that all access to the `obstructions` dictionary is thread-safe.
    private let lock = NSLock()

    /// The dictionary of all currently tracked NFOs. The `@Published` wrapper
    /// automatically notifies subscribers like `NFOVisibilityMonitor` of any changes.
    @Published public private(set) var obstructions: [UUID: NFOInfo] = [:]

    // Private initializer to enforce the singleton pattern.
    private init() {}

    /// Registers or updates a view's obstruction information.
    func registerOrUpdate(id: UUID, frame: CGRect, place: NFOPlace, isVisible: Bool) {
        lock.lock()
        defer { lock.unlock() }
        let info = NFOInfo(id: id, place: place, frame: frame, isVisible: isVisible)
        // This assignment will trigger the @Published property wrapper to send an update.
        obstructions[id] = info
    }

    /// Unregisters a view, removing it from the tracker.
    func unregister(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        if obstructions.removeValue(forKey: id) != nil {
            // The change to the dictionary automatically publishes the update.
        }
    }

    /// Returns all tracked obstructions for a specific place.
    public func obstructions(in place: NFOPlace) -> [NFOInfo] {
        lock.lock()
        defer { lock.unlock() }
        return obstructions.values.filter { $0.place == place }
    }

    /// Finds all tracked obstructions in a specific place that intersect with a given frame.
    public func obstructions(in place: NFOPlace, thatIntersect frame: CGRect) -> [NFOInfo] {
        lock.lock()
        defer { lock.unlock() }
        return obstructions.values.filter { $0.place == place && $0.frame.intersects(frame) }
    }
}
