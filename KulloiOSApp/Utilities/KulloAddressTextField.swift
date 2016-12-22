/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import HTAutocompleteTextField

class KulloAddressTextField: HTAutocompleteTextField {

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.UITextFieldTextDidChange,
            object: nil
        )
    }

    override func setupAutocompleteTextField() {
        super.setupAutocompleteTextField()

        keyboardType = .twitter
        autocompleteDataSource = self
        ignoreCase = true
        needsClearButtonSpace = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kulloAddrTextDidChange),
            name: NSNotification.Name.UITextFieldTextDidChange,
            object: nil
        )
    }

    func kulloAddrTextDidChange(_ notification: Notification) {
        if var text = self.text {

            // trim whitespace
            text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            // replace @ by #
            if let rangeOfAtChar = text.range(of: "@") {
                text = text.replacingCharacters(in: rangeOfAtChar, with: "#")
            }

            if text != self.text {
                self.text = text
                forceRefreshAutocompleteText()
            }
        }
    }

}

extension KulloAddressTextField:  HTAutocompleteDataSource {

    func textField(_ textField: HTAutocompleteTextField!, completionForPrefix _prefix: String!, ignoreCase: Bool) -> String! {
        let prefix = ignoreCase ? _prefix.lowercased(): _prefix

        // do nothing if there is no #
        guard let hashRange = prefix?.range(of: "#") else {
            return ""
        }

        let domainPart = prefix?.substring(from: hashRange.upperBound)
        let completionDomain = "kullo.net"

        // return full completion if the # is the last char
        if hashRange.upperBound == prefix?.endIndex {
            return completionDomain
        }

        // return a suffix of the completion if a prefix has already been typed
        if let alreadyTypedDomainChars = completionDomain.range(of: domainPart!) {
            if alreadyTypedDomainChars.lowerBound == completionDomain.startIndex {
                return completionDomain.substring(from: alreadyTypedDomainChars.upperBound)
            }
        }

        return ""
    }

}
