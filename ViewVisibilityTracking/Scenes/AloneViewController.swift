import UIKit

// MARK: - AloneViewController
final class AloneViewController: UIViewController {

    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        return scrollView
    }()

    let testBlock = TestFloatingBlock()

    let contentView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()

    lazy var floatingButton: UIButton & CoverableView = {
        let button = UIButton(configuration: .filled(), primaryAction: nil)
        button.setTitle("Floating Button", for: .normal)
        button.addTarget(self, action: #selector(floatingButtonTapped(_:)), for: .touchUpInside)

        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Details"
        setupViews()
        setupLayout()
        addContent()
        addTestBlock()
    }

    @objc private func floatingButtonTapped(_ sender: UIButton) {
        testBlock.isHidden.toggle()
    }

    private func setupViews() {
        floatingButton.setTitle("Floating Button", for: .normal)

        view.addSubview(scrollView)
        view.addSubview(floatingButton)
        scrollView.addSubview(contentView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        floatingButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupLayout() {
        // Use the scroll view's contentLayoutGuide to define the scrollable area
        let contentLayoutGuide = scrollView.contentLayoutGuide

        NSLayoutConstraint.activate([

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),


            contentView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),

            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            floatingButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            floatingButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func addContent() {
        // Add multiple blocks to make the content height exceed the screen height
        for _ in 0..<10 {
            let block = TestBlockAlone()
            contentView.addArrangedSubview(block)
        }
    }

    private func addTestBlock() {
        view.addSubview(testBlock)
        testBlock.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            testBlock.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            testBlock.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        testBlock.configure(text: "Testing block in the middle")
    }
}

final class TestBlockAlone: TrackableUIView {
    private let label = UILabel()

    // Each block now owns its own visibility tracker.
    private var visibilityTracker: VisibilityTracker?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBlue
        layer.cornerRadius = 8
        label.textColor = .white
        label.font = .systemFont(ofSize: 20, weight: .bold)
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.heightAnchor.constraint(equalToConstant: 150),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("...") }

    private func updateAppearance(with percentage: CGFloat) {
        // This is called from the tracker's closure.
        self.alpha = max(0.2, percentage)
        self.label.text = String(format: "Visibility: %.2f%%", percentage * 100)
    }
}

extension TestBlockAlone: VisibilityUpdateReceiver {
    func visibilityDidChange(to percentage: CGFloat) {
        self.alpha = max(0.2, percentage)
        if percentage * 100 > 50 {
            backgroundColor = .systemGreen
        } else {
            backgroundColor = .systemRed
        }
        self.label.text = String(format: "Visibility: %.2f%%", percentage * 100)
    }
}

