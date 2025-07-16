import UIKit

/// A protocol defining the responsibilities of a tracker.
/// This allows for dependency injection, so we can use a real tracker in production
/// and a mock tracker in our tests.
@MainActor
public protocol NFOTracking {
    func registerOrUpdate(id: UUID, frame: CGRect, place: NFOPlace, isVisible: Bool)
    func unregister(id: UUID)
}
