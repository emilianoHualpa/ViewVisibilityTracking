import UIKit

/// A  helper for calculating the visible percentage of a view.
///
/// This calculator provides a centralized place for the complex logic required to determine
/// how much of a view is actually visible to the user, considering the screen's visible area
/// and any other views that might be obstructing it.
public enum VisibilityCalculator {

    /// Calculates the visible percentage of a given view.
    /// This method is marked with `@MainActor` because it accesses main-thread-only
    /// properties like `superview` and `window`.
    /// - Parameters:
    ///   - view: The `UIView` whose visibility is being calculated.
    ///   - visibleRect: The rectangle representing the visible area of the window (e.g., the scroll view's frame).
    ///   - obstructions: An array of `NFOInfo` objects for any views that might be obstructing the target view.
    /// - Returns: A `CGFloat` between 0.0 and 1.0 representing the visible percentage.
    @MainActor
    public static func percentageVisible(
        of view: UIView,
        within visibleRect: CGRect,
        considering obstructions: [NFOInfo]
    ) -> CGFloat {
        // Ensure the view has a superview and a window to perform coordinate conversions.
        guard let superview = view.superview, let _ = view.window else {
            return 0.0
        }

        // A view with a zero-size frame has zero visibility.
        let totalViewArea = view.frame.width * view.frame.height
        guard totalViewArea > 0 else {
            return 0.0
        }

        // 1. Convert the view's frame to the window's coordinate space.
        let viewFrameInWindow = superview.convert(view.frame, to: nil)

        // 2. Find the initial visible part of the view by intersecting its frame
        //    with the screen's visible rectangle.
        let initialVisiblePart = viewFrameInWindow.intersection(visibleRect)
        var finalVisibleAreaValue = initialVisiblePart.width * initialVisiblePart.height

        // 3. Calculate the total area of all obstructions that overlap the initial visible part.
        if !initialVisiblePart.isNull {
            let totalObstructionArea = obstructions
                .filter { $0.isVisible } // Consider only visible obstructions
                .map { $0.frame } // Get their frames
                .map { initialVisiblePart.intersection($0) } // Find how much each one overlaps the *visible part* of our view
                .map { $0.width * $0.height } // Calculate the area of that overlap
                .reduce(0, +) // Sum up all the overlapping areas

            // Subtract the total obstruction area from the visible area.
            finalVisibleAreaValue -= totalObstructionArea
        }

        // 4. Calculate the final percentage.
        let percentage = (finalVisibleAreaValue / totalViewArea) * 100
        return percentage
    }
}
