/* Copyright 2015 Kullo GmbH. All rights reserved. */

import LibKullo

class ClientCheckLoginListener : KAClientCheckLoginListener {

    weak var delegate: ClientCheckLoginDelegate?

    init(delegate: ClientCheckLoginDelegate) {
        self.delegate = delegate
    }

    @objc func finished(address: KAAddress?, masterKey: KAMasterKey?, valid: Bool) {
        dispatch_async(dispatch_get_main_queue()) {
            if valid {
                self.delegate?.checkLoginSuccess(address!, masterKey: masterKey!)
            } else {
                self.delegate?.checkLoginInvalid(address!, masterKey: masterKey!)
            }
        }
    }

    @objc func error(_address: KAAddress?, error: KANetworkError) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.checkLoginError(KulloConnector.getNetworkErrorText(error))
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

class SyncerRunListener : KASyncerRunListener {
    
    weak var kulloConnector: KulloConnector?

    init(kulloConnector: KulloConnector) {
        self.kulloConnector = kulloConnector
    }
    
    @objc func draftAttachmentsTooBig(convId: Int64) {
        dispatch_async(dispatch_get_main_queue()) {
            self.kulloConnector?.syncerRunListener_draftAttachmentsTooBig(convId)
        }
    }
    
    @objc func finished() {
        dispatch_async(dispatch_get_main_queue()) {
            self.kulloConnector?.syncerRunListener_finished()
        }
    }
    
    @objc func error(error: KANetworkError) {
        dispatch_async(dispatch_get_main_queue()) {
            self.kulloConnector?.syncerRunListener_error(error)
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
