/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import HTAutocompleteTextField

class KulloAddressTextField: HTAutocompleteTextField {

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(
            self,
            name: UITextFieldTextDidChangeNotification,
            object: nil
        )
    }

    override func setupAutocompleteTextField() {
        super.setupAutocompleteTextField()

        autocompleteDataSource = self
        ignoreCase = true
        needsClearButtonSpace = true

        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: Selector("kulloAddrTextDidChange:"),
            name: UITextFieldTextDidChangeNotification,
            object: nil
        )
    }

    func kulloAddrTextDidChange(notification: NSNotification) {
        if let text = self.text, let rangeOfAtChar = text.rangeOfString("@") {
            self.text = text.stringByReplacingCharactersInRange(rangeOfAtChar, withString: "#")
            forceRefreshAutocompleteText()
        }
    }

}

extension KulloAddressTextField:  HTAutocompleteDataSource {

    func textField(textField: HTAutocompleteTextField!, completionForPrefix _prefix: String!, ignoreCase: Bool) -> String! {
        let prefix = ignoreCase ? _prefix.lowercaseString : _prefix

        // do nothing if there is no #
        guard let hashRange = prefix.rangeOfString("#") else {
            return ""
        }

        let domainPart = prefix.substringFromIndex(hashRange.endIndex)
        let completionDomain = "kullo.net"

        // return full completion if the # is the last char
        if hashRange.endIndex == prefix.endIndex {
            return completionDomain
        }

        // return a suffix of the completion if a prefix has already been typed
        if let alreadyTypedDomainChars = completionDomain.rangeOfString(domainPart) {
            if alreadyTypedDomainChars.startIndex == completionDomain.startIndex {
                return completionDomain.substringFromIndex(alreadyTypedDomainChars.endIndex)
            }
        }

        return ""
    }

}
