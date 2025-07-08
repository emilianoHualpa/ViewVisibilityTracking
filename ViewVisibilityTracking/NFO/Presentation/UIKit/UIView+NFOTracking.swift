import UIKit

/// A helper class that observes a UIView's lifecycle and frame changes to report to the NFOTracker.
/// This object is automatically associated with the UIView being tracked.
final class NFOUIKitLifecycleHelper: NSObject {
    private let viewId = UUID()
    private weak var trackedView: UIView?
    private let place: NFOPlace
    private var lastKnownFrame: CGRect?
    private var lastKnownVisibility: Bool?
    private var updateWorkItem: DispatchWorkItem?

    // KVO Observers
    private var isHiddenObserver: NSKeyValueObservation?
    private var alphaObserver: NSKeyValueObservation?

    init(view: UIView, place: NFOPlace) {
        self.trackedView = view
        self.place = place
        super.init()

        isHiddenObserver = view.observe(\.isHidden, options: [.new, .initial]) { [weak self] _, _ in
            self?.scheduleUpdate()
        }
        alphaObserver = view.observe(\.alpha, options: [.new, .initial]) { [weak self] _, _ in
            self?.scheduleUpdate()
        }
    }

    /// Called by our swizzled methods to trigger a debounced update.
    func scheduleUpdate() {
        updateWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.updateFrame()
        }
        self.updateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016, execute: workItem)
    }

    private func updateFrame() {
        guard let view = trackedView, view.window != nil else { return }
        guard view.bounds != .zero else { return }

        let globalFrame = view.convert(view.bounds, to: nil)
        let isVisible = !view.isHidden && view.alpha > 0.0

        if let lastFrame = lastKnownFrame,
           let lastVisibility = lastKnownVisibility,
           lastFrame == globalFrame && lastVisibility == isVisible {
            return
        }

        self.lastKnownFrame = globalFrame
        self.lastKnownVisibility = isVisible

        NFOTracker.shared.registerOrUpdate(id: viewId, frame: globalFrame, place: place, isVisible: isVisible)
    }

    func stopTracking() {
        updateWorkItem?.cancel()
        isHiddenObserver?.invalidate()
        alphaObserver?.invalidate()
        NFOTracker.shared.unregister(id: viewId)
    }

    deinit {
        stopTracking()
    }
}

// A private key for associating the helper object with a UIView.
private var nfoHelperKey: UInt8 = 0

public extension UIView {
    /// Marks this UIView as a "NonFriendlyObstructor" (NFO) to be tracked.
    func trackAsNFO(place: NFOPlace) {
        if objc_getAssociatedObject(self, &nfoHelperKey) != nil {
            return
        }
        let helper = NFOUIKitLifecycleHelper(view: self, place: place)
        objc_setAssociatedObject(self, &nfoHelperKey, helper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Explicitly stops tracking this view as an NFO.
    func stopTrackingNFO() {
        if let helper = objc_getAssociatedObject(self, &nfoHelperKey) as? NFOUIKitLifecycleHelper {
            helper.stopTracking()
            objc_setAssociatedObject(self, &nfoHelperKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

/* WITH SWIZZLING -> Not needed for now

import UIKit
import Combine

// This file contains the core UIKit tracking logic.

// A private key for associating the helper object with a UIView.
private var nfoHelperKey: UInt8 = 0

/// A helper class that observes a UIView's lifecycle and frame changes to report to the NFOTracker.
/// This object is automatically associated with the UIView being tracked.
fileprivate class NFOUIKitLifecycleHelper: NSObject {
    private let viewId = UUID()
    private weak var trackedView: UIView?
    private let place: NFOPlace
    private var lastKnownFrame: CGRect?
    private var lastKnownVisibility: Bool?
    private var updateWorkItem: DispatchWorkItem?

    // KVO Observers
    private var isHiddenObserver: NSKeyValueObservation?
    private var alphaObserver: NSKeyValueObservation?

    init(view: UIView, place: NFOPlace) {
        self.trackedView = view
        self.place = place
        super.init()

        isHiddenObserver = view.observe(\.isHidden, options: [.new, .initial]) { [weak self] _, _ in
            self?.scheduleUpdate()
        }
        alphaObserver = view.observe(\.alpha, options: [.new, .initial]) { [weak self] _, _ in
            self?.scheduleUpdate()
        }
    }

    /// Called by our swizzled methods to trigger a debounced update.
    func scheduleUpdate() {
        // Cancel any pending update to debounce frequent calls.
        updateWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.updateFrame()
        }
        self.updateWorkItem = workItem
        // A small delay allows the runloop to complete an animation/layout pass.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016, execute: workItem)
    }

    private func updateFrame() {
        guard let view = trackedView, view.window != nil else { return }
        guard view.bounds != .zero else { return }

        let globalFrame = view.convert(view.bounds, to: nil)
        let isVisible = !view.isHidden && view.alpha > 0.0

        if let lastFrame = lastKnownFrame,
           let lastVisibility = lastKnownVisibility,
           lastFrame == globalFrame && lastVisibility == isVisible {
            return // No change, no update needed.
        }

        self.lastKnownFrame = globalFrame
        self.lastKnownVisibility = isVisible

        NFOTracker.shared.registerOrUpdate(id: viewId, frame: globalFrame, place: place, isVisible: isVisible)
    }

    func stopTracking() {
        updateWorkItem?.cancel()
        isHiddenObserver?.invalidate()
        alphaObserver?.invalidate()
        NFOTracker.shared.unregister(id: viewId)
    }

    deinit {
        stopTracking()
    }
}


public extension UIView {
    /// Call this once at app startup (e.g., in AppDelegate) to enable tracking.
    static func prepareNFOTracking() {
        _ = swizzleDidMoveToWindow
        _ = swizzleLayoutSubviews
    }

    // Swizzle for didMoveToWindow
    private static let swizzleDidMoveToWindow: Void = {
        let originalSelector = #selector(didMoveToWindow)
        let swizzledSelector = #selector(nfo_swizzled_didMoveToWindow)
        guard let originalMethod = class_getInstanceMethod(UIView.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIView.self, swizzledSelector) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    @objc private func nfo_swizzled_didMoveToWindow() {
        // Call the original implementation first.
        self.nfo_swizzled_didMoveToWindow()
        // Then call our custom logic.
        if let helper = objc_getAssociatedObject(self, &nfoHelperKey) as? NFOUIKitLifecycleHelper {
            helper.scheduleUpdate()
        }
    }

    // Swizzle for layoutSubviews
    private static let swizzleLayoutSubviews: Void = {
        let originalSelector = #selector(layoutSubviews)
        let swizzledSelector = #selector(nfo_swizzled_layoutSubviews)
        guard let originalMethod = class_getInstanceMethod(UIView.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIView.self, swizzledSelector) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    @objc private func nfo_swizzled_layoutSubviews() {
        // Call the original implementation first.
        self.nfo_swizzled_layoutSubviews()
        // Then call our custom logic.
        if let helper = objc_getAssociatedObject(self, &nfoHelperKey) as? NFOUIKitLifecycleHelper {
            helper.scheduleUpdate()
        }
    }

    /// Marks this UIView as a "NonFriendlyObstructor" (NFO) to be tracked.
    func trackAsNFO(place: NFOPlace) {
        if objc_getAssociatedObject(self, &nfoHelperKey) != nil {
            return
        }
        let helper = NFOUIKitLifecycleHelper(view: self, place: place)
        objc_setAssociatedObject(self, &nfoHelperKey, helper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Explicitly stops tracking this view as an NFO.
    func stopTrackingNFO() {
        if let helper = objc_getAssociatedObject(self, &nfoHelperKey) as? NFOUIKitLifecycleHelper {
            helper.stopTracking()
            objc_setAssociatedObject(self, &nfoHelperKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
 */
