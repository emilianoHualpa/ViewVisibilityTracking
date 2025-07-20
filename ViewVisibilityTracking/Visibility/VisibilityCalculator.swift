import UIKit
import Foundation

/// A helper for calculating the visible percentage of a view.
///
/// This calculator provides a centralized place for the complex logic required to determine
/// how much of a view is actually visible to the user, considering the screen's visible area
/// and any other views that might be obstructing it.
public enum VisibilityCalculator {

    /// Calculates the visible percentage of a given view.
    /// - Parameters:
    ///   - view: The `UIView` whose visibility is being calculated.
    ///   - visibleRect: The rectangle representing the visible area of the window (e.g., the scroll view's frame).
    ///   - place: The placement context for finding relevant obstructions.
    /// - Returns: A `CGFloat` between 0.0 and 1.0 representing the visible percentage, rounded to 3 decimal places.
    @MainActor
    public static func percentageVisible(
        of view: UIView,
        within visibleRect: CGRect,
        forPlace place: NFOPlace
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

        // If the view is not visible at all, we can exit early.
        if initialVisiblePart.isNull || initialVisiblePart.isEmpty {
            return 0.0
        }

        let initialVisibleArea = initialVisiblePart.width * initialVisiblePart.height
        let initialPercentage = initialVisibleArea / totalViewArea

        // --- OPTIMIZATION ---
        // If the view is less than 50% visible, don't bother with the expensive
        // obstruction calculation. We can assume its visibility is low enough.
        if initialPercentage < 0.5 {
            let clampedPercentage = max(0.0, min(1.0, initialPercentage))
            return round(clampedPercentage, toDecimalPlaces: 3)
        }

        // 3. If we passed the threshold, NOW we fetch the obstructions.
        let obstructions = NFOTracker.shared.obstructions(in: place)
        var finalVisibleArea = initialVisibleArea

        // 4. Calculate the total area of all obstructions that overlap the initial visible part.
        let totalObstructionArea = obstructions
            .filter { $0.isVisible } // Consider only visible obstructions
            .map { $0.frame } // Get their frames
            .map { initialVisiblePart.intersection($0) } // Find how much each one overlaps the *visible part* of our view
            .map { $0.width * $0.height } // Calculate the area of that overlap
            .reduce(0, +) // Sum up all the overlapping areas

        // Subtract the total obstruction area from the visible area.
        finalVisibleArea -= totalObstructionArea

        // 5. Calculate the final percentage.
        let finalPercentage = finalVisibleArea / totalViewArea

        // Clamp the result between 0.0 and 1.0 and round to 3 decimal places.
        let clampedPercentage = max(0.0, min(1.0, finalPercentage))
        return round(clampedPercentage, toDecimalPlaces: 3)
    }

    /// Rounds a CGFloat value to a specific number of decimal places.
    private static func round(_ value: CGFloat, toDecimalPlaces places: Int) -> CGFloat {
        let divisor = pow(10.0, CGFloat(places))
        return (value * divisor).rounded() / divisor
    }
}
