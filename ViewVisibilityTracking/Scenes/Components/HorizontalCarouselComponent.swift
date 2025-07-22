import UIKit

public final class HorizontalCarouselComponent: UIView {
    private let place: NFOPlace

    /// The component now holds a reference to an object conforming to the `ImpressionTracking` protocol.
    /// The last known visible rectangle provided by the host. This is used to
    /// trigger a refresh after an impression is fired.
//    private var lastKnownVisibleRect: CGRect?
    private let parentCGRect: () -> CGRect
    private var visibilityMonitor: NFOVisibilityMonitor?
    private var presentationObserver: ViewPresentedOnTopStateObserver?

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

    lazy var impressionTracker: ImpressionTracking = MRCImpressionTracker(
        onViewImpressionFired: { [weak self] itemID in
            print("🚀 Firing API Call for VIEWABLE impression on item \(itemID)")
            // After an impression fires, re-run the visibility check.
            self?.updateCardVisibilities()
        },
        onRenderImpressionFired: { itemID in
            print("🎨 Firing API Call for RENDER impression on item \(itemID)")
        }
    )

    /// The designated initializer for the component.
    public init(place: NFOPlace, frame: CGRect = .zero, parentCGRect: @escaping @autoclosure () -> CGRect) {
        self.place = place
        self.parentCGRect = parentCGRect
        super.init(frame: frame)
        setupComponentView()
        setupVisibilityMonitor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            presentationObserver?.start()
        } else {
            presentationObserver?.stop()
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

    private func setupVisibilityMonitor() {
        visibilityMonitor = NFOVisibilityMonitor { [weak self] in
            print("👁️ Carousel's monitor detected an obstruction change.")
            self?.updateCardVisibilities()
        }
        presentationObserver = ViewPresentedOnTopStateObserver(observing: self) { [weak self] in
            self?.updateCardVisibilities()
        }
    }

    public func updateCardVisibilities() {
        // Store the latest visible rect from the host.

        for cell in collectionView.visibleCells {
            guard let cardCell = cell as? CardCell,
                  let indexPath = collectionView.indexPath(for: cardCell) else {
                continue
            }

            let itemID = "item_\(indexPath.item + 1)"
            cardCell.itemID = itemID

            let hasFiredView = impressionTracker.hasFiredViewImpression(for: itemID)
            let hasFiredRender = impressionTracker.hasFiredRenderImpression(for: itemID)

            if hasFiredView {
                // If the impression has fired, get the final, correct percentage from the tracker.
                let finalPercentage = impressionTracker.visibilityForFiredImpression(for: itemID) ?? 0.0
                cardCell.updateUI(
                    index: indexPath.item,
                    visibilityPercentage: finalPercentage,
                    hasFiredViewImpression: true,
                    hasFiredRenderImpression: hasFiredRender
                )
                continue // Stop processing this cell
            }

            // If the impression has NOT fired, proceed with the full logic.
            let visibility = VisibilityCalculator.percentageVisible(
                of: cardCell,
                within: parentCGRect(),
                forPlace: self.place
            )

            // Update the cell's UI with all the relevant information.
            cardCell.updateUI(
                index: indexPath.item,
                visibilityPercentage: visibility,
                hasFiredViewImpression: false,
                hasFiredRenderImpression: hasFiredRender
            )

            impressionTracker.updateVisibility(for: cardCell, id: itemID, percentage: visibility)
        }
    }
}

extension HorizontalCarouselComponent: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CardCell.reuseIdentifier, for: indexPath) as? CardCell else {
            return UICollectionViewCell()
        }

        // --- RENDER IMPRESSION ---
        let itemID = "item_\(indexPath.item + 1)"
        impressionTracker.trackRender(id: itemID)

        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 20
    }
}
