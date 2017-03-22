/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

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
        nextButton.isEnabled = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateProgress(getProgress())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        KulloConnector.shared.addGenerateKeysDelegate(self)
        KulloConnector.shared.startGenerateKeysIfNecessary()
        updateProgress(getProgress())
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        KulloConnector.shared.removeGenerateKeysDelegate(self)
    }

    func getProgress() -> Int8 {
        return KulloConnector.shared.getGenerateKeysProgress()
    }

    func updateProgress(_ progress: Int8) {
        log.debug("Key generation progress: \(progress)%")

        progressView.progress = Float(progress) / 100.0

        let done = progress >= 100

        if done != nextButton.isEnabled {
            UIView.transition(
                with: view,
                duration: 0.4,
                options: [.transitionCrossDissolve, .allowAnimatedContent],
                animations: {
                    self.nextButton.isEnabled = done
                    self.activeView.isHidden = done
                    self.doneView.isHidden = !done
                },
                completion: nil)
        }
    }

}

extension GenerateKeysViewController: GenerateKeysDelegate {

    func generateKeysProgress(_ progress: Int8) {
        updateProgress(progress)
    }

    func generateKeysFinished() {
        updateProgress(100)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

}
