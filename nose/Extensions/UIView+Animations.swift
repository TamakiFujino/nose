import UIKit

extension UIView {
    func fadeIn(duration: TimeInterval = 0.3, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: duration, animations: {
            self.alpha = 1
        }, completion: completion)
    }
    
    func fadeOut(duration: TimeInterval = 0.3, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: duration, animations: {
            self.alpha = 0
        }, completion: completion)
    }
    
    func fadeInAndOut(duration: TimeInterval = 0.3, delay: TimeInterval = 2.0) {
        fadeIn(duration: duration) { _ in
            self.fadeOut(duration: duration, delay: delay)
        }
    }
    
    func fadeOut(duration: TimeInterval = 0.3, delay: TimeInterval = 0.0) {
        UIView.animate(withDuration: duration, delay: delay, options: [], animations: {
            self.alpha = 0
        })
    }
} 