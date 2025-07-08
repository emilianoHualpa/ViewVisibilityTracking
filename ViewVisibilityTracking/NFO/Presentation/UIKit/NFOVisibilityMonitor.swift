import Foundation
import Combine

/// An observer class that uses Combine to monitor the NFOTracker for any changes.
///
/// Create an instance of this in your UIViewController to be notified whenever the
/// set of obstructions changes, allowing you to re-calculate visibility in real-time.
public class NFOVisibilityMonitor {
    private var cancellable: AnyCancellable?

    /// Initializes the monitor and starts listening for updates from the `NFOTracker`.
    /// - Parameter onUpdate: A closure that will be called on the main thread whenever
    ///   the list of obstructions is updated.
    public init(onUpdate: @escaping () -> Void) {
        // This subscription is now simple and safe.
        cancellable = NFOTracker.shared.$obstructions
            .receive(on: DispatchQueue.main)
            .sink { _ in
                onUpdate()
            }
    }
}
