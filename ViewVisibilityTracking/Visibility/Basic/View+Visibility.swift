import UIKit

extension UIView {

    /// Finds all subviews conforming to the ViewObfuscator protocol within a given view hierarchy.
    private func findAllObfuscatorViews(in view: UIView) -> [ViewObfuscator] {
        var coverableViews: [ViewObfuscator] = []

        for subview in view.subviews {
            if let coverableView = subview as? ViewObfuscator {
                coverableViews.append(coverableView)
            }
            // Recurse into subviews to find coverable views at any depth
            coverableViews.append(contentsOf: findAllObfuscatorViews(in: subview))
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
        let obfuscatorViews = findAllObfuscatorViews(in: rootView)

        // 3. Subtract the area of each coverable view.
        for obfuscatorView in obfuscatorViews {
            // Ensure the coverable view is actually visible and on screen
            guard !obfuscatorView.isHidden, obfuscatorView.alpha > 0 else { continue }

            // Convert the coverable view's frame to the window's coordinate space to compare.
            let coverFrameInWindow = obfuscatorView.convert(obfuscatorView.bounds, to: nil)

            // Calculate the intersection between our visible part and the covering view.
            let obscuredRect = visiblePart.intersection(coverFrameInWindow)
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

extension UIView {

    /// Calculates visibility by geometrically subtracting the frames of known NFOs from the tracker.
    ///
    /// - Parameters:
    ///   - visibleRectInWindow: The frame of the visible area on screen (e.g., the window's safe area).
    ///   - place: The NFO context to check for obstructing views.
    /// - Returns: A percentage (0.0 to 1.0) of how much of the view is visible.
    func visibilityPercentage(
        within visibleRectInWindow: CGRect,
        forPlace place: NFOPlace
    ) async -> CGFloat {

        guard !isHidden, alpha > 0, let _ = self.window, !self.bounds.isEmpty else {
            return 0
        }

        let viewFrameInWindow = self.convert(self.bounds, to: nil)
        var visiblePart = viewFrameInWindow.intersection(visibleRectInWindow)

        if visiblePart.isNull {
            return 0
        }

        let obfuscators = NFOTracker.shared.obstructions(in: place)

        for obfuscator in obfuscators {

            guard obfuscator.isVisible else {
                continue
            }

            let coverFrameInWindow = obfuscator.frame
            let obscuredRect = visiblePart.intersection(coverFrameInWindow)
            if obscuredRect.isNull {
                continue
            }

            let obscuredArea = obscuredRect.width * obscuredRect.height
            let visibleArea = visiblePart.width * visiblePart.height

            guard visibleArea > 0 else {
                continue
            }

            let newVisibleArea = max(0, visibleArea - obscuredArea)
            let newHeight = visiblePart.height * (newVisibleArea / visibleArea)
            visiblePart.size.height = newHeight
        }

        let finalVisibleArea = visiblePart.width * visiblePart.height
        let totalViewArea = self.bounds.width * self.bounds.height

        return totalViewArea > 0 ? finalVisibleArea / totalViewArea : 0
    }
}
