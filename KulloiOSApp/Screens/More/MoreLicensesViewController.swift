/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit

class MoreLicensesViewController: UIViewController {
    @IBOutlet var webView: UIWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        webView.delegate = self

        let path = Bundle.main.path(forResource: "licenses", ofType: "html")
        let html = try! String(contentsOfFile: path!, encoding: String.Encoding.utf8)
        webView.loadHTMLString(html, baseURL: nil)
    }
}

extension MoreLicensesViewController: UIWebViewDelegate {

    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if let url = request.url {
            if navigationType == .linkClicked && (url.scheme == "http" || url.scheme == "https") {
                return !UIApplication.shared.openURL(url)
            }
        }
        return true
    }

}
