/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import LibKullo
import SwiftyMimeTypes
import UIKit
import XCGLogger

struct Credentials {
    let address: KAAddress
    let masterKey: KAMasterKey
}

class KulloConnector {

    typealias VersionTuple = (component: String, version: String)

    static let sharedInstance = KulloConnector()

    private(set) var accountInfo: KAAccountInfo?

    private let client: KAClient
    private var session: KASession?
    private var storage: StorageManager?

    private var generateKeysTask: KAAsyncTask?
    private var registerAccountTask: KAAsyncTask?
    private var checkCredentialsTask: KAAsyncTask?
    private var registerPushTokenTask: KAAsyncTask?
    private var unregisterPushTokenTask: KAAsyncTask?
    private var accountInfoTask: KAAsyncTask?
    private var createSessionTask: KAAsyncTask?
    private var clientAddressExistsTask: KAAsyncTask?
    private var addAttachmentTask: KAAsyncTask?
    private var messageAttachmentsSaveToTask: KAAsyncTask?
    private var draftAttachmentsSaveToTask: KAAsyncTask?

    private enum SessionState { case none, creating, created }
    private var sessionState = SessionState.none {
        didSet {
            log.debug("sessionState: \(oldValue) -> \(self.sessionState)")
        }
    }

    private var generateKeysProgress: Int8 = 0
    private var registration: KARegistration?
    private var pushToken: String?
    private var pushTokenRegistered = false
    private var syncProgress: KASyncProgress?
    private var sessionCreationSuccessHandlers = [() -> Void]()
    private var sessionCreationErrorHandlers = [(String) -> Void]()

    typealias FetchCompletionHandler = (UIBackgroundFetchResult) -> Void
    private var fetchCompletionHandlers = [FetchCompletionHandler]()

    // MARK: delegates

    //FIXME: make weak
    private var generateKeysDelegates = [GenerateKeysDelegate]()
    private var syncDelegates = [SyncDelegate]()
    private var sessionEventsDelegates = [SessionEventsDelegate]()

    // MARK: initialization

    private init() {
        client = KAClient.create()!
        log.info("\(self.client.versions())")
    }

    // MARK: Login

    func waitForSession(
        onSuccess: @escaping () -> Void,
        onCredentialsMissing: @escaping () -> Void,
        onError: @escaping (_ error: String) -> Void) {

        log.debug("State: \(self.sessionState)")
        switch sessionState {
        case .created:
            onSuccess()

        case .creating:
            sessionCreationSuccessHandlers.append(onSuccess)
            sessionCreationErrorHandlers.append(onError)

        case .none:
            guard let address = StorageManager.getLastUserAddress() else {
                log.debug("Couldn't find last user address")
                onCredentialsMissing()
                return
            }

            storage = StorageManager(address: address)
            guard let credentials = storage?.loadCredentials() else {
                log.debug("Couldn't find credentials for \(address.toString())")
                onCredentialsMissing()
                return
            }

            sessionCreationSuccessHandlers.append(onSuccess)
            sessionCreationErrorHandlers.append(onError)
            createSession(credentials: credentials) { _, error in
                if let error = error {
                    for errorHandler in self.sessionCreationErrorHandlers {
                        errorHandler(error)
                    }
                } else {
                    for successHandler in self.sessionCreationSuccessHandlers {
                        successHandler()
                    }
                }
                self.sessionCreationErrorHandlers.removeAll()
                self.sessionCreationSuccessHandlers.removeAll()
            }
        }
    }

    func checkCredentials(_ address: String, masterKeyBlocks: [String], delegate: ClientCheckCredentialsDelegate) {
        log.info("Logging in with address \(address)")

        if let kaAddress = KAAddress.create(address),
            let kaMasterKey = KAMasterKey.create(fromDataBlocks: masterKeyBlocks) {

            checkCredentialsTask = client.checkCredentialsAsync(
                kaAddress,
                masterKey: kaMasterKey,
                listener: ClientCheckCredentialsListener(delegate: delegate))
        }
    }

    class func isValidKulloAddress(_ address: String) -> Bool {
        return (KAAddress.create(address) != nil)
    }

    class func isValidMasterKeyBlock(_ block: String) -> Bool {
        return KAMasterKey.isValidBlock(block)
    }

    // MARK: Logout

    func logout() {
        log.info("Logging out user.")

        unregisterPushToken()
        unregisterPushTokenTask?.wait(forMs: 2000)

        closeSession()
        storage!.deleteAllData()
        storage = nil

        log.info("User logged out.")
    }

    //MARK: Session

    private func createSession(
        credentials: Credentials,
        completion: @escaping CreateSessionCompletionHandler) {

        precondition(sessionState == .none)

        if storage == nil || storage!.userAddress != credentials.address {
            storage = StorageManager(address: credentials.address)
        }

        sessionState = .creating
        createSessionTask = client.createSessionAsync(
            credentials.address,
            masterKey: credentials.masterKey,
            dbFilePath: storage!.getDbPath(),
            sessionListener: SessionListener(kulloConnector: self),
            listener: ClientCreateSessionListener(kulloConnector: self, completion: {
                address, error in
                self.sessionState = .created
                completion(address, error)
            }))
    }

    func setSession(_ session: KASession) {
        precondition(sessionState == .creating)

        self.session = session
        self.session?.syncer()?.setListener(SyncerListener(kulloConnector: self))

        guard let userSettings = self.session?.userSettings() else {
            preconditionFailure("session must have userSettings")
        }
        guard let storage = storage else {
            preconditionFailure("there must be a storage instance at this point")
        }

        storage.migrateUserSettings(userSettings)
        if userSettings.name().isEmpty {
            userSettings.setName((userSettings.address()?.localPart()) ?? "")
        }

        sessionEventsDelegates.forEach { $0.sessionEventSessionCreated() }

        if let pushToken = pushToken {
            registerPushToken(pushToken)
        }
    }

    func closeSession() {
        UIApplication.shared.isIdleTimerDisabled = false
        UIApplication.shared.isNetworkActivityIndicatorVisible = false

        // Make sure all async tasks are done.
        // We cancel all tasks before waiting so that they can finish in parallel.
        session?.syncer()?.cancel()
        generateKeysTask?.cancel()
        registerAccountTask?.cancel()
        checkCredentialsTask?.cancel()
        registerPushTokenTask?.cancel()
        unregisterPushTokenTask?.cancel()
        accountInfoTask?.cancel()
        createSessionTask?.cancel()
        clientAddressExistsTask?.cancel()
        addAttachmentTask?.cancel()
        messageAttachmentsSaveToTask?.cancel()
        draftAttachmentsSaveToTask?.cancel()

        session?.syncer()?.waitUntilDone()
        generateKeysTask?.waitUntilDone()
        registerAccountTask?.waitUntilDone()
        checkCredentialsTask?.waitUntilDone()
        registerPushTokenTask?.waitUntilDone()
        unregisterPushTokenTask?.waitUntilDone()
        accountInfoTask?.waitUntilDone()
        createSessionTask?.waitUntilDone()
        clientAddressExistsTask?.waitUntilDone()
        addAttachmentTask?.waitUntilDone()
        messageAttachmentsSaveToTask?.waitUntilDone()
        draftAttachmentsSaveToTask?.waitUntilDone()

        sessionState = .none
        session = nil
    }

    private func makeKAPushToken(_ pushToken: String) -> KAPushToken {
        return KAPushToken(type: .GCM, token: pushToken, environment: .IOS)
    }

    func registerPushToken(_ pushToken: String) {
        if self.pushToken != pushToken {
            self.pushToken = pushToken
            pushTokenRegistered = false
        }
        if !pushTokenRegistered, let session = session {
            registerPushTokenTask = session.register(makeKAPushToken(pushToken))
            pushTokenRegistered = true
        }
    }

    func unregisterPushToken() {
        if let pushToken = pushToken {
            unregisterPushTokenTask = session?.unregisterPushToken(makeKAPushToken(pushToken))
            pushTokenRegistered = false
        }
    }

    func getAccountInfo(completion: @escaping () -> Void) {
        accountInfoTask = session?.accountInfoAsync(
            SessionAccountInfoListener(completion: { [weak self] accountInfo in
                DispatchQueue.main.async {
                    guard let strongSelf = self else { return }

                    strongSelf.accountInfo = accountInfo
                    completion()
                }
            }))
    }

    //MARK: Update/Store/Load/Remove user settings

    func saveCredentials(_ address: KAAddress, masterKey: KAMasterKey) {
        StorageManager(address: address).saveCredentials(address, masterKey: masterKey)
    }

    //MARK: Registration

    func addGenerateKeysDelegate(_ delegate: GenerateKeysDelegate) {
        generateKeysDelegates.append(delegate)
    }

    func removeGenerateKeysDelegate(_ delegate: GenerateKeysDelegate) {
        generateKeysDelegates = generateKeysDelegates.filter { $0 !== delegate }
    }

    func getGenerateKeysProgress() -> Int8 {
        return generateKeysProgress
    }

    func startGenerateKeysIfNecessary() {
        let generateKeysNotRunning = generateKeysTask == nil || generateKeysTask!.isDone()
        if registration == nil && generateKeysNotRunning {
            UIApplication.shared.isIdleTimerDisabled = true
            generateKeysTask = client.generateKeysAsync(ClientGenerateKeysListener(kulloConnector: self))
        }
    }

    func generateKeys_progress(_ progress: Int8) {
        generateKeysProgress = progress
        for delegate in generateKeysDelegates {
            delegate.generateKeysProgress(progress)
        }
    }

    func generateKeys_finished(_ registration: KARegistration) {
        UIApplication.shared.isIdleTimerDisabled = false

        self.registration = registration
        for delegate in generateKeysDelegates {
            delegate.generateKeysFinished()
        }
    }

    func registerAccount(_ address: KAAddress, delegate: RegisterAccountDelegate) {
        if let registration = registration {
            registerAccountTask = registration.registerAccountAsync(
                address,
                acceptedTerms: kulloTermsAndConditions,
                challenge: nil,
                challengeAnswer: "",
                listener: RegisterAccountListener(kulloConnector: self, delegate: delegate)
            )
        }
    }

    func deleteGeneratedKeys() {
        generateKeysProgress = 0
        generateKeysTask = nil
        registration = nil
    }

    //MARK: Session events
    
    func createSessionListener_migrationStarted() {
        sessionEventsDelegates.forEach { $0.sessionEventMigrationStarted() }
    }

    func addSessionEventsDelegate(_ delegate: SessionEventsDelegate) {
        sessionEventsDelegates.append(delegate)
    }

    func removeSessionEventsDelegate(_ delegate: SessionEventsDelegate) {
        sessionEventsDelegates = sessionEventsDelegates.filter { $0 !== delegate }
    }

    func sessionListener_internalEvent(_ event: KAInternalEvent?) {
        for event in session?.notify(event) ?? [] {
            for delegate in sessionEventsDelegates {
                switch event.event {
                case .conversationAdded:
                    delegate.sessionEventConversationAdded(event.conversationId)
                case .conversationChanged:
                    delegate.sessionEventConversationChanged(event.conversationId)
                case .conversationRemoved:
                    delegate.sessionEventConversationRemoved(event.conversationId)
                case .draftStateChanged:
                    delegate.sessionEventDraftStateChanged(event.conversationId)
                case .draftTextChanged:
                    delegate.sessionEventDraftTextChanged(event.conversationId)
                case .draftAttachmentAdded:
                    delegate.sessionEventDraftAttachmentAdded(event.conversationId)
                case .draftAttachmentRemoved:
                    delegate.sessionEventDraftAttachmentRemoved(event.conversationId)
                case .messageAdded:
                    delegate.sessionEventMessageAdded(event.conversationId, msgId: event.messageId)
                case .messageDeliveryChanged:
                    delegate.sessionEventMessageDeliveryChanged(event.conversationId, msgId: event.messageId)
                case .messageStateChanged:
                    delegate.sessionEventMessageStateChanged(event.conversationId, msgId: event.messageId)
                case .messageAttachmentsDownloadedChanged:
                    delegate.sessionEventMessageAttachmentsDownloadedChanged(event.conversationId, msgId: event.messageId)
                case .messageRemoved:
                    delegate.sessionEventMessageRemoved(event.conversationId, msgId: event.messageId)
                case .latestSenderChanged:
                    break //FIXME: implement
                }
            }
        }
    }

    // MARK: Synchronization

    func addSyncDelegate(_ delegate: SyncDelegate) {
        syncDelegates.append(delegate)
    }

    func removeSyncDelegate(_ delegate: SyncDelegate) {
        syncDelegates = syncDelegates.filter { $0 !== delegate }
    }

    func sync(_ syncMode: KASyncMode, completionHandler: ((UIBackgroundFetchResult) -> Void)? = nil) {
        if let completionHandler = completionHandler {
            fetchCompletionHandlers.append(completionHandler)
        }
        session?.syncer()?.requestSync(syncMode)
    }

    func syncIfNecessary() {
        guard let lastFullSync = session?.syncer()?.lastFullSync() else {
            sync(.withoutAttachments)
            return
        }
        if abs(lastFullSync.toDate().timeIntervalSinceNow) > secondsBetweenSyncs {
            sync(.withoutAttachments)
        }
    }

    func isSyncRunning() -> Bool {
        return session?.syncer()?.isSyncing() ?? false
    }

    func getSyncProgress() -> Float {
        guard let syncProgress = syncProgress,
            syncProgress.incomingMessagesTotal > 0 else {
                return 0
        }
        return Float(syncProgress.incomingMessagesProcessed)
            / Float(syncProgress.incomingMessagesTotal)
    }

    func getAttachmentDownloadProgress() -> Float {
        guard let syncProgress = syncProgress,
            syncProgress.incomingAttachmentsTotalBytes > 0 else {
                return 0
        }
        return Float(syncProgress.incomingAttachmentsDownloadedBytes)
            / Float(syncProgress.incomingAttachmentsTotalBytes)
    }

    func getSendingProgress() -> Float {
        guard let syncProgress = syncProgress,
            syncProgress.outgoingMessagesTotalBytes > 0 else {
            return 0
        }
        return Float(syncProgress.outgoingMessagesUploadedBytes)
            / Float(syncProgress.outgoingMessagesTotalBytes)
    }

    func syncerListener_started() {
        UIApplication.shared.isIdleTimerDisabled = true
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        for delegate in syncDelegates {
            delegate.syncStarted()
        }
    }

    func syncerListener_progressed(_ progress: KASyncProgress) {
        syncProgress = progress
        for delegate in syncDelegates {
            delegate.syncProgressed()
        }
    }

    func syncerListener_draftPartTooBig(_ convId: Int64, part: KADraftPart, currentSize: Int64, maxSize: Int64) {
        for delegate in syncDelegates {
            //TODO generalize delegate method
            delegate.syncDraftAttachmentsTooBig(convId)
        }
    }

    func syncComplete() {
        for handler in fetchCompletionHandlers {
            log.debug("calling fetchCompletionHandler with .newData")
            handler(.newData)
        }
        fetchCompletionHandlers.removeAll()
        UIApplication.shared.isIdleTimerDisabled = false
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }

    func syncerListener_finished() {
        syncComplete()
        for delegate in syncDelegates {
            delegate.syncFinished()
        }
    }
    
    func syncerListener_error(_ error: KANetworkError) {
        syncComplete()
        for delegate in syncDelegates {
            delegate.syncError(error.message)
        }
    }

    
    // MARK: Conversations
    
    func getAllConversationIdsSorted() -> [Int64] {
        if let conversations = session?.conversations()! {
            var allConversationIDs = [Int64]()
            for convId in conversations.all() {
                allConversationIDs.append(convId.int64Value)
            }

            let sortedConversationIds = allConversationIDs.sorted(by: {
                let firstTimestamp = getLatestMessageTimestamp($0)
                let secondTimestamp = getLatestMessageTimestamp($1)
                return (firstTimestamp.compare(secondTimestamp) == .orderedDescending)
            })

            return sortedConversationIds

        } else {
            return []
        }
    }
    
    func getConversationNameOrPlaceHolder(_ convId: Int64) -> String {
        let addresses = getParticipantAdresses(convId)
        var participantNames: [String] = []
        
        for address in addresses {
            participantNames.append(getLatestNameOrAddressForKulloAddress(address))
        }
        participantNames.sort()
        return participantNames.joined(separator: ", ")
    }
    
    func getConversationImage(_ convId: Int64, size: CGSize) -> UIImage {
        let avatars = getConversationAvatars(convId, size: size)

        if avatars.count == 0 {
            return getAvatarWithText("", size: size)
        } else {
            return UIImage.combineImages(avatars, targetSize: size)
        }
    }
    
    func getConversationAvatars(_ convId: Int64, size: CGSize) -> [UIImage] {
        var avatars = [UIImage]()

        let sortedParticipants = getParticipantAdresses(convId).sorted(by: { $0.isLessThan($1) })
        for address in sortedParticipants {
            avatars.append(getLatestAvatarForKulloAddress(address, size: size))
        }

        return avatars
    }

    func getTotalUnread() -> Int32 {
        var count: Int32 = 0
        if let convIds = session?.conversations()?.all() {
            for convId in convIds {
                count += getConversationUnread(convId.int64Value)
            }
        }
        return count
    }

    func getConversationUnread(_ convId: Int64) -> Int32 {
        return session?.conversations()?.unreadMessages(convId) ?? 0
    }
    
    func addNewConversationForKulloAddresses(_ participants: [KAAddress]) -> Int64 {
        if let conversations = session?.conversations() {
            return conversations.add(Set(participants))
        } else {
            log.error("Session or conversations null, tried to add new conversation.")
            return -1
        }
    }
    
    func startConversationWithSingleRecipient(_ recipientString: String) -> Int64 {
        var participants = [KAAddress]()
        
        if let participant = KAAddress.create(recipientString) {
            participants.append(participant)
            let convId = addNewConversationForKulloAddresses(participants)
            return convId
        } else {
            return -1
        }
    }
    
    func checkIfAddressExists(_ address: KAAddress, delegate: ClientAddressExistsDelegate) {
        clientAddressExistsTask = client.addressExistsAsync(
            address,
            listener: ClientAddressExistsListener(delegate: delegate)
        )
    }
    
    func removeConversation(_ convId: Int64) {
        session?.conversations()?.triggerRemoval(convId)
    }
    
    // MARK: participant senders
    
    func getParticipantAdresses(_ convId: Int64) -> Set<KAAddress> {
        if let conversations = session?.conversations() {
            return conversations.participants(convId)

        } else {
            log.warning("No conversations at session found.")
            return Set<KAAddress>()
        }
    }

    func getLatestNameOrAddressForKulloAddress(_ kulloAddress: KAAddress) -> String {
        if let msgId = getLatestMessageForKulloAddress(kulloAddress) {
            return getSenderNameOrAddress(msgId)
        } else {
            // fall back to address for addresses that didn't send messages
            return kulloAddress.toString()
        }
    }

    func getLatestMessageForKulloAddress(_ kulloAddress: KAAddress) -> Int64? {
        if let messages = session?.messages() {
            let latestMessageID = messages.latest(forSender: kulloAddress)

            if latestMessageID >= 0 {
                return latestMessageID
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    func getLatestAvatarForKulloAddress(_ kulloAddress: KAAddress, size: CGSize) -> UIImage {
        if let msgId = getLatestMessageForKulloAddress(kulloAddress) {
            return getSenderAvatar(msgId, size: size)
        } else {
            // fall back to empty avatar for addresses that didn't send messages
            return getAvatarWithText("", size: size)
        }
    }

    // MARK: current user

    func getClientAddress() -> String {
        return session?.userSettings()?.address()?.toString() ?? ""
    }

    func getClientName() -> String {
        return session?.userSettings()?.name() ?? ""
    }

    func getClientOrganization() -> String {
        return session?.userSettings()?.organization() ?? ""
    }

    func getClientFooter() -> String {
        return session?.userSettings()?.footer() ?? ""
    }

    func getClientMasterKeyPem() -> String {
        return session?.userSettings()?.masterKey()?.pem() ?? ""
    }

    func setClientName(_ name: String) {
        session?.userSettings()?.setName(name)
    }

    func setClientOrganization(_ organization: String) {
        session?.userSettings()?.setOrganization(organization)
    }

    func setClientFooter(_ footer: String) {
        session?.userSettings()?.setFooter(footer)
    }

    func hasAvatar() -> Bool {
        if let data = session?.userSettings()?.avatar() {
            return data.count > 0
        }
        return false
    }

    func getClientAvatar() -> UIImage? {
        let defaultAvatar = "iOS_settings_avatar"

        if let data = session?.userSettings()?.avatar(), let image = UIImage(data: data) {
            return image
        }
        return UIImage(named: defaultAvatar)
    }

    func setClientAvatar(_ newAvatarImage: UIImage) {
        if let userSettings = session?.userSettings() {
            if let imageData = compressAvatar(newAvatarImage) {
                userSettings.setAvatar(imageData)
                userSettings.setAvatarMimeType("image/jpeg")
            }
        }
    }

    func compressAvatar(_ image: UIImage) -> Data? {
        var quality = avatarBestQuality
        while true {
            guard let imageData = UIImageJPEGRepresentation(image, quality) else {
                return nil
            }
            if imageData.count <= avatarMaxSize {
                return imageData
            }
            quality -= jpegQualityDownsamplingSteps
        }
    }

    func deleteClientAvatar() {
        if let userSettings = session?.userSettings() {
            userSettings.setAvatar(Data())
        }
    }
    
    // MARK: drafts

    func saveDraftForConversation(_ convId: Int64, message: String, prepareToSend: Bool) {
        if let drafts = session?.drafts() {
            if prepareToSend {
                // User is done writing. This trims the message before sending
                let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                drafts.setText(convId, text: trimmedMessage)
                drafts.prepare(toSend: convId)
            } else {
                drafts.setText(convId, text: message)
            }
        }
    }

    func clearDraftForConversation(_ convId: Int64) {
        session?.drafts()?.clear(convId)
    }

    func getDraftText(_ convId: Int64) -> String {
        return session?.drafts()?.text(convId) ?? ""
    }
    
    func getDraftState(_ convId: Int64) -> KADraftState {
        return session?.drafts()?.state(convId) ?? KADraftState.editing
    }

    // MARK: messages

    func getLatestMessageTimestamp(_ convId: Int64) -> KADateTime {
        if let conversations = session?.conversations() {
            return conversations.latestMessageTimestamp(convId)
        } else {
            return KAConversations.emptyConversationTimestamp()
        }
    }

    func getAllMessageIdsSorted(_ convId: Int64) -> [Int64] {
        if let messages = session?.messages() {
            var messageList = [Int64]()
            for msgId in messages.all(forConversation: convId) {
                messageList.append(msgId.int64Value)
            }
            return messageList.reversed().sorted { $0 > $1 }
        } else {
            log.warning("No messages found for convId: \(convId)")
            return []
        }
    }

    func getMessageReceivedDate(_ messageId: Int64) -> KADateTime {
        if let messages = session?.messages() {
            return messages.dateReceived(messageId)
        } else {
            return KAConversations.emptyConversationTimestamp()
        }
    }

    func getMessageUnread(_ messageId: Int64) -> Bool {
        return !(session?.messages()?.isRead(messageId) ?? true)
    }

    func setMessageUnread(_ messageId: Int64, value: Bool) {
        session?.messages()?.setRead(messageId, value: !value)
    }

    func hasAttachments(_ messageId: Int64) -> Bool {
        let attIds = session?.messageAttachments()?.all(forMessage: messageId) ?? []
        return !attIds.isEmpty
    }

    func getMessageText(_ messageId: Int64) -> String {
        return session?.messages()?.text(messageId) ?? ""
    }

    func removeMessage(_ messageId: Int64) {
        session?.messages()?.remove(messageId)
    }

    func getSenderName(_ messageId: Int64) -> String {
        return session?.senders()?.name(messageId) ?? ""
    }

    func getSenderNameOrAddress(_ messageId: Int64) -> String {
        var senderName = ""

        if let senders = session?.senders() {
            senderName = senders.name(messageId)
            if (senderName.isEmpty) {
                if let address = senders.address(messageId) {
                    senderName = address.toString()
                }
            }
        }
        return senderName
    }

    func getSenderOrganization(_ messageId: Int64) -> String {
        return session?.senders()?.organization(messageId) ?? ""
    }

    func getSenderAvatar(_ messageId: Int64, size: CGSize) -> UIImage {
        if let senders = session?.senders() {
            let imageData = senders.avatar(messageId)

            if let image = UIImage(data: imageData) {
                return image
            } else {
                let name = getSenderNameOrAddress(messageId)
                let initials = InitialsUtil.getInitialsForName(name)
                return getAvatarWithText(initials, size: size)
            }

        } else {
            log.warning("No senders at session for messageId: \(messageId)")
            return getAvatarWithText("XY", size: size)
        }
    }

    func getSenderImprint(_ messageId: Int64) -> String {
        return session?.messages()?.footer(messageId) ?? ""
    }

    // MARK: message attachments

    func getMessageAttachmentsDownloaded(_ messageId: Int64)  -> Bool {
        return session?.messageAttachments()?.allAttachmentsDownloaded(messageId) ?? false
    }

    func getMessageAttachmentIds(_ messageId: Int64) -> [Int64]  {
        if let messageAttachments = session?.messageAttachments() {
            let attachmentIds = messageAttachments.all(forMessage: messageId)
            return attachmentIds.map { $0.int64Value }
        } else {
            return []
        }
    }

    func getMessageAttachmentFilename(_ messageId: Int64, attachmentId: Int64) -> String {
        return session?.messageAttachments()?.filename(messageId, attId: attachmentId) ?? ""
    }

    func getMessageAttachmentFilesize(_ messageId: Int64, attachmentId: Int64) -> Int64 {
        return session?.messageAttachments()?.size(messageId, attId: attachmentId) ?? 0
    }

    func downloadAttachments(_ messageId: Int64) {
        if let syncer = session?.syncer() {
            syncer.requestDownloadingAttachments(forMessage: messageId)
        }
    }

    func saveMessageAttachment(_ messageId: Int64, attachmentId: Int64, path: String, delegate: MessageAttachmentsSaveToDelegate) {
        messageAttachmentsSaveToTask = session?.messageAttachments()?.save(
            toAsync: messageId,
            attId: attachmentId,
            path: path,
            listener: MessageAttachmentsSaveToListener(delegate: delegate)
        )
    }

    // MARK: draft attachments

    func addAttachmentToDraft(_ convId: Int64, path: String, delegate: DraftAttachmentsAddDelegate) {
        let ext = URL(fileURLWithPath: path).pathExtension
        let mimeType = MimeTypes.mimeType(forExtension: ext) ?? "application/octet-stream"
        addAttachmentTask = session?.draftAttachments()?.addAsync(
            convId,
            path: path,
            mimeType: mimeType,
            listener: DraftAttachmentsAddListener(delegate: delegate)
        )
    }

    func getDraftAttachmentIds(_ convId: Int64) -> [Int64]  {
        if let draftAttachments = session?.draftAttachments() {
            let attachmentIds = draftAttachments.all(forDraft: convId)
            return attachmentIds.map { $0.int64Value }
        } else {
            return []
        }
    }

    func getDraftAttachmentFilenames(_ convId: Int64) -> [String] {
        return getDraftAttachmentIds(convId).map({
            getDraftAttachmentFilename(convId, attachmentId: $0)
        })
    }

    func getDraftAttachmentFilename(_ convId: Int64, attachmentId: Int64) -> String {
        return session?.draftAttachments()?.filename(convId, attId: attachmentId) ?? ""
    }

    func getDraftAttachmentFilesize(_ convId: Int64, attachmentId: Int64) -> Int64 {
        return session?.draftAttachments()?.size(convId, attId: attachmentId) ?? 0
    }

    func saveDraftAttachment(_ convId: Int64, attachmentId: Int64, path: String, delegate: DraftAttachmentsSaveToDelegate) {
        draftAttachmentsSaveToTask = session?.draftAttachments()?.save(
            toAsync: convId,
            attId: attachmentId,
            path: path,
            listener: DraftAttachmentsSaveToListener(delegate: delegate)
        )
    }

    func removeDraftAttachment(_ convId: Int64, attachmentId: Int64) {
        session?.draftAttachments()?.remove(convId, attId: attachmentId)
    }

    // MARK: little helpers

    func getVersions() -> [VersionTuple] {
        var result = [VersionTuple]()
        for componentAndVersion in client.versions() {
            let component = componentAndVersion.0
            let version = componentAndVersion.1
            result.append(VersionTuple(component, version))
        }
        return result.sorted(by: { $0.component < $1.component })
    }

    func getAvatarWithText(_ text: String, size: CGSize) -> UIImage {
        let imageBG = UIImage.imageWithColor(colorAccent, size: size)
        return imageBG.drawTextToImageCentered(text)
    }

    class func friendlyFileSize(_ size: Int64) -> String {
        // get magnitude of size that is divisible by 3
        let magnitude = Int(log10f(Float(size))) / 3 * 3
        var unit = ""

        switch magnitude {
        case 0:
            unit = "B"
        case 3:
            unit = "kB"
        case 6:
            unit = "MB"
        case 9:
            unit = "GB"
        default:
            preconditionFailure("size: \(size), magnitude: \(magnitude)")
        }

        let convertedSize = Float(size) / powf(10, Float(magnitude))
        return String(format: "%.1f %@", convertedSize, unit)
    }

}
