import UIKit

public final class HorizontalCarouselComponent: UIView {
    private let place: NFOPlace

    /// The component now owns a single, centralized impression tracker.
    /// It is declared as a `lazy var` to allow `self` to be captured in its initialization closure.
    private lazy var impressionTracker: MRCImpressionTracker = {
        return MRCImpressionTracker(
            onViewImpressionFired: { [weak self] itemID in
                // This is the callback for a successful viewable impression.
                print("🚀 Firing API Call for VIEWABLE impression on item \(itemID)")
                // AnalyticsService.shared.trackViewableImpression(for: itemID)

                // After an impression fires, we must re-run the visibility check
                // to ensure the UI stops tracking this cell and updates its color.
                guard let self = self, let rect = self.lastKnownVisibleRect else { return }
                self.updateCardVisibilities(within: rect)
            },
            onRenderImpressionFired: { itemID in
                // This is the callback for a successful render impression.
                print("🎨 Firing API Call for RENDER impression on item \(itemID)")
                // AnalyticsService.shared.trackRenderImpression(for: itemID)
            }
        )
    }()

    /// The last known visible rectangle provided by the host. This is used to
    /// trigger a refresh after an impression is fired.
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

    public init(place: NFOPlace, frame: CGRect = .zero) {
        self.place = place
        super.init(frame: frame)
        setupComponentView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    @MainActor
    public func updateCardVisibilities(within visibleRectInWindow: CGRect) {
        // Store the latest visible rect from the host.
        self.lastKnownVisibleRect = visibleRectInWindow

        for cell in collectionView.visibleCells {
            guard let cardCell = cell as? CardCell,
                  let indexPath = collectionView.indexPath(for: cardCell) else {
                continue
            }

            let itemID = "item_\(indexPath.item + 1)"
            cardCell.itemID = itemID

            // --- VIEWABLE IMPRESSION ---
            // First, check if the viewable impression has already fired for this item.
            if impressionTracker.hasFiredViewImpression(for: itemID) {
                cardCell.updateUI(for: .impressionFired, percentage: nil, index: indexPath.item)
                continue // Skip to the next cell
            }

            // If not, calculate the current visibility.
            let visibility = VisibilityCalculator.percentageVisible(
                of: cardCell,
                within: visibleRectInWindow,
                forPlace: self.place
            )

            // Update the cell's UI based on the visibility percentage.
            if visibility >= 0.5 {
                cardCell.updateUI(for: .aboveThreshold, percentage: visibility, index: indexPath.item)
            } else {
                cardCell.updateUI(for: .belowThreshold, percentage: visibility, index: indexPath.item)
            }

            // Finally, update the impression tracker with the latest data.
            impressionTracker.updateVisibility(id: itemID, percentage: visibility)
        }
    }
}

extension HorizontalCarouselComponent: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
         guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CardCell.reuseIdentifier, for: indexPath) as? CardCell else {
             return UICollectionViewCell()
         }

         // --- RENDER IMPRESSION ---
         // This is the correct place to fire the render impression, as it happens
         // only once when the cell is prepared for display.
         let itemID = "item_\(indexPath.item)"
         impressionTracker.trackRender(id: itemID)

         return cell
     }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 20
    }
}
