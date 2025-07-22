import Foundation
import UIKit

@MainActor
public protocol ImpressionTracking {
    func trackRender(id: String)
    func updateVisibility(for view: UIView, id: String, percentage: CGFloat)
    func hasFiredViewImpression(for id: String) -> Bool
    func hasFiredRenderImpression(for id: String) -> Bool
    func visibilityForFiredImpression(for id: String) -> CGFloat?
}

/// A class that tracks two types of impressions for multiple items, conforming to the `ImpressionTracking` protocol.
/// 1. **Render Impression:** Fires once as soon as an item is about to be rendered.
/// 2. **Viewable Impression:** Fires once after an item meets the MRC standard (>= 50% of pixels visible for at least 1 continuous second).
@MainActor
public final class MRCImpressionTracker: ImpressionTracking {
    private let visibilityThreshold: CGFloat
    private let timeThreshold: TimeInterval
    private let onViewImpressionFired: (String) -> Void
    private let onRenderImpressionFired: (String) -> Void
    private let isObscuredCheck: @MainActor (UIView) async -> Bool

    private var timerTasks = [String: Task<Void, Error>]()
    private var firedViewImpressionIDs = Set<String>()
    private var firedRenderImpressionIDs = Set<String>()
    private var visibilityWhileTiming = [String: CGFloat]()
    private var firedImpressionVisibility = [String: CGFloat]()

    public init(
        visibilityThreshold: CGFloat = 0.5,
        timeThreshold: TimeInterval = 3.0,
        onViewImpressionFired: @escaping (String) -> Void,
        onRenderImpressionFired: @escaping (String) -> Void,
        isObscuredCheck: @escaping @MainActor (UIView) async -> Bool = { $0.isViewControllerPresentedOnTop }
    ) {
        self.visibilityThreshold = visibilityThreshold
        self.timeThreshold = timeThreshold
        self.onViewImpressionFired = onViewImpressionFired
        self.onRenderImpressionFired = onRenderImpressionFired
        self.isObscuredCheck = isObscuredCheck
    }

    public func trackRender(id: String) {
        guard !firedRenderImpressionIDs.contains(id) else { return }
        firedRenderImpressionIDs.insert(id)
        onRenderImpressionFired(id)
    }

    public func updateVisibility(for view: UIView, id: String, percentage: CGFloat) {
        guard !firedViewImpressionIDs.contains(id) else { return }
        if percentage >= visibilityThreshold {
            visibilityWhileTiming[id] = percentage
            startTimerIfNeeded(for: view, id: id)
        } else {
            cancelTimer(for: id)
        }
    }

    public func hasFiredViewImpression(for id: String) -> Bool {
        return firedViewImpressionIDs.contains(id)
    }

    public func hasFiredRenderImpression(for id: String) -> Bool {
        return firedRenderImpressionIDs.contains(id)
    }

    public func visibilityForFiredImpression(for id: String) -> CGFloat? {
        return firedImpressionVisibility[id]
    }

    public func reset() {
        timerTasks.values.forEach { $0.cancel() }
        timerTasks.removeAll()
        firedViewImpressionIDs.removeAll()
        firedRenderImpressionIDs.removeAll()
        visibilityWhileTiming.removeAll()
        firedImpressionVisibility.removeAll()
    }

    private func startTimerIfNeeded(for view: UIView, id: String) {
        guard timerTasks[id] == nil else { return }
        timerTasks[id] = Task {
            let nanoseconds = UInt64(timeThreshold * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)

            // The check now uses the injected closure, which can be a real check
            // in the app or a mock check in tests.
            if await isObscuredCheck(view) {
                print("❌ Impression for item \(id) aborted: A view controller was presented on top.")
                cancelTimer(for: id)
                return
            }

            firedViewImpressionIDs.insert(id)
            if let finalVisibility = visibilityWhileTiming[id] {
                firedImpressionVisibility[id] = finalVisibility
            }
            onViewImpressionFired(id)
            cancelTimer(for: id)
        }
    }

    private func cancelTimer(for id: String) {
        if let task = timerTasks[id] {
            task.cancel()
            timerTasks[id] = nil
            visibilityWhileTiming.removeValue(forKey: id)
        }
    }
}
