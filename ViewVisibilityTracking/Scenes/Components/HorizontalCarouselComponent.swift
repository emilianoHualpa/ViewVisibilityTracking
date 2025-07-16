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

    /// **PUBLIC API**: The host view controller calls this method to trigger a visibility update.
    @MainActor
    public func updateCardVisibilities(within visibleRectInWindow: CGRect, obstructions: [NFOInfo]) {
        for cell in collectionView.visibleCells {
            guard let cardCell = cell as? CardCell,
                  let indexPath = collectionView.indexPath(for: cardCell) else {
                continue
            }

            // Use the new, reusable calculator to get the visibility percentage.
            let visibility = VisibilityCalculator.percentageVisible(
                of: cardCell,
                within: visibleRectInWindow,
                considering: obstructions
            )

            // Update the cell's UI.
            cardCell.updateVisibility(percentage: visibility, index: indexPath.item)
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
