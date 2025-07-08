import Foundation

/// An enum representing the distinct places or contexts where an NFO can appear.
///
/// Using an enum provides type safety and prevents errors from using incorrect string literals.
/// You should extend this enum with all the specific locations in your app where
/// an obstruction might occur.
public enum NFOPlace: String, Hashable, CaseIterable {
    case home
    case details
    case favorites
    case profile
}
