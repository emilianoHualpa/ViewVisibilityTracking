import UIKit

public extension UIView {
    /// A computed property that checks if another view controller is currently presented over this view's own view controller.
    /// - Returns: `true` if another view controller is presented on top, otherwise `false`.
    var isViewControllerPresentedOnTop: Bool {
        // Use the application's key window, which is more reliable than `self.window`,
        // especially when this view is being removed from the hierarchy.
        guard let keyWindow = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) else {
            return false
        }

        // 1. Find the top-most controller by traversing `presentedViewController`.
        var topViewController = keyWindow.rootViewController
        while let presentedVC = topViewController?.presentedViewController {
            topViewController = presentedVC
        }

        // 2. Find this view's own parent view controller.
        guard let myViewController = self.findOwningViewController() else {
            return false
        }

        // 3. If our VC is the top one, or if there is no top one, we are not covered.
        guard let topVC = topViewController, topVC != myViewController else {
            return false
        }

        // 4. Crucially, check if our VC is a child of the top VC (e.g., inside a UINavigationController
        // that is the top-most controller). If so, we are the visible content, not what's underneath.
        var currentVC: UIViewController? = myViewController
        while let parentVC = currentVC?.parent {
            if parentVC == topVC {
                // Our parent is the top VC, so we are not covered.
                return false
            }
            currentVC = parentVC
        }

        // 5. If we are not the top VC and not a child of the top VC, then we must be covered by it.
        return true
    }

    /// Finds the owning UIViewController of a UIView by traversing the responder chain.
    private func findOwningViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            responder = responder?.next
        }
        return nil
    }
}
