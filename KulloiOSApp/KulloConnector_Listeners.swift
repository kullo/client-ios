/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import LibKullo

class ClientGenerateKeysListener : KAClientGenerateKeysListener {

    weak var kulloConnector: KulloConnector?

    init(kulloConnector: KulloConnector) {
        self.kulloConnector = kulloConnector
    }

    @objc func progress(progress: Int8) {
        dispatch_async(dispatch_get_main_queue()) {
            self.kulloConnector?.generateKeys_progress(progress)
        }
    }

    @objc func finished(registration: KARegistration?) {
        dispatch_async(dispatch_get_main_queue()) {
            self.kulloConnector?.generateKeys_finished(registration!)
        }
    }

}

class RegisterAccountListener : KARegistrationRegisterAccountListener {

    weak var kulloConnector: KulloConnector?
    weak var delegate: RegisterAccountDelegate?

    init(kulloConnector: KulloConnector, delegate: RegisterAccountDelegate) {
        self.kulloConnector = kulloConnector
        self.delegate = delegate
    }

    @objc func challengeNeeded(address: KAAddress?, challenge: KAChallenge?) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.registerAccountChallengeNeeded(address!, challenge: challenge!)
        }
    }

    @objc func addressNotAvailable(address: KAAddress?, reason: KAAddressNotAvailableReason) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.registerAccountAddressNotAvailable(address!, reason: reason)
        }
    }

    @objc func finished(address: KAAddress?, masterKey: KAMasterKey?) {
        kulloConnector?.deleteGeneratedKeys()
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.registerAccountFinished(address!, masterKey: masterKey!)
        }
    }

    @objc func error(address: KAAddress?, error: KANetworkError) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.registerAccountError(KulloConnector.getNetworkErrorText(error))
        }
    }

}

class ClientCheckCredentialsListener : KAClientCheckCredentialsListener {

    weak var delegate: ClientCheckCredentialsDelegate?

    init(delegate: ClientCheckCredentialsDelegate) {
        self.delegate = delegate
    }

    @objc func finished(address: KAAddress?, masterKey: KAMasterKey?, valid: Bool) {
        dispatch_async(dispatch_get_main_queue()) {
            if valid {
                self.delegate?.checkCredentialsSuccess(address!, masterKey: masterKey!)
            } else {
                self.delegate?.checkCredentialsInvalid(address!, masterKey: masterKey!)
            }
        }
    }

    @objc func error(_address: KAAddress?, error: KANetworkError) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.checkCredentialsError(KulloConnector.getNetworkErrorText(error))
        }
    }

}

class ClientCreateSessionListener : KAClientCreateSessionListener {

    weak var delegate: ClientCreateSessionDelegate?

    init(delegate: ClientCreateSessionDelegate) {
        self.delegate = delegate
    }

    @objc func finished(session: KASession?) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.createSessionFinished(session!)
        }
    }

    @objc func error(address: KAAddress?, error: KALocalError) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.createSessionError(address!, error: KulloConnector.getLocalErrorText(error))
        }
    }
}

class SessionListener : KASessionListener {

    weak var kulloConnector: KulloConnector?

    init(kulloConnector: KulloConnector) {
        self.kulloConnector = kulloConnector
    }

    @objc func internalEvent(event: KAInternalEvent?) {
        dispatch_async(dispatch_get_main_queue()) {
            self.kulloConnector?.sessionListener_internalEvent(event)
        }
    }
}

class SyncerListener : KASyncerListener {
    
    weak var kulloConnector: KulloConnector?

    init(kulloConnector: KulloConnector) {
        self.kulloConnector = kulloConnector
    }

    @objc func started() {
        dispatch_async(dispatch_get_main_queue()) {
            self.kulloConnector?.syncerListener_started()
        }
    }
    
    @objc func draftAttachmentsTooBig(convId: Int64) {
        dispatch_async(dispatch_get_main_queue()) {
            self.kulloConnector?.syncerListener_draftAttachmentsTooBig(convId)
        }
    }

    @objc func progressed(progress: KASyncProgress) {
        dispatch_async(dispatch_get_main_queue()) {
            self.kulloConnector?.syncerListener_progressed(progress)
        }
    }

    @objc func finished() {
        dispatch_async(dispatch_get_main_queue()) {
            self.kulloConnector?.syncerListener_finished()
        }
    }
    
    @objc func error(error: KANetworkError) {
        dispatch_async(dispatch_get_main_queue()) {
            self.kulloConnector?.syncerListener_error(error)
        }
    }
    
}

class ClientAddressExistsListener : KAClientAddressExistsListener {

    weak var delegate: ClientAddressExistsDelegate?

    init(delegate: ClientAddressExistsDelegate) {
        self.delegate = delegate
    }
    
    @objc func finished(address: KAAddress?, exists: Bool) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.clientAddressExistsFinished(address!, exists: exists)
        }
    }
    
    @objc func error(address: KAAddress?, error: KANetworkError) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.clientAddressExistsError(address!, error: KulloConnector.getNetworkErrorText(error))
        }
    }
    
}

class MessageAttachmentsSaveToListener : KAMessageAttachmentsSaveToListener {
    
    weak var delegate: MessageAttachmentsSaveToDelegate?

    init(delegate: MessageAttachmentsSaveToDelegate) {
        self.delegate = delegate
    }
    
    @objc func finished(msgId: Int64, attId: Int64, path: String) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.messageAttachmentsSaveToFinished(msgId, attId: attId, path: path)
        }
    }
    
    @objc func error(msgId: Int64, attId: Int64, path: String, error: KALocalError) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.messageAttachmentsSaveToError(
                msgId,
                attId: attId,
                path: path,
                error: KulloConnector.getLocalErrorText(error)
            )
        }
    }

}

class DraftAttachmentsAddListener : KADraftAttachmentsAddListener {

    weak var delegate: DraftAttachmentsAddDelegate?

    init(delegate: DraftAttachmentsAddDelegate) {
        self.delegate = delegate
    }

    @objc func finished(convId: Int64, attId: Int64, path: String) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.draftAttachmentsAddFinished(convId, attId: attId, path: path)
        }
    }

    @objc func error(convId: Int64, path: String, error: KALocalError) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.draftAttachmentsAddError(
                convId,
                path: path,
                error: KulloConnector.getLocalErrorText(error)
            )
        }
    }

}

class DraftAttachmentsSaveToListener : KADraftAttachmentsSaveToListener {

    weak var delegate: DraftAttachmentsSaveToDelegate?

    init(delegate: DraftAttachmentsSaveToDelegate) {
        self.delegate = delegate
    }

    @objc func finished(msgId: Int64, attId: Int64, path: String) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.draftAttachmentsSaveToFinished(msgId, attId: attId, path: path)
        }
    }

    @objc func error(msgId: Int64, attId: Int64, path: String, error: KALocalError) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.draftAttachmentsSaveToError(
                msgId,
                attId: attId,
                path: path,
                error: KulloConnector.getLocalErrorText(error)
            )
        }
    }

}
