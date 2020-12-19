/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import MLPAutoCompleteTextField

class KulloAddressTextField: MLPAutoCompleteTextField {

    var includeDefaultKulloNetCompletion = false
    var excludedCompletions = Set<String>()

    private var addresses = [String]()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        keyboardType = .twitter
        clearButtonMode = .always
        autoCompleteDataSource = self
        autoCompleteDelegate = self
        autoCompleteTableAppearsAsKeyboardAccessory = true

        addresses = KulloConnector.shared.getAllAddresses().map({ $0.description() })

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kulloAddrTextDidChange),
            name: UITextField.textDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: UITextField.textDidChangeNotification,
            object: nil
        )
    }

    @objc private func kulloAddrTextDidChange(_ notification: Notification) {
        if var text = self.text {

            // trim whitespace
            text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            // replace @ by #
            if let rangeOfAtChar = text.range(of: "@") {
                text = text.replacingCharacters(in: rangeOfAtChar, with: "#")
            }

            if text != self.text {
                self.text = text
            }
        }
    }

    private func makeKulloNetCompletion(prefix: String) -> String? {
        guard !prefix.isEmpty else { return nil }

        let components = prefix.components(separatedBy: "#")
        let completionDomain = "kullo.net"

        switch components.count {
        case 1:
            return prefix + "#" + completionDomain

        case 2:
            let userPart = components[0]
            let domainPart = components[1]

            if completionDomain.hasPrefix(domainPart) {
                return userPart + "#" + completionDomain
            } else {
                return nil
            }

        default:
            return nil
        }
    }
}

extension KulloAddressTextField: MLPAutoCompleteTextFieldDataSource {
    func autoCompleteTextField(
        _ textField: MLPAutoCompleteTextField!,
        possibleCompletionsFor string: String!,
        completionHandler handler: (([Any]?) -> Void)!) {

        var suggestions = addresses.filter({
            $0.localizedCaseInsensitiveContains(string)
            && !self.excludedCompletions.contains($0)
        })
        if includeDefaultKulloNetCompletion,
            let kulloNetCompletion = makeKulloNetCompletion(prefix: string) {

            if !suggestions.contains(kulloNetCompletion) {
                suggestions.append(kulloNetCompletion)
            }
        }
        handler(suggestions)
    }
}

extension KulloAddressTextField: MLPAutoCompleteTextFieldDelegate {
    func autoCompleteTextField(
        _ textField: MLPAutoCompleteTextField!,
        didSelectAutoComplete selectedString: String!,
        withAutoComplete selectedObject: MLPAutoCompletionObject!,
        forRowAt indexPath: IndexPath!) {

        _ = textField.delegate?.textFieldShouldReturn?(textField)
    }
}
