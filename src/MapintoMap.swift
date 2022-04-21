import UIKit

class MaintoMap: UIStoryboardSegue {
        override func perform() {
        self.source.view.superview?.insertSubview(self.destination.view, aboveSubview: self.source.view)
        self.destination.view.transform = CGAffineTransform(translationX: -self.source.view.frame.size.width, y: 0)
            
        UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseInOut, animations:
            { self.destination.view.transform = CGAffineTransform(translationX: 0, y: 0) },
                        completion: { finished in self.source.present(self.destination, animated: false, completion: nil)})
    }
}
    
class MaptoMain: UIStoryboardSegue {
    override func perform() {
            
        self.source.view.superview?.insertSubview(self.destination.view, aboveSubview: self.source.view)
        self.destination.view.transform = CGAffineTransform(translationX: self.source.view.frame.size.width, y: 0)
        UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseInOut, animations:
            { self.destination.view.transform = CGAffineTransform(translationX: 0, y: 0) },
                        completion: { finished in self.source.present(self.destination, animated: false, completion: nil)})
    }
}
