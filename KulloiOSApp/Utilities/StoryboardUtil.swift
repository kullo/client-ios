import UIKit

final class StoryboardUtil {
    private init() {}

    static func instantiate<T: UIViewController>(_ vcType: T.Type) -> T {
        let storyboard = UIStoryboard(
            name: String(describing: vcType),
            bundle: Bundle(for: vcType))
        return storyboard.instantiateInitialViewController()! as! T
    }
}
