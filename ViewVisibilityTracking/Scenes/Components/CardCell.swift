import UIKit

@MainActor
public class CardCell: UICollectionViewCell {
    public static let reuseIdentifier = "CardCell"
    public var itemID: String?

    private let visibilityLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(visibilityLabel)
        contentView.layer.cornerRadius = 12
        NSLayoutConstraint.activate([
            visibilityLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            visibilityLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            visibilityLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    /// Updates the cell's UI based on its current visibility and impression state.
    public func updateUI(
        index: Int,
        visibilityPercentage: CGFloat,
        hasFiredViewImpression: Bool,
        hasFiredRenderImpression: Bool
    ) {
        let viewImpressionIcon = hasFiredViewImpression ? "✅" : "❌"
        let renderImpressionIcon = hasFiredRenderImpression ? "✅" : "❌"
        let percentageFormatted = String(format: "%.1f", visibilityPercentage * 100)

        visibilityLabel.text = """
        Card \(index + 1)
        visibility: \(percentageFormatted)%
        viewImpression: \(viewImpressionIcon)
        renderImpression: \(renderImpressionIcon)
        """

        if hasFiredViewImpression {
            contentView.backgroundColor = .systemBlue
        } else if visibilityPercentage >= 0.5 {
            contentView.backgroundColor = .systemGreen
        } else {
            contentView.backgroundColor = .systemRed
        }
    }
}
