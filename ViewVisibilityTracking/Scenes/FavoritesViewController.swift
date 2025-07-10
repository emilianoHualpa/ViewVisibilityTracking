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
    private let carouselComponent = HorizontalCarouselComponent()
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
        updateComponentVisibility()
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

        testBlock.isHidden = Bool.random()
        // 1. Update the constant of the EXISTING constraint
        testBoxWidthConstraint.constant = Bool.random() ? 150 : 50

        // 2. Animate the layout change (optional, but makes it smooth)
        UIView.animate(withDuration: 0.3) {
            // Request the superview to layout its subviews, applying the constraint change
            self.view.layoutIfNeeded()
        }
    }

    /// This single method is the source of truth for visibility updates.
    private func updateComponentVisibility() {
        guard view.window != nil else { return }
        // The host correctly calculates the visible rect from its own coordinate space.
        let visibleRect = view.convert(view.safeAreaLayoutGuide.layoutFrame, to: nil)
        // It then passes this information to the component.
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

final class CardCell: UICollectionViewCell {
    static let reuseIdentifier = "CardCell"
    private let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 12; contentView.clipsToBounds = true
        label.textColor = .white; label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center; label.numberOfLines = 2
        contentView.addSubview(label); label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor), label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func updateVisibility(percentage: CGFloat, index: Int) {
        if self.contentView.isViewControllerPresentedOnTop {
            contentView.backgroundColor = .systemRed
            label.text = String(format: "Card \(index + 1)\nVisible: %.1f%%", 0)
            return
        }
        contentView.backgroundColor = percentage > 0.5 ? .systemGreen : .systemRed
        label.text = String(format: "Card \(index + 1)\nVisible: %.1f%%", percentage * 100)
    }
}
