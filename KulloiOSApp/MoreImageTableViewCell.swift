/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit

class MoreImageTableViewCell: UITableViewCell {

    @IBOutlet private var avatarImageView : UIImageView!
    
    func setAvatarImage(avatarImage: UIImage?) {
        avatarImageView.image = avatarImage
    }
}