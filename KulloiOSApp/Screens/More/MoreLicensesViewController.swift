/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit
import WebKit

class MoreLicensesViewController: UIViewController {
    private let webView = WKWebView()

    override func loadView() {
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Software licenses", comment: "")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        webView.navigationDelegate = self

        let licensesURL = Bundle.main.url(forResource: "licenses", withExtension: "html")!
        webView.load(URLRequest(url: licensesURL))
    }
}

extension MoreLicensesViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        if
            navigationAction.navigationType == .linkActivated,
            let url = navigationAction.request.url,
            url.scheme == "http" || url.scheme == "https" {
                let opened = !UIApplication.shared.openURL(url)
                decisionHandler(opened ? .cancel : .allow)
        } else {
            decisionHandler(.allow)
        }
    }
}
