//
//  ViewController.swift
//  ViewVisibilityTracking
//
//  Created by Emiliano Hualpa on 7/6/25.
//

import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        setupViewControllers()
    }

    private func setupTabBar() {
        tabBar.backgroundColor = .systemBackground
        tabBar.tintColor = .systemBlue
        tabBar.unselectedItemTintColor = .systemGray
    }

    private func setupViewControllers() {

        let favoritesVC = createNavigationController(
            rootViewController: FavoritesViewController(),
            title: "Favorites",
            image: UIImage(systemName: "heart"),
            selectedImage: UIImage(systemName: "heart.fill"),
            tag: 2
        )

        let profileVC = createNavigationController(
            rootViewController: ProfileViewController(),
            title: "Profile",
            image: UIImage(systemName: "person"),
            selectedImage: UIImage(systemName: "person.fill"),
            tag: 3
        )

        let searchVC = createNavigationController(
            rootViewController: SearchViewController(),
            title: "Search",
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass.fill"),
            tag: 3
        )

        viewControllers = [favoritesVC, profileVC, searchVC]
    }

    private func createNavigationController(
        rootViewController: UIViewController,
        title: String,
        image: UIImage?,
        selectedImage: UIImage?,
        tag: Int
    ) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.tabBarItem = UITabBarItem(
            title: title,
            image: image,
            selectedImage: selectedImage
        )
        navigationController.tabBarItem.tag = tag
        return navigationController
    }
}


