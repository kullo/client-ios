/* Copyright 2015 Kullo GmbH. All rights reserved. */

import UIKit

class MoreLicensesViewController: UIViewController {
    @IBOutlet var webView: UIWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        webView.delegate = self

        let path = NSBundle.mainBundle().pathForResource("licenses", ofType: "html")
        let html = try! String(contentsOfFile: path!, encoding: NSUTF8StringEncoding)
        webView.loadHTMLString(html as String, baseURL: nil)
    }
}

extension MoreLicensesViewController: UIWebViewDelegate {

    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if let url = request.URL {
            if navigationType == .LinkClicked && (url.scheme == "http" || url.scheme == "https") {
                return !UIApplication.sharedApplication().openURL(url)
            }
        }
        return true
    }

}
