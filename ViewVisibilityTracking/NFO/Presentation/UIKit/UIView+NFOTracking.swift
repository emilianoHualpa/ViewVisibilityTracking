import UIKit
import Combine

// This file contains the core UIKit tracking logic, updated for Swift 6 concurrency.

// A private key for associating the helper object with a UIView.
@MainActor private var nfoHelperKey: UInt8 = 0

/// A helper class that observes a UIView's lifecycle and frame changes to report to the NFOTracker.
/// This object is automatically associated with the UIView being tracked.
@MainActor
private final class NFOUIKitLifecycleHelper {
    private let viewId = UUID()
    private weak var trackedView: UIView?
    private let place: NFOPlace
    private var lastKnownFrame: CGRect?
    private var lastKnownVisibility: Bool?

    // This Task handles the debounced update, replacing DispatchWorkItem.
    private var updateTask: Task<Void, Never>?

    // A set to store all Combine subscriptions, ensuring they are cancelled on deinit.
    private var cancellables = Set<AnyCancellable>()

    init(view: UIView, place: NFOPlace) {
        self.trackedView = view
        self.place = place
        // No need to call super.init() when not subclassing a specific NSObject method.

        // Start observing when the helper is initialized.
        startObserving()
    }

    /// Sets up Combine publishers to listen for any property changes that could affect the view's final frame or visibility.
    private func startObserving() {
        guard let view = trackedView else { return }

        // Each publisher is mapped to a Void output and then type-erased.
        let boundsPublisher = view.layer.publisher(for: \.bounds).map { _ in () }.eraseToAnyPublisher()
        let centerPublisher = view.publisher(for: \.center).map { _ in () }.eraseToAnyPublisher()
        let alphaPublisher = view.publisher(for: \.alpha).map { _ in () }.eraseToAnyPublisher()
        let isHiddenPublisher = view.publisher(for: \.isHidden).map { _ in () }.eraseToAnyPublisher()
        let windowPublisher = view.publisher(for: \.window).map { _ in () }.eraseToAnyPublisher()

        // Merge all publishers into a single stream.
        Publishers.MergeMany(
            boundsPublisher,
            centerPublisher,
            alphaPublisher,
            isHiddenPublisher,
            windowPublisher
        )
        .debounce(for: .milliseconds(16), scheduler: DispatchQueue.main) // Debounce remains the same.
        .sink { [weak self] in
            // Because this class is @MainActor isolated, this closure is safe.
            self?.scheduleUpdate()
        }
        .store(in: &cancellables)

        // Perform an initial update right away.
        scheduleUpdate()
    }

    /// Schedules a debounced update to check the view's frame and visibility using modern concurrency.
    func scheduleUpdate() {
        // Cancel any pending update to debounce frequent calls.
        updateTask?.cancel()

        updateTask = Task {
            do {
                // A small delay allows the runloop to complete an animation/layout pass.
                try await Task.sleep(nanoseconds: 16_000_000)
                self.updateFrameAndVisibility()
            } catch {
                // This will be a CancellationError if the task was cancelled.
                // No action needed, the update was successfully debounced.
            }
        }
    }

    /// Calculates the view's frame in screen coordinates and its visibility,
    /// and reports it to the tracker if there's a change.
    private func updateFrameAndVisibility() {
        // Ensure the view is still alive and on screen.
        guard let view = trackedView, view.window != nil else {
            // If the view is off-screen, ensure it's unregistered.
            if lastKnownFrame != nil {
                NFOTracker.shared.unregister(id: viewId)
                lastKnownFrame = nil
                lastKnownVisibility = nil
            }
            return
        }

        // Ignore views with a zero-size frame, as they are not visible.
        guard view.bounds != .zero else {
            return
        }

        // Convert the view's bounds to the screen's coordinate space.
        let globalFrame = view.convert(view.bounds, to: nil)
        let isVisible = !view.isHidden && view.alpha > 0.0

        // Check if the frame or visibility has actually changed since the last update.
        if let lastFrame = lastKnownFrame,
           let lastVisibility = lastKnownVisibility,
           lastFrame == globalFrame && lastVisibility == isVisible {
            return // No change, no update needed.
        }

        // Store the new state.
        self.lastKnownFrame = globalFrame
        self.lastKnownVisibility = isVisible

        // Register the update with the central tracker.
        NFOTracker.shared.registerOrUpdate(id: viewId, frame: globalFrame, place: place, isVisible: isVisible)
    }

    /// Stops all observations and tracking activities.
    func stopTracking() {
        updateTask?.cancel()
        cancellables.removeAll()
        NFOTracker.shared.unregister(id: viewId)
    }

    deinit {
        DispatchQueue.main.async { [weak self] in
            self?.stopTracking()
            print("✅ NFOUIKitLifecycleHelper deinitialized.")
        }
    }
}


public extension UIView {
    /// Marks this UIView as a "NonFriendlyObstructor" (NFO) to be tracked.
    /// This method is now the single point of entry for UIKit views.
    /// - Parameter place: An identifier for the logical placement of this view.
    func trackAsNFO(place: NFOPlace) {
        // If a helper already exists, do nothing.
        if objc_getAssociatedObject(self, &nfoHelperKey) != nil {
            return
        }

        // Create the helper and associate it with the view.
        // The helper's `init` method will automatically start the observation.
        let helper = NFOUIKitLifecycleHelper(view: self, place: place)
        objc_setAssociatedObject(self, &nfoHelperKey, helper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Explicitly stops tracking this view as an NFO.
    func stopTrackingNFO() {
        if let helper = objc_getAssociatedObject(self, &nfoHelperKey) as? NFOUIKitLifecycleHelper {
            // Since the helper is a MainActor, we must call its methods from an async context.
            Task { @MainActor in
                helper.stopTracking()
                objc_setAssociatedObject(self, &nfoHelperKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
}
