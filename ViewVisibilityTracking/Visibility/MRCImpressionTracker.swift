import Foundation

@MainActor
public protocol ImpressionTracking {
    /// Tracks a render impression for a given item ID.
    func trackRender(id: String)

    /// Updates the tracker with the latest visibility data to evaluate for a viewable impression.
    func updateVisibility(id: String, percentage: CGFloat)

    /// Checks if a viewable impression has already been fired for a given item ID.
    func hasFiredViewImpression(for id: String) -> Bool

    /// Checks if a render impression has already been fired for a given item ID.
    func hasFiredRenderImpression(for id: String) -> Bool

    /// Returns the visibility percentage at which a viewable impression was fired.
    func visibilityForFiredImpression(for id: String) -> CGFloat?
}

/// A class that tracks two types of impressions for multiple items, conforming to the `ImpressionTracking` protocol.
/// 1. **Render Impression:** Fires once as soon as an item is rendered.
/// 2. **Viewable Impression:** Fires once after an item meets the MRC standard
///    (e.g., 50% of pixels visible for at least 1 continuous second).
@MainActor
public final class MRCImpressionTracker: ImpressionTracking {

    // --- Configuration ---
    private let visibilityThreshold: CGFloat
    private let timeThreshold: TimeInterval

    // --- Callbacks ---
    private let onViewImpressionFired: (String) -> Void
    private let onRenderImpressionFired: (String) -> Void

    // --- State Management ---
    private var timerTasks = [String: Task<Void, Error>]()
    private var firedViewImpressionIDs = Set<String>()
    private var firedRenderImpressionIDs = Set<String>()

    /// Stores the most recent visibility percentage while the timer is running.
    private var visibilityWhileTiming = [String: CGFloat]()
    /// Stores the final visibility percentage after an impression has successfully fired.
    private var firedImpressionVisibility = [String: CGFloat]()

    /// Initializes the impression tracker.
    public init(
        visibilityThreshold: CGFloat = 0.5,
        timeThreshold: TimeInterval = 1.0,
        onViewImpressionFired: @escaping (String) -> Void,
        onRenderImpressionFired: @escaping (String) -> Void
    ) {
        self.visibilityThreshold = visibilityThreshold
        self.timeThreshold = timeThreshold
        self.onViewImpressionFired = onViewImpressionFired
        self.onRenderImpressionFired = onRenderImpressionFired
    }

    public func trackRender(id: String) {
        guard !firedRenderImpressionIDs.contains(id) else { return }
        firedRenderImpressionIDs.insert(id)
        print("🎨 Render Impression Fired for item \(id)!")
        onRenderImpressionFired(id)
    }

    public func updateVisibility(id: String, percentage: CGFloat) {
        guard !firedViewImpressionIDs.contains(id) else { return }

        if percentage >= visibilityThreshold {
            // Continuously update the latest known percentage while the view is visible.
            visibilityWhileTiming[id] = percentage
            startTimerIfNeeded(for: id)
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

    /// Resets the tracker to its initial state.
    public func reset() {
        timerTasks.values.forEach { $0.cancel() }
        timerTasks.removeAll()
        firedViewImpressionIDs.removeAll()
        firedRenderImpressionIDs.removeAll()
        visibilityWhileTiming.removeAll()
        firedImpressionVisibility.removeAll()
    }

    private func startTimerIfNeeded(for id: String) {
        guard timerTasks[id] == nil else { return }

        print("👁️ Viewable threshold met for item \(id). Starting 1-second timer...")

        timerTasks[id] = Task {
            let nanoseconds = UInt64(timeThreshold * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)

            print("✅ Viewable Impression Fired for item \(id)!")
            firedViewImpressionIDs.insert(id)

            // Lock in the most recent percentage from when the timer was running.
            if let finalVisibility = visibilityWhileTiming[id] {
                firedImpressionVisibility[id] = finalVisibility
            }

            onViewImpressionFired(id)
            cancelTimer(for: id)
        }
    }

    private func cancelTimer(for id: String) {
        if let task = timerTasks[id] {
            print("❌ Visibility lost or impression fired for item \(id). Cancelling timer.")
            task.cancel()
            timerTasks[id] = nil
            visibilityWhileTiming.removeValue(forKey: id)
        }
    }
}
