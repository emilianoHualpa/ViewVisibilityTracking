import UIKit
import Combine

//================================================================================
// MARK: - Host App: HostViewController
//================================================================================

/// This represents the "smart" host view controller that owns the layout and events.
final class FavoritesViewController: UIViewController, UICollectionViewDelegate {

    // MARK: - Properties
    private let mainScrollView = UIScrollView()
    private let stackView = UIStackView()
    private let carouselComponent = HorizontalCarouselComponent(place: .favorites)
    private let testBlock = TestFloatingBlock()
    private let floatingButton = UIButton(configuration: .filled())
    private var testBoxWidthConstraint: NSLayoutConstraint!

    // The host now owns the visibility monitor.
    private var visibilityMonitor: NFOVisibilityMonitor?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
//        title = "Hosted Carousel"
        view.backgroundColor = .systemBackground
        setupViews()
        setupLayout()
        setupVisibilityMonitor()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Trigger an update after the initial layout pass.
        Task {
            updateComponentVisibility()
        }
    }

    // MARK: - Setup
    private func setupViews() {
        // The host is the delegate for BOTH scroll views.
        mainScrollView.delegate = self
        carouselComponent.collectionView.delegate = self

        stackView.addArrangedSubview(createDummyView(text: "Host Content Above", color: .systemTeal))
        stackView.addArrangedSubview(carouselComponent)
        stackView.addArrangedSubview(createDummyView(text: "Host Content Below", color: .systemIndigo))
        stackView.axis = .vertical
        stackView.spacing = 30

        view.addSubview(mainScrollView)
        mainScrollView.addSubview(stackView)
        view.addSubview(testBlock)
        view.addSubview(floatingButton)

        testBlock.trackAsNFO(place: .favorites)
        floatingButton.trackAsNFO(place: .favorites)
        floatingButton.setTitle("Toggle NFO", for: .normal)
        floatingButton.addTarget(self, action: #selector(floatingButtonTapped), for: .touchUpInside)

        mainScrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        carouselComponent.translatesAutoresizingMaskIntoConstraints = false
        testBlock.translatesAutoresizingMaskIntoConstraints = false
        floatingButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupLayout() {
        testBoxWidthConstraint = testBlock.widthAnchor.constraint(equalToConstant: 150)
        NSLayoutConstraint.activate([
            mainScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stackView.topAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: mainScrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: mainScrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: mainScrollView.widthAnchor),

            carouselComponent.heightAnchor.constraint(equalToConstant: 150),

            testBlock.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            testBlock.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            testBoxWidthConstraint,

            floatingButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            floatingButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func setupVisibilityMonitor() {
        // When an NFO changes, the HOST triggers the component update.
        visibilityMonitor = NFOVisibilityMonitor { [weak self] in
            self?.updateComponentVisibility()
        }
    }

    // MARK: - Actions & Visibility Calculation

    @objc private func floatingButtonTapped() {
        if Bool.random() {
            let profVC = ProfileViewController()
            profVC.modalPresentationStyle = .pageSheet
            self.present(profVC, animated: true)
        }
    }

    @MainActor
    func updateComponentVisibility() {
        guard view.window != nil else { return }

        let visibleRect = mainScrollView.convert(mainScrollView.bounds, to: nil)

        carouselComponent.updateCardVisibilities(within: visibleRect)
    }

    private func createDummyView(text: String, color: UIColor) -> UIView {
        let dummyView = UIView()
        dummyView.backgroundColor = color
        dummyView.heightAnchor.constraint(equalToConstant: 400).isActive = true
        return dummyView
    }
}

// Make your view controller conform to the delegate protocol
extension FavoritesViewController: UIAdaptivePresentationControllerDelegate {

    // This delegate method is GUARANTEED to be called after a sheet is dismissed.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        print("✅ Presentation controller was dismissed. Telling carousel to update.")

        // Now you can reliably command your component to update.
        updateComponentVisibility()
    }
}

// The host conforms to UIScrollViewDelegate to handle all scroll events.
extension FavoritesViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // This is called for both vertical and horizontal scrolls.
        updateComponentVisibility()
    }
}

//================================================================================
// MARK: - Shared Components (For Demo)
//================================================================================

@MainActor
public class CardCell: UICollectionViewCell {
    public static let reuseIdentifier = "CardCell"

    /// The possible visibility states for a card.
    public enum VisibilityState {
        case belowThreshold
        case aboveThreshold
        case impressionFired
    }

    public var itemID: String?

    private let visibilityLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 18, weight: .bold)
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
            visibilityLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            visibilityLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    /// Updates the cell's UI based on its current visibility state and percentage.
    public func updateUI(for state: VisibilityState, percentage: CGFloat?, index: Int) {
        switch state {
        case .belowThreshold:
            contentView.backgroundColor = .systemRed
            let percentageFormatted = String(format: "%.1f", (percentage ?? 0) * 100)
            visibilityLabel.text = "Card \(index + 1):\n\(percentageFormatted)% visible"

        case .aboveThreshold:
            contentView.backgroundColor = .systemGreen
            let percentageFormatted = String(format: "%.1f", (percentage ?? 0) * 100)
            visibilityLabel.text = "Card \(index + 1):\n\(percentageFormatted)% visible"

        case .impressionFired:
            contentView.backgroundColor = .systemBlue
            visibilityLabel.text = "Impression Fired"
        }
    }
}
