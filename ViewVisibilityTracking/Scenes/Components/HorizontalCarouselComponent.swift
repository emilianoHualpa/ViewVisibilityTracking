import UIKit

//================================================================================
// MARK: - Simplified HorizontalCarouselComponent
//================================================================================

/// This represents the reusable carousel component. It is now a "dumb" component,
/// focused only on displaying its content. It relies entirely on its owner (the host
/// view controller) to tell it when and how to update.
public final class HorizontalCarouselComponent: UIView {

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
        setupDismissalObserver()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // The carousel now holds a reference to the observer.
    private var dismissalObserver: ViewPresentedOnTopStateObserver?

    // We still need to store the last known rect to pass to the update method.
    private var lastKnownVisibleRect: CGRect?

    // We override didMoveToWindow to start and stop our polling timer.
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window != nil {
            dismissalObserver?.start()
        } else {
            dismissalObserver?.stop()
        }
    }

    /// Sets up the dismissal observer, providing the logic to run when a dismissal is detected.
    private func setupDismissalObserver() {
        dismissalObserver = ViewPresentedOnTopStateObserver(observing: self) { [weak self] in
            // This closure is the callback. When the observer detects a dismissal,
            // it calls this code.
            guard let self = self, let rect = self.lastKnownVisibleRect else { return }

            // We force a UI update using the last known visible rectangle.
            self.updateCardVisibilities(within: rect)
        }
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
    @MainActor
    public func updateCardVisibilities(within visibleRectInWindow: CGRect) {
        // Store the rect provided by the host so our internal trigger can use it.
        self.lastKnownVisibleRect = visibleRectInWindow

        for cell in collectionView.visibleCells {
            guard let cardCell = cell as? CardCell,
                  let indexPath = collectionView.indexPath(for: cardCell) else {
                continue
            }
            Task {
                let visibility = VisibilityCalculator
                    .percentageVisible(
                        of: cell,
                        within: visibleRectInWindow,
                        considering: NFOTracker.shared.obstructions(in: .favorites)
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
