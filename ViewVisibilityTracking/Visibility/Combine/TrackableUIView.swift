import UIKit

/// A base class for UIViews that automatically tracks their own visibility on screen.
class TrackableUIView: UIView {
    
    private var visibilityTracker: VisibilityTracker?
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        handleVisibilityTracking()
    }
    
    private func handleVisibilityTracking() {
        if self.window != nil {
            // If the view is on-screen and doesn't already have a tracker, create one.
            if self.visibilityTracker == nil {
                guard let boundary = self.parentViewController?.view ?? self.window else { return }
                
                let tracker = VisibilityTracker(viewToTrack: self, boundaryView: boundary)
                
                tracker.onVisibilityChange = { [weak self] percentage in
                    // The view must conform to VisibilityUpdateReceiver to get updates.
                    (self as? VisibilityUpdateReceiver)?.visibilityDidChange(to: percentage)
                }
                
                tracker.start()
                self.visibilityTracker = tracker
            }
        } else {
            // The view was removed from the window, stop and release the tracker.
            self.visibilityTracker?.stop()
            self.visibilityTracker = nil
        }
    }
}

protocol VisibilityUpdateReceiver {
    func visibilityDidChange(to percentage: CGFloat)
}
