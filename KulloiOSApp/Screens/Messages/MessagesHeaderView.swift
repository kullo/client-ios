/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */
//
//  MessagesHeaderView.swift
//  KulloiOSApp
//
//  Created by Daniel on 12.09.16.
//  Copyright © 2016 Kullo GmbH. All rights reserved.
//

import UIKit

class MessagesHeaderView: UIView {

    @IBOutlet var label: UILabel!

    override func layoutSubviews() {
        super.layoutSubviews()

        label.preferredMaxLayoutWidth = label.bounds.width
    }
}
