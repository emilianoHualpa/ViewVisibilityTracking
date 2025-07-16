import UIKit

/// An internal, reusable helper class that encapsulates the logic for polling a view's state.
///
/// This observer uses a `CADisplayLink` to efficiently check for changes in a view's
/// state, such as whether a view controller presented on top of it has been dismissed.
/// It's designed to be owned by a `UIView` and automatically start/stop based on the
/// view's presence in a window.
public final class ViewPresentedOnTopStateObserver {

    // A weak reference to the view being observed to avoid retain cycles.
    private weak var observedView: UIView?

    // The `CADisplayLink` used for polling. It's an optional because it's only active
    // when the observed view is in a window.
    private var pollTimer: CADisplayLink?

    // The previous state, used to detect changes.
    private var wasPresentedOnTop = false

    /// The callback to execute when the desired state change (dismissal) is detected.
    private let onDismissalDetected: () -> Void

    /// Initializes the observer.
    /// - Parameters:
    ///   - view: The `UIView` whose state will be polled.
    ///   - onDismissalDetected: The closure to run when a dismissal is detected.
    public init(observing view: UIView, onDismissalDetected: @escaping () -> Void) {
        self.observedView = view
        self.onDismissalDetected = onDismissalDetected
        // The observer starts itself automatically when the view is added to a window.
        // No need to call start/stop manually.
    }

    /// Starts the polling timer. This should be called when the observed view is added to a window.
    @MainActor
    func start() {
        // Invalidate any existing timer to be safe.
        stop()

        guard let view = observedView else { return }

        // Set the initial state before starting.
        wasPresentedOnTop = view.isViewControllerPresentedOnTop

        // Create a new timer that calls our check function.
        pollTimer = CADisplayLink(target: self, selector: #selector(pollForStateChange))

        // We don't need to check 60 times per second. 15 is more than enough
        // to catch a dismissal instantly from a user's perspective.
        pollTimer?.preferredFramesPerSecond = 15
        pollTimer?.add(to: .main, forMode: .common)
    }

    /// Stops and invalidates the polling timer. This should be called when the view is removed from a window.
    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// The function called by the `CADisplayLink` on each frame.
    @MainActor
    @objc private func pollForStateChange() {
        guard let view = observedView else {
            // If the view is gone, stop the timer.
            stop()
            return
        }

        let isCurrentlyPresentedOnTop = view.isViewControllerPresentedOnTop

        // We are looking for one specific change: the state flipping from TRUE to FALSE.
        if wasPresentedOnTop && !isCurrentlyPresentedOnTop {
            print("✅ Dismissal Detected via Polling: Executing callback.")
            // Execute the callback provided at initialization.
            onDismissalDetected()
        }

        // Update the state for the next frame's check.
        wasPresentedOnTop = isCurrentlyPresentedOnTop
    }
}
