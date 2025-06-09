//
//  HomeViewController.swift
//  ViewVisibilityTracking
//
//  Created by Emiliano Hualpa on 9/6/25.
//
import UIKit

final class HomeViewController: UIViewController {
    var messageTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBlue
        title = "Home"

        // Configure label
        let label = UILabel()
        label.text = "Home View"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        // Configure button
        let detailButton = UIButton(type: .system)
        detailButton.setTitle("Show Details", for: .normal)
        detailButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        detailButton.backgroundColor = .white
        detailButton.layer.cornerRadius = 8
        detailButton.translatesAutoresizingMaskIntoConstraints = false
        detailButton.addTarget(self, action: #selector(showDetail), for: .touchUpInside)

        // Add subviews
        view.addSubview(label)
        view.addSubview(detailButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            detailButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            detailButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            detailButton.widthAnchor.constraint(equalToConstant: 200),
            detailButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        startPrintingMessages()
    }

    @objc private func showDetail() {
        let detailVC = DetailViewController()
        navigationController?.pushViewController(detailVC, animated: true)
    }

    func startPrintingMessages() {
        // 2. Schedule a repeating timer
        // The timer will fire every 1.0 second and call the `printMessage` function.
        messageTimer = Timer.scheduledTimer(timeInterval: 1.0,
                                            target: self,
                                            selector: #selector(printMessage),
                                            userInfo: nil,
                                            repeats: true)
    }

    // 3. Define the function to be called by the timer
    // This function must be exposed to Objective-C using @objc.
    @objc func printMessage() {
        print("This message appears every second.")
    }

    // 4. Invalidate the timer when it's no longer needed
    // This is crucial to prevent memory leaks.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        messageTimer?.invalidate()
        messageTimer = nil
    }

}
