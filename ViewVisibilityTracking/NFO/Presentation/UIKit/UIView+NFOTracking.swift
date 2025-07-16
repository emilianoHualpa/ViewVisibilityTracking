import UIKit
import Combine

@MainActor private var nfoHelperKey: UInt8 = 0

@MainActor
final class NFOUIKitLifecycleHelper {
    internal let viewId = UUID()
    private weak var trackedView: UIView?
    private let place: NFOPlace
    private let tracker: NFOTracking // Injected dependency
    private var lastKnownFrame: CGRect?
    private var lastKnownVisibility: Bool?
    private var updateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(view: UIView, place: NFOPlace, tracker: NFOTracking) {
        self.trackedView = view
        self.place = place
        self.tracker = tracker // Store the injected tracker
        startObserving()
    }

    deinit {
        DispatchQueue.main.async { [weak self] in
            self?.stopTracking()
        }
    }

    private func startObserving() {
        guard let view = trackedView else {
            return
        }

        let boundsPublisher = view.layer.publisher(for: \.bounds).map { _ in () }.eraseToAnyPublisher()
        let centerPublisher = view.publisher(for: \.center).map { _ in () }.eraseToAnyPublisher()
        let alphaPublisher = view.publisher(for: \.alpha).map { _ in () }.eraseToAnyPublisher()
        let isHiddenPublisher = view.publisher(for: \.isHidden).map { _ in () }.eraseToAnyPublisher()
        let windowPublisher = view.publisher(for: \.window).map { _ in () }.eraseToAnyPublisher()
        let transformPublisher = view.publisher(for: \.transform).map { _ in () }.eraseToAnyPublisher()

        Publishers.MergeMany(
            boundsPublisher,
            centerPublisher,
            alphaPublisher,
            isHiddenPublisher,
            windowPublisher,
            transformPublisher
        )
        .debounce(for: .milliseconds(16), scheduler: DispatchQueue.main)
        .sink { [weak self] in
            self?.scheduleUpdate()
        }
        .store(in: &cancellables)

        scheduleUpdate()
    }

    func scheduleUpdate() {
        updateTask?.cancel()
        // Capture self weakly to prevent a retain cycle.
        updateTask = Task { [weak self] in
            do {
                // This delay is crucial. It allows the run loop to complete a layout pass
                // after a view is added to a window, ensuring properties like `view.window`
                // are correctly populated before the first visibility check.
                try await Task.sleep(nanoseconds: 16_000_000)
                guard let self = self, !Task.isCancelled else {
                    return
                }
                self.updateFrameAndVisibility()
            } catch {}
        }
    }

    private func updateFrameAndVisibility() {
        guard let view = trackedView, let window = view.window else {
            // View is off-screen. Unregister if we were previously registered.
            unregisterIfNeeded()
            return
        }

        guard view.bounds != .zero else {
            return
        }

        let globalFrame = view.convert(view.bounds, to: window)
        let isVisible = !view.isHidden && view.alpha > 0.0

        if lastKnownFrame == globalFrame && lastKnownVisibility == isVisible {
            return
        }

        self.lastKnownFrame = globalFrame
        self.lastKnownVisibility = isVisible
        tracker.registerOrUpdate(id: viewId, frame: globalFrame, place: place, isVisible: isVisible)
    }

    /// The single entry point for explicitly stopping tracking.
    func stopTracking() {
        updateTask?.cancel()
        cancellables.removeAll()
        unregisterIfNeeded()
    }

    /// A unified, idempotent method for unregistering from the tracker.
    private func unregisterIfNeeded() {
        // This check makes the unregister operation idempotent, preventing
        // duplicate events from race conditions between KVO and deinit.
        guard lastKnownFrame != nil else {
            return
        }

        tracker.unregister(id: viewId)
        lastKnownFrame = nil
        lastKnownVisibility = nil
    }
}

public extension UIView {
    @MainActor internal var nfoHelper: NFOUIKitLifecycleHelper? {
        objc_getAssociatedObject(self, &nfoHelperKey) as? NFOUIKitLifecycleHelper
    }

    @MainActor
    func trackAsNFO(place: NFOPlace) {
        self.trackAsNFO(place: place, tracker: NFOTracker.shared)
    }

    @MainActor
    func stopTrackingNFO() {
        if let helper = nfoHelper {
            helper.stopTracking()
            objc_setAssociatedObject(self, &nfoHelperKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension UIView {
    @MainActor
    func trackAsNFO(place: NFOPlace, tracker: NFOTracking) {
        if objc_getAssociatedObject(self, &nfoHelperKey) != nil {
            return
        }
        let helper = NFOUIKitLifecycleHelper(view: self, place: place, tracker: tracker)
        objc_setAssociatedObject(self, &nfoHelperKey, helper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
