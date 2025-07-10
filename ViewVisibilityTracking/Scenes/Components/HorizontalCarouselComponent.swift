//import UIKit
//import Combine
//
////================================================================================
//// MARK: - Your SPM: HorizontalCarouselComponent
////================================================================================
//
///// This represents the reusable carousel component that you own and distribute in a Swift Package.
///// It is now a "dumb" component that relies on the host to tell it when and how to update.
//public final class HorizontalCarouselComponent: UIView {
//
//    // The component no longer needs its own visibility monitor.
//
//    // We expose the collection view so the host can become its delegate.
//    public private(set) lazy var collectionView: UICollectionView = {
//        let layout = UICollectionViewFlowLayout()
//        layout.scrollDirection = .horizontal
//        layout.itemSize = CGSize(width: 250, height: 150)
//        layout.minimumLineSpacing = 20
//        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
//
//        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
//        collectionView.dataSource = self
//        // The host will set the delegate.
//        collectionView.register(CardCell.self, forCellWithReuseIdentifier: CardCell.reuseIdentifier)
//        collectionView.showsHorizontalScrollIndicator = false
//        collectionView.backgroundColor = .clear
//        return collectionView
//    }()
//
//    public override init(frame: CGRect) {
//        super.init(frame: frame)
//        setupComponentView()
//    }
//
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    private func setupComponentView() {
//        addSubview(collectionView)
//        collectionView.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            collectionView.topAnchor.constraint(equalTo: topAnchor),
//            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
//            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
//            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
//        ])
//    }
//
//    /// **PUBLIC API**: The host view controller calls this method to trigger a visibility update,
//    /// providing the exact rectangle that is visible on screen.
//    public func updateCardVisibilities(within visibleRectInWindow: CGRect) {
//        for cell in collectionView.visibleCells {
//            guard let cardCell = cell as? CardCell,
//                  let indexPath = collectionView.indexPath(for: cardCell) else {
//                continue
//            }
//
//            Task {
//                // The component uses the rect provided by the host.
//                let visibility = await cardCell.visibilityPercentage(
//                    within: visibleRectInWindow,
//                    forPlace: .favorites
//                )
//
//                await MainActor.run {
//                    cardCell.updateVisibility(percentage: visibility, index: indexPath.item)
//                }
//            }
//        }
//    }
//}
//
//extension HorizontalCarouselComponent: UICollectionViewDataSource {
//    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        return 20
//    }
//
//    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CardCell.reuseIdentifier, for: indexPath) as? CardCell else {
//            return UICollectionViewCell()
//        }
//        cell.updateVisibility(percentage: 0, index: indexPath.item)
//        return cell
//    }
//}

import UIKit

//================================================================================
// MARK: - Your SPM: HorizontalCarouselComponent
//================================================================================

/// This represents the reusable carousel component. It now contains a robust,
/// self-contained mechanism to detect when a presented view controller is dismissed.
public final class HorizontalCarouselComponent: UIView {

    // --- NEW: Self-contained dismissal detection using a CADisplayLink for active polling ---
    private var statePollTimer: CADisplayLink?
    private var wasPresentedOnTop = false
    private var lastKnownVisibleRect: CGRect?

    public private(set) lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 250, height: 150)
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.register(CardCell.self, forCellWithReuseIdentifier: CardCell.reuseIdentifier)
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        return collectionView
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupComponentView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // We override didMoveToWindow to start and stop our polling timer.
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window != nil {
            startStatePollTimer()
        } else {
            stopStatePollTimer()
        }
    }

    private func startStatePollTimer() {
        // Invalidate any existing timer to be safe.
        stopStatePollTimer()
        // Set the initial state before starting.
        wasPresentedOnTop = self.isViewControllerPresentedOnTop
        // Create a new timer that calls our check function.
        statePollTimer = CADisplayLink(target: self, selector: #selector(pollForStateChange))

        // --- PERFORMANCE OPTIMIZATION ---
        // We don't need to check 60 times per second. 15 is more than enough
        // to catch a dismissal instantly from a user's perspective.
        // This reduces the performance impact by 75%.
        statePollTimer?.preferredFramesPerSecond = 15

        statePollTimer?.add(to: .main, forMode: .common)
    }

    private func stopStatePollTimer() {
        statePollTimer?.invalidate()
        statePollTimer = nil
    }

    @objc private func pollForStateChange() {
        // This function runs every frame while the timer is active.
        let isCurrentlyPresentedOnTop = self.isViewControllerPresentedOnTop

        // We are looking for one specific change: the state flipping from TRUE to FALSE.
        if wasPresentedOnTop && !isCurrentlyPresentedOnTop {
            print("✅ Dismissal Detected via Polling: Forcing UI update.")

            // Trigger the UI update with the last known visible rectangle.
            if let rect = self.lastKnownVisibleRect {
                self.updateCardVisibilities(within: rect)
            }
        }

        // Update the state for the next frame's check.
        wasPresentedOnTop = isCurrentlyPresentedOnTop
    }

    deinit {
        stopStatePollTimer()
    }

    private func setupComponentView() {
        addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    /// **PUBLIC API**: The host view controller calls this method to trigger a visibility update.
    /// We now also store the provided rect for our internal use.
    public func updateCardVisibilities(within visibleRectInWindow: CGRect) {
        // Store the rect provided by the host so our internal trigger can use it.
        self.lastKnownVisibleRect = visibleRectInWindow

        for cell in collectionView.visibleCells {
            guard let cardCell = cell as? CardCell,
                  let indexPath = collectionView.indexPath(for: cardCell) else {
                continue
            }
            Task {
                let visibility = await cardCell.visibilityPercentage(
                    within: visibleRectInWindow,
                    forPlace: .favorites // Assuming NFOPlace is defined elsewhere
                )
                await MainActor.run {
                    cardCell.updateVisibility(percentage: visibility, index: indexPath.item)
                }
            }
        }
    }
}

extension HorizontalCarouselComponent: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 20
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CardCell.reuseIdentifier, for: indexPath) as? CardCell else {
            return UICollectionViewCell()
        }
        cell.updateVisibility(percentage: 0, index: indexPath.item)
        return cell
    }
}
