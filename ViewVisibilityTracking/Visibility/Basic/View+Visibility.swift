import UIKit

extension UIView {

    /// Finds all subviews conforming to the CoverableView protocol within a given view hierarchy.
    private func findAllCoverableViews(in view: UIView) -> [CoverableView] {
        var coverableViews: [CoverableView] = []

        for subview in view.subviews {
            if let coverableView = subview as? CoverableView {
                coverableViews.append(coverableView)
            }
            // Recurse into subviews to find coverable views at any depth
            coverableViews.append(contentsOf: findAllCoverableViews(in: subview))
        }

        return coverableViews
    }

    /// Calculates visibility by geometrically subtracting the frames of known "coverable" views.
    func protocolBasedVisibilityPercentage(within visibleRectInWindow: CGRect, rootView: UIView) -> CGFloat {
        guard !isHidden, alpha > 0, let _ = self.window, !self.bounds.isEmpty else {
            return 0
        }

        // 1. Calculate the initial visible area, clipped to the safe area.
        let viewFrameInWindow = self.convert(self.bounds, to: nil)
        var visiblePart = viewFrameInWindow.intersection(visibleRectInWindow)

        if visiblePart.isNull {
            return 0
        }

        // 2. Find all views that can obscure our view.
        let coverableViews = findAllCoverableViews(in: rootView)

        // 3. Subtract the area of each coverable view.
        for coverableView in coverableViews {
            // Ensure the coverable view is actually visible and on screen
            guard !coverableView.isHidden, coverableView.alpha > 0 else { continue }

            // Convert the coverable view's frame to the window's coordinate space to compare.
            let coverFrameInWindow = coverableView.convert(coverableView.bounds, to: nil)

            // Calculate the intersection between our visible part and the covering view.
            let obscuredRect = visiblePart.intersection(coverFrameInWindow)

            // This is a simplified subtraction. For a perfect calculation, you'd need to
            // handle cases where the remaining visible area is split into multiple rectangles.
            // For this use case, subtracting the area is a very good approximation.
            let obscuredArea = obscuredRect.width * obscuredRect.height
            let visibleArea = visiblePart.width * visiblePart.height
            let newVisibleArea = max(0, visibleArea - obscuredArea)

            // This simplification assumes the remaining visible area can be represented by
            // adjusting the height of the original visiblePart rect.
            let newHeight = visiblePart.height * (newVisibleArea / visibleArea)
            visiblePart.size.height = newHeight
        }

        // 4. Calculate the final percentage.
        let finalVisibleArea = visiblePart.width * visiblePart.height
        let totalViewArea = self.bounds.width * self.bounds.height

        return totalViewArea > 0 ? finalVisibleArea / totalViewArea : 0
    }

    /// Traverses the responder chain to find the view's parent view controller.
    var parentViewController: UIViewController? {
        var responder: UIResponder? = self.next
        while responder != nil {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            responder = responder?.next
        }
        return nil
    }
}
