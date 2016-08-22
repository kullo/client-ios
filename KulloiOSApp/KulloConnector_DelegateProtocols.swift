/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import LibKullo

protocol RegisterAccountDelegate: class {
    func registerAccountChallengeNeeded(address: KAAddress, challenge: KAChallenge)
    func registerAccountAddressNotAvailable(address: KAAddress, reason: KAAddressNotAvailableReason)
    func registerAccountFinished(address: KAAddress, masterKey: KAMasterKey)
    func registerAccountError(error: String)
}

protocol ClientCheckCredentialsDelegate: class {
    func checkCredentialsSuccess(address: KAAddress, masterKey: KAMasterKey)
    func checkCredentialsInvalid(address: KAAddress, masterKey: KAMasterKey)
    func checkCredentialsError(error: String)
}

protocol SyncDelegate: class {
    func syncStarted()
    func syncProgressed()
    func syncDraftAttachmentsTooBig(convId: Int64)
    func syncFinished()
    func syncError(error: String)
}

protocol ClientAddressExistsDelegate: class {
    func clientAddressExistsFinished(address: KAAddress, exists: Bool)
    func clientAddressExistsError(address: KAAddress, error: String)
}

protocol MessageAttachmentsSaveToDelegate: class {
    func messageAttachmentsSaveToFinished(msgId: Int64, attId: Int64, path: String)
    func messageAttachmentsSaveToError(msgId: Int64, attId: Int64, path: String, error: String)
}

protocol DraftAttachmentsAddDelegate: class {
    func draftAttachmentsAddFinished(convId: Int64, attId: Int64, path: String)
    func draftAttachmentsAddError(convId: Int64, path: String, error: String)
}

protocol DraftAttachmentsSaveToDelegate: class {
    func draftAttachmentsSaveToFinished(convId: Int64, attId: Int64, path: String)
    func draftAttachmentsSaveToError(convId: Int64, attId: Int64, path: String, error: String)
}

protocol GenerateKeysDelegate: class {
    func generateKeysProgress(progress: Int8)
    func generateKeysFinished()
}

protocol SessionEventsDelegate: class {
    func sessionEventSessionCreated()
    func sessionEventConversationAdded(convId: Int64)
    func sessionEventConversationChanged(convId: Int64)
    func sessionEventConversationRemoved(convId: Int64)
    func sessionEventDraftStateChanged(convId: Int64)
    func sessionEventDraftTextChanged(convId: Int64)
    func sessionEventDraftAttachmentAdded(convId: Int64)
    func sessionEventDraftAttachmentRemoved(convId: Int64)
    func sessionEventMessageAdded(convId: Int64, msgId: Int64)
    func sessionEventMessageDeliveryChanged(convId: Int64, msgId: Int64)
    func sessionEventMessageStateChanged(convId: Int64, msgId: Int64)
    func sessionEventMessageAttachmentsDownloadedChanged(convId: Int64, msgId: Int64)
    func sessionEventMessageRemoved(convId: Int64, msgId: Int64)
}

extension SessionEventsDelegate {
    func sessionEventSessionCreated() {}
    func sessionEventConversationAdded(convId: Int64) {}
    func sessionEventConversationChanged(convId: Int64) {}
    func sessionEventConversationRemoved(convId: Int64) {}
    func sessionEventDraftStateChanged(convId: Int64) {}
    func sessionEventDraftTextChanged(convId: Int64) {}
    func sessionEventDraftAttachmentAdded(convId: Int64) {}
    func sessionEventDraftAttachmentRemoved(convId: Int64) {}
    func sessionEventMessageAdded(convId: Int64, msgId: Int64) {}
    func sessionEventMessageDeliveryChanged(convId: Int64, msgId: Int64) {}
    func sessionEventMessageStateChanged(convId: Int64, msgId: Int64) {}
    func sessionEventMessageAttachmentsDownloadedChanged(convId: Int64, msgId: Int64) {}
    func sessionEventMessageRemoved(convId: Int64, msgId: Int64) {}
}
