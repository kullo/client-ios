/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import LibKullo

protocol RegisterAccountDelegate: class {
    func registerAccountChallengeNeeded(_ address: KAAddress, challenge: KAChallenge)
    func registerAccountAddressNotAvailable(_ address: KAAddress, reason: KAAddressNotAvailableReason)
    func registerAccountFinished(_ address: KAAddress, masterKey: KAMasterKey)
    func registerAccountError(_ error: String)
}

protocol ClientCheckCredentialsDelegate: class {
    func checkCredentialsSuccess(_ address: KAAddress, masterKey: KAMasterKey)
    func checkCredentialsInvalid(_ address: KAAddress, masterKey: KAMasterKey)
    func checkCredentialsError(_ error: String)
}

protocol SyncDelegate: class {
    func syncStarted()
    func syncProgressed()
    func syncDraftAttachmentsTooBig(_ convId: Int64)
    func syncFinished()
    func syncError(_ error: String)
}

protocol ClientAddressExistsDelegate: class {
    func clientAddressExistsFinished(_ address: KAAddress, exists: Bool)
    func clientAddressExistsError(_ address: KAAddress, error: String)
}

protocol MessageAttachmentsSaveToDelegate: class {
    func messageAttachmentsSaveToFinished(_ msgId: Int64, attId: Int64, path: String)
    func messageAttachmentsSaveToError(_ msgId: Int64, attId: Int64, path: String, error: String)
}

protocol DraftAttachmentsAddDelegate: class {
    func draftAttachmentsAddFinished(_ convId: Int64, attId: Int64, path: String)
    func draftAttachmentsAddError(_ convId: Int64, path: String, error: String)
}

protocol DraftAttachmentsSaveToDelegate: class {
    func draftAttachmentsSaveToFinished(_ convId: Int64, attId: Int64, path: String)
    func draftAttachmentsSaveToError(_ convId: Int64, attId: Int64, path: String, error: String)
}

protocol GenerateKeysDelegate: class {
    func generateKeysProgress(_ progress: Int8)
    func generateKeysFinished()
}

protocol SessionEventsDelegate: class {
    func sessionEventMigrationStarted()
    func sessionEventSessionCreated()
    func sessionEventConversationAdded(_ convId: Int64)
    func sessionEventConversationChanged(_ convId: Int64)
    func sessionEventConversationRemoved(_ convId: Int64)
    func sessionEventDraftStateChanged(_ convId: Int64)
    func sessionEventDraftTextChanged(_ convId: Int64)
    func sessionEventDraftAttachmentAdded(_ convId: Int64)
    func sessionEventDraftAttachmentRemoved(_ convId: Int64)
    func sessionEventMessageAdded(_ convId: Int64, msgId: Int64)
    func sessionEventMessageDeliveryChanged(_ convId: Int64, msgId: Int64)
    func sessionEventMessageStateChanged(_ convId: Int64, msgId: Int64)
    func sessionEventMessageAttachmentsDownloadedChanged(_ convId: Int64, msgId: Int64)
    func sessionEventMessageRemoved(_ convId: Int64, msgId: Int64)
}

extension SessionEventsDelegate {
    func sessionEventMigrationStarted() {}
    func sessionEventSessionCreated() {}
    func sessionEventConversationAdded(_ convId: Int64) {}
    func sessionEventConversationChanged(_ convId: Int64) {}
    func sessionEventConversationRemoved(_ convId: Int64) {}
    func sessionEventDraftStateChanged(_ convId: Int64) {}
    func sessionEventDraftTextChanged(_ convId: Int64) {}
    func sessionEventDraftAttachmentAdded(_ convId: Int64) {}
    func sessionEventDraftAttachmentRemoved(_ convId: Int64) {}
    func sessionEventMessageAdded(_ convId: Int64, msgId: Int64) {}
    func sessionEventMessageDeliveryChanged(_ convId: Int64, msgId: Int64) {}
    func sessionEventMessageStateChanged(_ convId: Int64, msgId: Int64) {}
    func sessionEventMessageAttachmentsDownloadedChanged(_ convId: Int64, msgId: Int64) {}
    func sessionEventMessageRemoved(_ convId: Int64, msgId: Int64) {}
}
