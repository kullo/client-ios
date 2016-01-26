/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import AudioToolbox
import UIKit

class GenerateKeysViewController: UIViewController {

    @IBOutlet var activeView: UIView!
    @IBOutlet var activeTopSpacing: NSLayoutConstraint!
    @IBOutlet var doneView: UIView!
    @IBOutlet var doneTopSpacing: NSLayoutConstraint!

    @IBOutlet var progressView: UIProgressView!
    @IBOutlet var nextButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        doneTopSpacing.constant = activeTopSpacing.constant

        // Necessary because otherwise, when waiting for completion, then going back and finally
        // re-entering this view, "Next" is already enabled.
        nextButton.enabled = false
    }

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

        let done = progress >= 100

        if done != nextButton.enabled {
            UIView.transitionWithView(
                view,
                duration: 0.4,
                options: [.TransitionCrossDissolve, .AllowAnimatedContent],
                animations: {
                    self.nextButton.enabled = done
                    self.activeView.hidden = done
                    self.doneView.hidden = !done
                },
                completion: nil)
        }
    }

}

extension GenerateKeysViewController : GenerateKeysDelegate {

    func generateKeysProgress(progress: Int8) {
        updateProgress(progress)
    }

    func generateKeysFinished() {
        updateProgress(100)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

}
