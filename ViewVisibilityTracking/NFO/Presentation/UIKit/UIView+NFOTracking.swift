import UIKit
import Combine

// This file contains the core UIKit tracking logic.

// A private key for associating the helper object with a UIView.
private var nfoHelperKey: UInt8 = 0

/// A helper class that observes a UIView's lifecycle and frame changes to report to the NFOTracker.
/// This object is automatically associated with the UIView being tracked.
private final class NFOUIKitLifecycleHelper: NSObject {
    private let viewId = UUID()
    private weak var trackedView: UIView?
    private let place: NFOPlace
    private var lastKnownFrame: CGRect?
    private var lastKnownVisibility: Bool?
    private var updateWorkItem: DispatchWorkItem?

    // A set to store all Combine subscriptions, ensuring they are cancelled on deinit.
    private var cancellables = Set<AnyCancellable>()

    init(view: UIView, place: NFOPlace) {
        self.trackedView = view
        self.place = place
        super.init()

        // Start observing when the helper is initialized.
        startObserving()
    }

    /// Sets up Combine publishers to listen for any property changes that could affect the view's final frame or visibility.
    private func startObserving() {
        guard let view = trackedView else { return }

        // We observe multiple properties that can affect layout or visibility.
        // Each publisher is mapped to a Void output and then type-erased to AnyPublisher<Void, Never>
        // so they can be merged together.

        let boundsPublisher = view.layer.publisher(for: \.bounds)
            .map{ _ in () }
            .eraseToAnyPublisher()

        let centerPublisher = view.publisher(for: \.center)
            .map { _ in () }
            .eraseToAnyPublisher()

        let alphaPublisher = view.publisher(for: \.alpha)
            .map { _ in () }
            .eraseToAnyPublisher()

        let isHiddenPublisher = view.publisher(for: \.isHidden)
            .map { _ in () }
            .eraseToAnyPublisher()

        let windowPublisher = view.publisher(for: \.window)
            .map { _ in () }
            .eraseToAnyPublisher()

        // Merge all publishers into a single stream.
        // Any time one of these properties changes, the merged publisher will emit a value.
        Publishers.MergeMany(
            boundsPublisher,
            centerPublisher,
            alphaPublisher,
            isHiddenPublisher,
            windowPublisher
        )
        .debounce(for: .milliseconds(16), scheduler: DispatchQueue.main) // Debounce to avoid excessive updates during animations.
        .sink { [weak self] in
            self?.scheduleUpdate()
        }
        .store(in: &cancellables)

        // Perform an initial update right away.
        scheduleUpdate()
    }

    /// Schedules a debounced update to check the view's frame and visibility.
    func scheduleUpdate() {
        // Cancel any pending update to debounce frequent calls.
        updateWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.updateFrameAndVisibility()
        }
        self.updateWorkItem = workItem
        // Execute on the next runloop turn to ensure layout is complete.
        DispatchQueue.main.async(execute: workItem)
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
        updateWorkItem?.cancel()
        cancellables.removeAll() // This cancels all active Combine subscriptions.
         NFOTracker.shared.unregister(id: viewId)
    }

    deinit {
        stopTracking()
        print("✅ NFOUIKitLifecycleHelper for view \(viewId) deinitialized.")
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
            helper.stopTracking()
            // Remove the associated object to allow for re-tracking later if needed.
            objc_setAssociatedObject(self, &nfoHelperKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
