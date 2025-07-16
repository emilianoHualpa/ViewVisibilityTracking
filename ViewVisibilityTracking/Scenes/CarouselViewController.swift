import UIKit
import Combine

// MARK: - CarouselViewController
final class CarouselViewController: UIViewController {

    var testBoxWidthConstraint: NSLayoutConstraint!
    private var visibilityMonitor: NFOVisibilityMonitor?

    // MARK: - UI Components
    
    lazy var mainScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        // Set the delegate for the *vertical* scroll view
        scrollView.delegate = self
        return scrollView
    }()

    let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 30
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    
    lazy var carouselCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 250, height: 150)
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        // Set the delegate for the *horizontal* collection view scroll
        collectionView.delegate = self
        collectionView.register(CardCell.self, forCellWithReuseIdentifier: CardCell.reuseIdentifier)
        collectionView.showsHorizontalScrollIndicator = false
        return collectionView
    }()

    let testBlock = TestFloatingBlock() // Our NFO

    lazy var floatingButton: UIButton = {
        let button = UIButton(configuration: .filled(), primaryAction: nil)
        button.setTitle("Toggle NFO", for: .normal)
        button.addTarget(self, action: #selector(floatingButtonTapped(_:)), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Carousel"
        
        setupViewsAndNFOs()
        setupLayout()
        setupVisibilityMonitor()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Perform the initial visibility check after the first layout pass.
        updateCardVisibilities()
    }
    
    // MARK: - Setup
    
    private func setupVisibilityMonitor() {
        visibilityMonitor = NFOVisibilityMonitor { [weak self] in
            self?.updateCardVisibilities()
        }
    }

    private func setupViewsAndNFOs() {
        // Add dummy views to ensure vertical scrolling
        contentStackView.addArrangedSubview(createDummyView(text: "Scroll Down", color: .systemTeal))
        contentStackView.addArrangedSubview(carouselCollectionView)
        contentStackView.addArrangedSubview(createDummyView(text: "Keep Scrolling", color: .systemIndigo))
        
        view.addSubview(mainScrollView)
        mainScrollView.addSubview(contentStackView)
        
        // Add NFOs on top of everything
        view.addSubview(testBlock)
        view.addSubview(floatingButton)
        
        // Track the NFOs
        testBlock.trackAsNFO(place: .details)
        floatingButton.trackAsNFO(place: .details)
    }

    private func setupLayout() {
        mainScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        carouselCollectionView.translatesAutoresizingMaskIntoConstraints = false
        testBlock.translatesAutoresizingMaskIntoConstraints = false
        floatingButton.translatesAutoresizingMaskIntoConstraints = false
        
        testBoxWidthConstraint = testBlock.widthAnchor.constraint(equalToConstant: 150)

        NSLayoutConstraint.activate([
            mainScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.widthAnchor.constraint(equalTo: mainScrollView.widthAnchor),
            
            carouselCollectionView.heightAnchor.constraint(equalToConstant: 150),
            
            testBlock.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            testBlock.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            testBoxWidthConstraint,
            
            floatingButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            floatingButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    // MARK: - Actions & Visibility Calculation

    @objc private func floatingButtonTapped(_ sender: UIButton) {
        testBlock.isHidden.toggle()
        let value = CGFloat.random(in: 100...300)
        testBoxWidthConstraint.constant = value
        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func updateCardVisibilities() {
        guard view.window != nil else { return }
        let visibleRectInWindow = view.convert(view.safeAreaLayoutGuide.layoutFrame, to: nil)

        // Iterate through only the cells that are currently visible on screen.
        for cell in carouselCollectionView.visibleCells {
            guard let cardCell = cell as? CardCell,
                  let indexPath = carouselCollectionView.indexPath(for: cardCell) else {
                continue
            }

            Task {
                let visibility = VisibilityCalculator
                    .percentageVisible(
                        of: cell,
                        within: visibleRectInWindow,
                        considering: NFOTracker.shared.obstructions(in: .details)
                    )
                await MainActor.run {
                    cardCell.updateVisibility(percentage: visibility, index: indexPath.item)
                }
            }
        }
    }
    
    private func createDummyView(text: String, color: UIColor) -> UIView {
        let dummyView = UIView()
        dummyView.backgroundColor = color
        dummyView.heightAnchor.constraint(equalToConstant: 300).isActive = true
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        dummyView.addSubview(label)
        label.centerXAnchor.constraint(equalTo: dummyView.centerXAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: dummyView.centerYAnchor).isActive = true
        return dummyView
    }
}

// MARK: - UICollectionViewDataSource
extension CarouselViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 20
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CardCell.reuseIdentifier, for: indexPath) as? CardCell else {
            return UICollectionViewCell()
        }
        cell.updateVisibility(percentage: 0, index: indexPath.item)
        return cell
    }
}

// MARK: - UIScrollViewDelegate
extension CarouselViewController: UICollectionViewDelegate {
    // This delegate method handles both vertical and horizontal scrolls.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCardVisibilities()
    }
}
