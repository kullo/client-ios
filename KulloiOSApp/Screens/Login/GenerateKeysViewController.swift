/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import AudioToolbox
import UIKit

class GenerateKeysViewController: UIViewController {

    @IBOutlet var activeView: UIView!
    @IBOutlet var activeTopSpacing: NSLayoutConstraint!
    @IBOutlet var doneView: UIView!
    @IBOutlet var doneTopSpacing: NSLayoutConstraint!

    @IBOutlet var progressView: UIProgressView!
    private var nextButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        doneTopSpacing.constant = activeTopSpacing.constant

        nextButton = UIBarButtonItem(
            title: NSLocalizedString("Next", comment: ""), style: .plain,
            target: self, action: #selector(nextTapped))
        navigationItem.rightBarButtonItem = nextButton

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

    @objc private func nextTapped(_ sender: UIBarButtonItem) {
        let chooseAddressVC = StoryboardUtil.instantiate(ChooseAddressViewController.self)
        navigationController?.pushViewController(chooseAddressVC, animated: true)
    }

    private func getProgress() -> Int8 {
        return KulloConnector.shared.getGenerateKeysProgress()
    }

    private func updateProgress(_ progress: Int8) {
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
