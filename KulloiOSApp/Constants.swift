/* Copyright 2015 Kullo GmbH. All rights reserved. */

import UIKit

let testingPrefillAddress: String? = nil
let testingPrefillMasterKey: [String]? = nil

let kulloWebsiteAddress = "https://www.kullo.net"
let feedbackAddress = "hi#kullo.net"

// MARK: Avatar

let fontAvatarInitials = "Helvetica"
let fontSizeAvatarInitials : CGFloat = 26.0
let colorAvatarInitials : UIColor = UIColor.whiteColor()

let avatarDimension : CGFloat = 200.0;
let avatarMaxSize = 24*1024;
let avatarBestQuality : CGFloat = 0.96;
let avatarQualityDownsamplingSteps : CGFloat = 0.2;

// MARK: Color

let colorAccent : UIColor = UIColor(hex: "#009F95")
let colorOrangeDark : UIColor = UIColor(hex: "#E88D03")

let colorTextFieldText : UIColor = colorAccent
let colorTextFieldBG : UIColor = UIColor.whiteColor()
let colorTextFieldErrorBG : UIColor = UIColor.redColor()
let colorTextFieldErrorText : UIColor = UIColor.whiteColor()

// MARK: Textsize Message

let textSizeMessage : CGFloat = 14.0

// MARK: segues

let showMessageSegueIdentifier = "ShowMessageSegue"
let composeMessageSegueIdentifier = "MessagesComposeMessageSegue"
