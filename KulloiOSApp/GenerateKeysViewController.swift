/* Copyright 2015 Kullo GmbH. All rights reserved. */

import UIKit

class GenerateKeysViewController: UIViewController {

    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var progressView: UIProgressView!
    @IBOutlet var nextButton: UIBarButtonItem!
    @IBOutlet var pleaseWaitLabel: UILabel!

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        updateProgress(getProgress())
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        KulloConnector.sharedInstance.addGenerateKeysDelegate(self)
        KulloConnector.sharedInstance.startGenerateKeysIfNecessary()
        updateProgress(getProgress())
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)

        KulloConnector.sharedInstance.removeGenerateKeysDelegate(self)
    }

    func getProgress() -> Int8 {
        return KulloConnector.sharedInstance.getGenerateKeysProgress()
    }

    func updateProgress(progress: Int8) {
        log.debug("Key generation progress: \(progress)%")

        progressView.progress = Float(progress) / 100.0
        if progress < 100 {
            activityIndicator.startAnimating()
            nextButton.enabled = false
            pleaseWaitLabel.hidden = false
        }
        else {
            activityIndicator.stopAnimating()
            nextButton.enabled = true
            pleaseWaitLabel.hidden = true
        }
    }

}

extension GenerateKeysViewController : GenerateKeysDelegate {

    func generateKeysProgress(progress: Int8) {
        updateProgress(progress)
    }

    func generateKeysFinished() {
        updateProgress(100)
    }

}
