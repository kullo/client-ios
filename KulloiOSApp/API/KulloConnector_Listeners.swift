/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import LibKullo

class ClientGenerateKeysListener: KAClientGenerateKeysListener {

    weak var kulloConnector: KulloConnector?

    init(kulloConnector: KulloConnector) {
        self.kulloConnector = kulloConnector
    }

    @objc func progress(_ progress: Int8) {
        DispatchQueue.main.async {
            self.kulloConnector?.generateKeys_progress(progress)
        }
    }

    @objc func finished(_ registration: KARegistration) {
        DispatchQueue.main.async {
            self.kulloConnector?.generateKeys_finished(registration)
        }
    }

}

class RegisterAccountListener: KARegistrationRegisterAccountListener {

    weak var kulloConnector: KulloConnector?
    weak var delegate: RegisterAccountDelegate?

    init(kulloConnector: KulloConnector, delegate: RegisterAccountDelegate) {
        self.kulloConnector = kulloConnector
        self.delegate = delegate
    }

    @objc func challengeNeeded(_ address: KAAddress, challenge: KAChallenge) {
        DispatchQueue.main.async {
            self.delegate?.registerAccountChallengeNeeded(address, challenge: challenge)
        }
    }

    @objc func addressNotAvailable(_ address: KAAddress, reason: KAAddressNotAvailableReason) {
        DispatchQueue.main.async {
            self.delegate?.registerAccountAddressNotAvailable(address, reason: reason)
        }
    }

    @objc func finished(_ address: KAAddress, masterKey: KAMasterKey) {
        kulloConnector?.deleteGeneratedKeys()
        DispatchQueue.main.async {
            self.delegate?.registerAccountFinished(address, masterKey: masterKey)
        }
    }

    @objc func error(_ address: KAAddress, error: KANetworkError) {
        DispatchQueue.main.async {
            self.delegate?.registerAccountError(error.message)
        }
    }

}

class ClientCheckCredentialsListener: KAClientCheckCredentialsListener {

    weak var delegate: ClientCheckCredentialsDelegate?

    init(delegate: ClientCheckCredentialsDelegate) {
        self.delegate = delegate
    }

    @objc func finished(_ address: KAAddress, masterKey: KAMasterKey, valid: Bool) {
        DispatchQueue.main.async {
            if valid {
                self.delegate?.checkCredentialsSuccess(address, masterKey: masterKey)
            } else {
                self.delegate?.checkCredentialsInvalid(address, masterKey: masterKey)
            }
        }
    }

    @objc func error(_ _address: KAAddress, error: KANetworkError) {
        DispatchQueue.main.async {
            self.delegate?.checkCredentialsError(error.message)
        }
    }

}

typealias CreateSessionCompletionHandler = (_ address: KAAddress, _ error: String?) -> ()

class ClientCreateSessionListener: KAClientCreateSessionListener {
    weak var kulloConnector: KulloConnector?
    var completion: CreateSessionCompletionHandler

    init(kulloConnector: KulloConnector, completion: @escaping CreateSessionCompletionHandler) {
        self.kulloConnector = kulloConnector
        self.completion = completion
    }

    @objc func migrationStarted(_ address: KAAddress) {
        DispatchQueue.main.async {
            self.kulloConnector?.createSessionListener_migrationStarted()
        }
    }

    @objc func finished(_ session: KASession) {
        DispatchQueue.main.async {
            self.kulloConnector?.setSession(session)
            self.completion(session.userSettings().address(), nil)
        }
    }

    @objc func error(_ address: KAAddress, error: KALocalError) {
        DispatchQueue.main.async {
            self.completion(address, error.message)
        }
    }
}

class SessionListener: KASessionListener {

    weak var kulloConnector: KulloConnector?

    init(kulloConnector: KulloConnector) {
        self.kulloConnector = kulloConnector
    }

    @objc func internalEvent(_ event: KAInternalEvent) {
        DispatchQueue.main.async {
            self.kulloConnector?.sessionListener_internalEvent(event)
        }
    }
}

class SessionAccountInfoListener: KASessionAccountInfoListener {
    private let completion: (KAAccountInfo) -> Void

    init(completion: @escaping (KAAccountInfo) -> Void) {
        self.completion = completion
    }

    @objc func finished(_ accountInfo: KAAccountInfo) {
        completion(accountInfo)
    }

    @objc func error(_ error: KANetworkError) {
        log.error("Error retrieving account info: \(error)")
    }
}

class SyncerListener: KASyncerListener {
    
    weak var kulloConnector: KulloConnector?

    init(kulloConnector: KulloConnector) {
        self.kulloConnector = kulloConnector
    }

    @objc func started() {
        DispatchQueue.main.async {
            self.kulloConnector?.syncerListener_started()
        }
    }
    
    @objc func draftPartTooBig(_ convId: Int64, part: KADraftPart, currentSize: Int64, maxSize: Int64) {
        DispatchQueue.main.async {
            self.kulloConnector?.syncerListener_draftPartTooBig(convId, part: part, currentSize: currentSize, maxSize: maxSize)
        }
    }

    @objc func progressed(_ progress: KASyncProgress) {
        DispatchQueue.main.async {
            self.kulloConnector?.syncerListener_progressed(progress)
        }
    }

    @objc func finished() {
        DispatchQueue.main.async {
            self.kulloConnector?.syncerListener_finished()
        }
    }
    
    @objc func error(_ error: KANetworkError) {
        DispatchQueue.main.async {
            self.kulloConnector?.syncerListener_error(error)
        }
    }
    
}

class ClientAddressExistsListener: KAClientAddressExistsListener {

    weak var delegate: ClientAddressExistsDelegate?

    init(delegate: ClientAddressExistsDelegate) {
        self.delegate = delegate
    }
    
    @objc func finished(_ address: KAAddress, exists: Bool) {
        DispatchQueue.main.async {
            self.delegate?.clientAddressExistsFinished(address, exists: exists)
        }
    }
    
    @objc func error(_ address: KAAddress, error: KANetworkError) {
        DispatchQueue.main.async {
            self.delegate?.clientAddressExistsError(address, error: error.message)
        }
    }
    
}

class MessageAttachmentsSaveToListener: KAMessageAttachmentsSaveToListener {
    
    weak var delegate: MessageAttachmentsSaveToDelegate?

    init(delegate: MessageAttachmentsSaveToDelegate) {
        self.delegate = delegate
    }
    
    @objc func finished(_ msgId: Int64, attId: Int64, path: String) {
        DispatchQueue.main.async {
            self.delegate?.messageAttachmentsSaveToFinished(msgId, attId: attId, path: path)
        }
    }
    
    @objc func error(_ msgId: Int64, attId: Int64, path: String, error: KALocalError) {
        DispatchQueue.main.async {
            self.delegate?.messageAttachmentsSaveToError(
                msgId,
                attId: attId,
                path: path,
                error: error.message
            )
        }
    }

}

class DraftAttachmentsAddListener: KADraftAttachmentsAddListener {

    weak var delegate: DraftAttachmentsAddDelegate?

    init(delegate: DraftAttachmentsAddDelegate) {
        self.delegate = delegate
    }

    @objc func progressed(_ convId: Int64, attId: Int64, bytesProcessed: Int64, bytesTotal: Int64) {
        //TODO implement
    }

    @objc func finished(_ convId: Int64, attId: Int64, path: String) {
        DispatchQueue.main.async {
            self.delegate?.draftAttachmentsAddFinished(convId, attId: attId, path: path)
        }
    }

    @objc func error(_ convId: Int64, path: String, error: KALocalError) {
        DispatchQueue.main.async {
            self.delegate?.draftAttachmentsAddError(
                convId,
                path: path,
                error: error.message
            )
        }
    }

}

class MessagesSearchListener: KAMessagesSearchListener {
    private let completion: ([KAMessagesSearchResult]) -> Void

    init(completion: @escaping ([KAMessagesSearchResult]) -> Void) {
        self.completion = completion
    }

    func finished(_ results: [KAMessagesSearchResult]) {
        DispatchQueue.main.async {
            self.completion(results)
        }
    }
}

class DraftAttachmentsSaveToListener: KADraftAttachmentsSaveToListener {

    weak var delegate: DraftAttachmentsSaveToDelegate?

    init(delegate: DraftAttachmentsSaveToDelegate) {
        self.delegate = delegate
    }

    @objc func finished(_ msgId: Int64, attId: Int64, path: String) {
        DispatchQueue.main.async {
            self.delegate?.draftAttachmentsSaveToFinished(msgId, attId: attId, path: path)
        }
    }

    @objc func error(_ msgId: Int64, attId: Int64, path: String, error: KALocalError) {
        DispatchQueue.main.async {
            self.delegate?.draftAttachmentsSaveToError(
                msgId,
                attId: attId,
                path: path,
                error: error.message
            )
        }
    }

}
