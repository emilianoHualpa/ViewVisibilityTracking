import Foundation

/// A struct to hold information about a view that might be obstructing other content.
///
/// This structure stores the view's unique identifier, its location in screen coordinates,
/// and a type-safe enum describing the context or "place" where it is being displayed.
public struct NFOInfo: Identifiable, Hashable {
    /// A stable, unique identifier for the tracked view instance.
    public let id: UUID

    /// A type-safe enum to categorize the location of the obstruction.
    public let place: NFOPlace

    /// The frame of the view in the global (screen) coordinate space.
    public var frame: CGRect

    /// A flag indicating if the obstructing view is currently visible.
    public var isVisible: Bool
}
