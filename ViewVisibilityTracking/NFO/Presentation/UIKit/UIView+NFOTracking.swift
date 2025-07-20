import UIKit
import Combine

@MainActor
private var nfoHelperKey: UInt8 = 0

public extension UIView {
    internal var nfoHelper: NFOUIKitLifecycleHelper? {
        objc_getAssociatedObject(self, &nfoHelperKey) as? NFOUIKitLifecycleHelper
    }

    func trackAsNFO(place: NFOPlace) {
        self.trackAsNFO(place: place, tracker: NFOTracker.shared)
    }

    func stopTrackingNFO() {
        if let helper = nfoHelper {
            helper.stopTracking()
            objc_setAssociatedObject(self, &nfoHelperKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension UIView {
    func trackAsNFO(place: NFOPlace, tracker: NFOTracking) {
        if objc_getAssociatedObject(self, &nfoHelperKey) != nil {
            return
        }
        let helper = NFOUIKitLifecycleHelper(view: self, place: place, tracker: tracker)
        objc_setAssociatedObject(self, &nfoHelperKey, helper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
