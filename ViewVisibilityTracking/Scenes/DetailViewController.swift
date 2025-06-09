import UIKit

// MARK: - DetailViewController
final class DetailViewController: UIViewController {

    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
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
//        floatingButton.isHidden = true

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
        for i in 0..<10 {
            let block = TestBlock()
            block.configure(text: "Test Block \(i + 1)")
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

extension DetailViewController: UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let visibleRectInWindow = view.convert(view.safeAreaLayoutGuide.layoutFrame, to: nil)

        // The loop variable 'view' is of type UIView.
        for (index, view) in contentView.arrangedSubviews.enumerated() {

            // --- THE FIX ---
            // Safely cast the generic UIView to your specific TestBlock subclass.
            // If the cast fails for any reason, `continue` to the next loop iteration.
            guard let block = view as? TestBlock else {
                continue
            }
            // ----------------

            // Now, 'block' is known to be a TestBlock, and you can access its members.
            let percentage = block.protocolBasedVisibilityPercentage(within: visibleRectInWindow, rootView: self.view)

            block.alpha = max(0.2, percentage)

            // This line will now compile successfully.
            block.configure(text: String(format: "Block \(index + 1) visibility: %.2f%%", percentage * 100))
        }
    }
}

// MARK: - TestBlock
final class TestFloatingBlock: UIView, CoverableView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemGray4
        layer.cornerRadius = 8

        label.textColor = .white
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textAlignment = .center

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([

            self.heightAnchor.constraint(equalToConstant: 150),

            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String) {
        label.text = text
    }
}


// MARK: - TestBlock
final class TestBlock: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemRed
        layer.cornerRadius = 8

        label.textColor = .white
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textAlignment = .center

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([

            self.heightAnchor.constraint(equalToConstant: 150),

            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String) {
        label.text = text
    }
}

extension UIButton: CoverableView {}
