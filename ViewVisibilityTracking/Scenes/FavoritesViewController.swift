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
    private lazy var carouselComponent = HorizontalCarouselComponent(place: .favorites, parentCGRect:  self.mainScrollView.convert(self.mainScrollView.bounds, to: nil))
    private let testBlock = TestFloatingBlock()
    private let floatingButton = UIButton(configuration: .filled())
    private var testBoxWidthConstraint: NSLayoutConstraint!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupViews()
        setupLayout()
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
        testBoxWidthConstraint = testBlock.widthAnchor.constraint(equalToConstant: 250)
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

    // MARK: - Actions & Visibility Calculation

    @objc private func floatingButtonTapped() {

        let profVC = ProfileViewController()
            profVC.modalPresentationStyle = .pageSheet
            self.present(profVC, animated: true)
    }

    private func createDummyView(text: String, color: UIColor) -> UIView {
        let dummyView = UIView()
        dummyView.backgroundColor = color
        dummyView.heightAnchor.constraint(equalToConstant: 450).isActive = true
        return dummyView
    }
}

// The host conforms to UIScrollViewDelegate to handle all scroll events.
extension FavoritesViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        carouselComponent.updateCardVisibilities()
    }
}
