/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */
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
