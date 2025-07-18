import Foundation

@MainActor
public final class MRCImpressionTracker {

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

    /// Initializes the impression tracker.
    /// - Parameters:
    ///   - visibilityThreshold: The percentage (0.0 to 1.0) required for a viewable impression.
    ///   - timeThreshold: The uninterrupted time in seconds for a viewable impression.
    ///   - onViewImpressionFired: The closure to execute when a viewable impression is confirmed.
    ///   - onRenderImpressionFired: The closure to execute when a render impression is confirmed.
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

    /// Tracks a render impression for a given item ID.
    /// This is a one-time event per ID.
    public func trackRender(id: String) {
        guard !firedRenderImpressionIDs.contains(id) else { return }
        firedRenderImpressionIDs.insert(id)
        print("🎨 Render Impression Fired for item \(id)!")
        onRenderImpressionFired(id)
    }

    /// Updates the tracker with the latest visibility data to evaluate for a viewable impression.
    public func updateVisibility(id: String, percentage: CGFloat) {
        guard !firedViewImpressionIDs.contains(id) else { return }

        if percentage >= visibilityThreshold {
            startTimerIfNeeded(for: id)
        } else {
            cancelTimer(for: id)
        }
    }

    /// Checks if a viewable impression has already been fired for a given item ID.
    public func hasFiredViewImpression(for id: String) -> Bool {
        return firedViewImpressionIDs.contains(id)
    }

    /// Resets the tracker to its initial state.
    public func reset() {
        timerTasks.values.forEach { $0.cancel() }
        timerTasks.removeAll()
        firedViewImpressionIDs.removeAll()
        firedRenderImpressionIDs.removeAll()
    }

    private func startTimerIfNeeded(for id: String) {
        guard timerTasks[id] == nil else { return }

        print("👁️ Viewable threshold met for item \(id). Starting 1-second timer...")
        timerTasks[id] = Task {
            let nanoseconds = UInt64(timeThreshold * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)

            print("✅ Viewable Impression Fired for item \(id)!")
            firedViewImpressionIDs.insert(id)
            onViewImpressionFired(id)
            cancelTimer(for: id)
        }
    }

    private func cancelTimer(for id: String) {
        if let task = timerTasks[id] {
            print("❌ Visibility lost or impression fired for item \(id). Cancelling timer.")
            task.cancel()
            timerTasks[id] = nil
        }
    }
}
