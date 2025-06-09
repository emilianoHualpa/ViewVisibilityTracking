import UIKit
import Combine

import UIKit
import Combine

final class VisibilityTracker {

    private weak var viewToTrack: UIView?
    private weak var boundaryView: UIView?

    var onVisibilityChange: ((CGFloat) -> Void)?
    private var cancellables: Set<AnyCancellable> = []

    // Updated initializer
    init(viewToTrack: UIView, boundaryView: UIView) {
        self.viewToTrack = viewToTrack
        self.boundaryView = boundaryView
    }

    func calculateAndReportVisibility() {
        guard let view = viewToTrack,
              let window = view.window,
              let boundaryView = self.boundaryView else {
            onVisibilityChange?(0)
            return
        }

        // Calculate the safe area based on the boundaryView.
        let visibleRectInWindow = boundaryView.convert(boundaryView.safeAreaLayoutGuide.layoutFrame, to: nil)

        // The root view for the protocol search should still be the window to find all overlays.
        let percentage = view.protocolBasedVisibilityPercentage(within: visibleRectInWindow, rootView: window)

        onVisibilityChange?(percentage)
    }

    func start() {
        stop()

        guard let view = viewToTrack else { return }

        let parentScrollViews = findParentScrollViews(for: view)

        // Return early if there's nothing to track.
        if parentScrollViews.isEmpty {
            calculateAndReportVisibility()
            return
        }

        // --- THE CORRECTED PATTERN ---

        // 1. Create a "ticker" publisher that fires 2 times per second
        //    and runs in .common mode so it is NOT paused during scrolling.
        let ticker = Timer.publish(every: 1.0 / 2.0, on: .main, in: .common).autoconnect()

        // 2. Create publishers for each scroll view's contentOffset.
        let offsetPublishers = parentScrollViews.map {
            $0.publisher(for: \.contentOffset).eraseToAnyPublisher()
        }

        // 3. Merge all scroll view publishers into a single stream.
        let mergedOffsets = Publishers.MergeMany(offsetPublishers)
            // Start with an initial value to ensure combineLatest fires immediately.
            .prepend(CGPoint.zero)

        // 4. Use `combineLatest` to pair the ticker with the latest offset value.
        ticker
            .combineLatest(mergedOffsets)
            // We now have a stream of (Date, CGPoint) tuples firing on every tick.
            .sink { [weak self] _, _ in // We can ignore the tuple values.
                // The tick itself is our signal to recalculate.
                self?.calculateAndReportVisibility()
            }
            .store(in: &cancellables)

        // Perform an initial calculation.
        calculateAndReportVisibility()
    }

    func stop() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    private func findParentScrollViews(for view: UIView) -> [UIScrollView] {
        var scrollViews: [UIScrollView] = []
        var currentView: UIView? = view.superview
        while currentView != nil {
            if let scrollView = currentView as? UIScrollView {
                scrollViews.append(scrollView)
            }
            currentView = currentView?.superview
        }
        return scrollViews
    }

    deinit {
        stop()
    }
}
