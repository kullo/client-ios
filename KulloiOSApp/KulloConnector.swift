/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import LibKullo
import SwiftMime
import UIKit
import XCGLogger

class KulloConnector {

    typealias VersionTuple = (component: String, version: String)

    static let sharedInstance = KulloConnector()

    private let client: KAClient
    private var session: KASession?
    private var storage: StorageManager?

    private var generateKeysTask: KAAsyncTask?
    private var registerAccountTask: KAAsyncTask?
    private var checkCredentialsTask: KAAsyncTask?
    private var registerPushTokenTask: KAAsyncTask?
    private var unregisterPushTokenTask: KAAsyncTask?
    private var createSessionTask: KAAsyncTask?
    private var clientAddressExistsTask: KAAsyncTask?
    private var addAttachmentTask: KAAsyncTask?
    private var messageAttachmentsSaveToTask: KAAsyncTask?
    private var draftAttachmentsSaveToTask: KAAsyncTask?

    private var generateKeysProgress: Int8 = 0
    private var registration: KARegistration?
    private var pushToken: String?
    private var pushTokenRegistered = false
    private var shouldSyncWhenSessionHasBeenCreated = false
    private var syncProgress: KASyncProgress?
    private var syncCompletionCallback: (() -> Void)?

    // MARK: delegates

    //FIXME: make weak
    private var generateKeysDelegates = [GenerateKeysDelegate]()
    private var syncDelegates = [SyncDelegate]()
    private var sessionEventsDelegates = [SessionEventsDelegate]()

    // MARK: initialization

    private init() {
        client = KAClient.create()!
        log.info("\(client.versions())")
    }

    // MARK: Login

    func checkForStoredCredentialsAndCreateSession(delegate: ClientCreateSessionDelegate) -> Bool {
        if let address = StorageManager.getLastUserAddress() {
            storage = StorageManager(address: address)

            if let userSettings = storage!.loadUserSettings() {
                createSession(userSettings, delegate: delegate)
                return true
            }
        }

        log.info("No stored user settings found")
        return false
    }

    func checkCredentials(address: String, masterKeyBlocks: [String], delegate: ClientCheckCredentialsDelegate) {
        log.info("Logging in with address \(address)")

        if let kaAddress = KAAddress.create(address),
            let kaMasterKey = KAMasterKey.createFromDataBlocks(masterKeyBlocks) {

            checkCredentialsTask = client.checkCredentialsAsync(
                kaAddress,
                masterKey: kaMasterKey,
                listener: ClientCheckCredentialsListener(delegate: delegate))
        }
    }

    class func isValidKulloAddress(address: String) -> Bool {
        return (KAAddress.create(address) != nil)
    }

    class func isValidMasterKeyBlock(block: String) -> Bool {
        return KAMasterKey.isValidBlock(block)
    }

    // MARK: Logout

    func logout() {
        log.info("Logging out user.")

        unregisterPushToken()
        unregisterPushTokenTask?.waitForMs(2000)

        closeSession()
        storage!.deleteAllData()
        storage = nil

        log.info("User logged out.")
    }

    //MARK: Session

    func createSession(userSettings: KAUserSettings, delegate: ClientCreateSessionDelegate) {
        if storage == nil || storage!.userAddress != userSettings.address()! {
            storage = StorageManager(address: userSettings.address()!)
        }

        if userSettings.name().isEmpty {
            userSettings.setName(userSettings.address()!.localPart())
            storage!.saveEditableUserSettings(userSettings)
        }

        createSessionTask = client.createSessionAsync(
            userSettings,
            dbFilePath: storage!.getDbPath(),
            sessionListener: SessionListener(kulloConnector: self),
            listener: ClientCreateSessionListener(delegate: delegate))
    }

    func hasSession() -> Bool {
        return session != nil
    }

    func setSession(session: KASession) {
        self.session = session
        self.session?.syncer()?.setListener(SyncerListener(kulloConnector: self))
        if let pushToken = pushToken {
            registerPushToken(pushToken)
        }
        if shouldSyncWhenSessionHasBeenCreated {
            sync(.WithoutAttachments)
        }
    }

    func closeSession() {
        UIApplication.sharedApplication().idleTimerDisabled = false
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false

        // Make sure all async tasks are done.
        // We cancel all tasks before waiting so that they can finish in parallel.
        session?.syncer()?.cancel()
        generateKeysTask?.cancel()
        registerAccountTask?.cancel()
        checkCredentialsTask?.cancel()
        registerPushTokenTask?.cancel()
        unregisterPushTokenTask?.cancel()
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
        createSessionTask?.waitUntilDone()
        clientAddressExistsTask?.waitUntilDone()
        addAttachmentTask?.waitUntilDone()
        messageAttachmentsSaveToTask?.waitUntilDone()
        draftAttachmentsSaveToTask?.waitUntilDone()

        session = nil
    }

    private func makeKAPushToken(pushToken: String) -> KAPushToken {
        return KAPushToken(type: .GCM, token: pushToken, environment: .IOS)
    }

    func registerPushToken(pushToken: String) {
        if self.pushToken != pushToken {
            self.pushToken = pushToken
            pushTokenRegistered = false
        }
        if !pushTokenRegistered, let session = session {
            registerPushTokenTask = session.registerPushToken(makeKAPushToken(pushToken))
            pushTokenRegistered = true
        }
    }

    func unregisterPushToken() {
        if let pushToken = pushToken {
            unregisterPushTokenTask = session?.unregisterPushToken(makeKAPushToken(pushToken))
            pushTokenRegistered = false
        }
    }

    //MARK: Update/Store/Load/Remove user settings

    func saveCredentials(address: KAAddress, masterKey: KAMasterKey) {
        StorageManager(address: address).saveCredentials(address, masterKey: masterKey)
    }

    func storeCurrentUserSettings() {
        if let userSettings = session?.userSettings(), let storage = storage {
            storage.saveEditableUserSettings(userSettings)

        } else {
            assertionFailure("session or storage not available")
        }
    }

    //MARK: Registration

    func addGenerateKeysDelegate(delegate: GenerateKeysDelegate) {
        generateKeysDelegates.append(delegate)
    }

    func removeGenerateKeysDelegate(delegate: GenerateKeysDelegate) {
        generateKeysDelegates = generateKeysDelegates.filter { $0 !== delegate }
    }

    func getGenerateKeysProgress() -> Int8 {
        return generateKeysProgress
    }

    func startGenerateKeysIfNecessary() {
        let generateKeysNotRunning = generateKeysTask == nil || generateKeysTask!.isDone()
        if registration == nil && generateKeysNotRunning {
            UIApplication.sharedApplication().idleTimerDisabled = true
            generateKeysTask = client.generateKeysAsync(ClientGenerateKeysListener(kulloConnector: self))
        }
    }

    func generateKeys_progress(progress: Int8) {
        generateKeysProgress = progress
        for delegate in generateKeysDelegates {
            delegate.generateKeysProgress(progress)
        }
    }

    func generateKeys_finished(registration: KARegistration) {
        UIApplication.sharedApplication().idleTimerDisabled = false

        self.registration = registration
        for delegate in generateKeysDelegates {
            delegate.generateKeysFinished()
        }
    }

    func registerAccount(address: KAAddress, delegate: RegisterAccountDelegate) {
        if let registration = registration {
            registerAccountTask = registration.registerAccountAsync(
                address,
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
    
    func addSessionEventsDelegate(delegate: SessionEventsDelegate) {
        sessionEventsDelegates.append(delegate)
    }

    func removeSessionEventsDelegate(delegate: SessionEventsDelegate) {
        sessionEventsDelegates = sessionEventsDelegates.filter { $0 !== delegate }
    }
    
    func sessionListener_internalEvent(event: KAInternalEvent?) {
        if let events = session?.notify(event) {
            for event in events {
                switch event.event {
                case .ConversationAdded:
                    informDelegatesConversationAdded(event.conversationId)
                case .ConversationChanged:
                    informDelegatesConversationChanged(event.conversationId)
                case .ConversationRemoved:
                    informDelegatesConversationRemoved(event.conversationId)
                case .DraftStateChanged:
                    informDelegatesDraftStateChanged(event.conversationId)
                case .DraftTextChanged:
                    informDelegatesDraftTextChanged(event.conversationId)
                case .DraftAttachmentAdded:
                    informDelegatesDraftAttachmentAdded(event.conversationId)
                case .DraftAttachmentRemoved:
                    informDelegatesDraftAttachmentRemoved(event.conversationId)
                case .MessageAdded:
                    informDelegatesMessageAdded(event.conversationId, msgId: event.messageId)
                case .MessageDeliveryChanged:
                    informDelegatesMessageDeliveryChanged(event.conversationId, msgId: event.messageId)
                case .MessageStateChanged:
                    informDelegatesMessageStateChanged(event.conversationId, msgId: event.messageId)
                case .MessageAttachmentsDownloadedChanged:
                    informDelegatesMessageAttachmentsDownloadedChanged(event.conversationId, msgId: event.messageId)
                case .MessageRemoved:
                    informDelegatesMessageRemoved(event.conversationId, msgId: event.messageId)
                case .LatestSenderChanged:
                    break //FIXME: implement
                }
            }
        }
    }
    
    func informDelegatesConversationAdded(convId: Int64) {
        for delegate in sessionEventsDelegates {
            delegate.sessionEventConversationAdded?(convId)
        }
    }
    
    func informDelegatesConversationChanged(convId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventConversationChanged?(convId)
        }
    }
    
    func informDelegatesConversationRemoved(convId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventConversationRemoved?(convId)
        }
    }
    
    func informDelegatesDraftStateChanged(convId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventDraftStateChanged?(convId)
        }
    }

    func informDelegatesDraftTextChanged(convId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventDraftTextChanged?(convId)
        }
    }

    func informDelegatesDraftAttachmentAdded(convId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventDraftAttachmentAdded?(convId)
        }
    }

    func informDelegatesDraftAttachmentRemoved(convId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventDraftAttachmentRemoved?(convId)
        }
    }
    
    func informDelegatesMessageAdded(convId: Int64, msgId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventMessageAdded?(convId, msgId: msgId)
        }
    }

    func informDelegatesMessageDeliveryChanged(convId: Int64, msgId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventMessageDeliveryChanged?(convId, msgId: msgId)
        }
    }

    func informDelegatesMessageStateChanged(convId: Int64, msgId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventMessageStateChanged?(convId, msgId: msgId)
        }
    }

    func informDelegatesMessageAttachmentsDownloadedChanged(convId: Int64, msgId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventMessageAttachmentsDownloadedChanged?(convId, msgId: msgId)
        }
    }

    func informDelegatesMessageRemoved(convId: Int64, msgId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventMessageRemoved?(convId, msgId: msgId)
        }
    }

    // MARK: Synchronization

    func addSyncDelegate(delegate: SyncDelegate) {
        syncDelegates.append(delegate)
    }

    func removeSyncDelegate(delegate: SyncDelegate) {
        syncDelegates = syncDelegates.filter { $0 !== delegate }
    }

    // returns true iff a session is available and a sync has been requested
    func sync(syncMode: KASyncMode) -> Bool {
        if let syncer = session?.syncer() {
            syncer.requestSync(syncMode)
            shouldSyncWhenSessionHasBeenCreated = false
        } else {
            shouldSyncWhenSessionHasBeenCreated = true
        }
        return !shouldSyncWhenSessionHasBeenCreated
    }

    func sync(syncMode: KASyncMode, completionHandler: (UIBackgroundFetchResult) -> Void) {
        syncCompletionCallback = {
            log.debug("Sync completed (triggered by notification)")
            completionHandler(.NewData)
        }
        if !sync(syncMode) {
            syncCompletionCallback = nil
            completionHandler(.Failed)
        }
    }

    func syncIfNecessary() {
        guard let lastFullSync = session?.syncer()?.lastFullSync() else {
            sync(.WithoutAttachments)
            return
        }
        if abs(lastFullSync.toNSDate().timeIntervalSinceNow) > secondsBetweenSyncs {
            sync(.WithoutAttachments)
        }
    }

    func isSyncRunning() -> Bool {
        return session?.syncer()?.isSyncing() ?? false
    }

    func getSyncProgress() -> Float {
        guard let syncProgress = syncProgress else {
            return 0
        }
        return Float(syncProgress.countProcessed) / Float(syncProgress.countTotal)
    }

    func syncerListener_started() {
        UIApplication.sharedApplication().idleTimerDisabled = true
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        for delegate in syncDelegates {
            delegate.syncStarted()
        }
    }

    func syncerListener_progressed(progress: KASyncProgress) {
        syncProgress = progress
        for delegate in syncDelegates {
            delegate.syncProgressed()
        }
    }

    func syncerListener_draftAttachmentsTooBig(convId: Int64) {
        for delegate in syncDelegates {
            delegate.syncDraftAttachmentsTooBig(convId)
        }
    }

    func syncComplete() {
        if let callback = syncCompletionCallback {
            callback()
            syncCompletionCallback = nil
        }
        UIApplication.sharedApplication().idleTimerDisabled = false
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    }

    func syncerListener_finished() {
        syncComplete()
        for delegate in syncDelegates {
            delegate.syncFinished()
        }
    }
    
    func syncerListener_error(error: KANetworkError) {
        syncComplete()
        let errorText = KulloConnector.getNetworkErrorText(error)
        for delegate in syncDelegates {
            delegate.syncError(errorText)
        }
    }

    
    // MARK: Conversations
    
    func getAllConversationIdsSorted() -> [Int64] {
        if let conversations = session?.conversations()! {
            var allConversationIDs = [Int64]()
            for convId in conversations.all() {
                allConversationIDs.append(convId.longLongValue)
            }

            let sortedConversationIds = allConversationIDs.sort({
                let firstTimestamp = getLatestMessageTimestamp($0)
                let secondTimestamp = getLatestMessageTimestamp($1)
                return (firstTimestamp.compare(secondTimestamp) == .OrderedDescending)
            })

            return sortedConversationIds

        } else {
            return []
        }
    }
    
    func getConversationNameOrPlaceHolder(convId: Int64) -> String {
        let addresses = getParticipantAdresses(convId)
        var participantNames : [String] = []
        
        for address in addresses {
            participantNames.append(getLatestNameOrAddressForKulloAddress(address))
        }
        participantNames.sortInPlace()
        return participantNames.joinWithSeparator(", ")
    }
    
    func getConversationImage(convId: Int64, size: CGSize) -> UIImage {
        let avatars = getConversationAvatars(convId, size: size)

        if avatars.count == 0 {
            return getAvatarWithText("", size: size)
        } else {
            return UIImage.combineImages(avatars, targetSize: size)
        }
    }
    
    func getConversationAvatars(convId: Int64, size: CGSize) -> [UIImage] {
        var avatars = [UIImage]()

        let sortedParticipants = getParticipantAdresses(convId).sort({ $0.isLessThan($1) })
        for address in sortedParticipants {
            avatars.append(getLatestAvatarForKulloAddress(address, size: size))
        }

        return avatars
    }

    func getConversationUnread(convId: Int64) -> Int32 {
        return session?.conversations()?.unreadMessages(convId) ?? 0
    }
    
    func addNewConversationForKulloAddresses(participants: [KAAddress]) -> Int64 {
        if let conversations = session?.conversations() {
            return conversations.add(Set(participants))
        } else {
            log.error("Session or conversations null, tried to add new conversation.")
            return -1
        }
    }
    
    func startConversationWithSingleRecipient(recipientString: String) -> Int64 {
        var participants = [KAAddress]()
        
        if let participant = KAAddress.create(recipientString) {
            participants.append(participant)
            let convId = addNewConversationForKulloAddresses(participants)
            return convId
        } else {
            return -1
        }
    }
    
    func checkIfAddressExists(address: KAAddress, delegate: ClientAddressExistsDelegate) {
        clientAddressExistsTask = client.addressExistsAsync(
            address,
            listener: ClientAddressExistsListener(delegate: delegate)
        )
    }
    
    func removeConversation(convId: Int64) {
        session?.conversations()?.remove(convId)
    }
    
    // MARK: participant senders
    
    func getParticipantAdresses(convId: Int64) -> Set<KAAddress> {
        if let conversations = session?.conversations() {
            return conversations.participants(convId)

        } else {
            log.warning("No conversations at session found.")
            return Set<KAAddress>()
        }
    }

    func getLatestNameOrAddressForKulloAddress(kulloAddress: KAAddress) -> String {
        if let msgId = getLatestMessageForKulloAddress(kulloAddress) {
            return getSenderNameOrAddress(msgId)
        } else {
            // fall back to address for addresses that didn't send messages
            return kulloAddress.toString()
        }
    }

    func getInitialsForName(name: String) -> String {
        var returnString = ""
        let parts = name.characters.split{$0 == " "}.map(String.init)

        if parts.count == 1 {
            returnString = String(name.characters.first!)
        } else if parts.count >= 2 {
            returnString = String(parts[0].characters.first!) + String(parts[parts.count - 1].characters.first!)
        }

        return returnString.uppercaseString
    }

    func getLatestMessageForKulloAddress(kulloAddress: KAAddress) -> Int64? {
        if let messages = session?.messages() {
            let latestMessageID = messages.latestForSender(kulloAddress)

            if latestMessageID >= 0 {
                return latestMessageID
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    func getLatestAvatarForKulloAddress(kulloAddress: KAAddress, size: CGSize) -> UIImage {
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

    func setClientName(name: String) {
        session?.userSettings()?.setName(name)
    }

    func setClientOrganization(organization: String) {
        session?.userSettings()?.setOrganization(organization)
    }

    func setClientFooter(footer: String) {
        session?.userSettings()?.setFooter(footer)
    }

    func hasAvatar() -> Bool {
        if let data = session?.userSettings()?.avatar() {
            return data.length > 0
        }
        return false
    }

    func getClientAvatar() -> UIImage? {
        let defaultAvatar = "iOS_settings_avatar"

        if let data = session?.userSettings()?.avatar(), image = UIImage(data: data) {
            return image
        }
        return UIImage(named: defaultAvatar)
    }

    func setClientAvatar(newAvatarImage: UIImage) {
        if let userSettings = session?.userSettings() {
            if let imageData = compressAvatar(newAvatarImage) {
                userSettings.setAvatar(imageData)
                userSettings.setAvatarMimeType("image/jpeg")
            }
        }
    }

    func compressAvatar(image: UIImage) -> NSData? {
        var quality = avatarBestQuality
        while true {
            guard let imageData = UIImageJPEGRepresentation(image, quality) else {
                return nil
            }
            if imageData.length <= avatarMaxSize {
                return imageData
            }
            quality -= jpegQualityDownsamplingSteps
        }
    }

    func deleteClientAvatar() {
        if let userSettings = session?.userSettings() {
            userSettings.setAvatar(NSData())
        }
    }
    
    // MARK: drafts

    func saveDraftForConversation(convId: Int64, message: String, prepareToSend: Bool) {
        if let drafts = session?.drafts() {
            if prepareToSend == true {
                // User is done writing. This trims the message before sending
                let trimmedMessage = message.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                drafts.setText(convId, text: trimmedMessage)
                drafts.prepareToSend(convId)
            } else {
                drafts.setText(convId, text: message)
            }
        }
    }

    func clearDraftForConversation(convId: Int64) {
        session?.drafts()?.clear(convId)
    }

    func getDraftText(convId: Int64) -> String {
        return session?.drafts()?.text(convId) ?? ""
    }
    
    func getDraftState(convId: Int64) -> KADraftState {
        return session?.drafts()?.state(convId) ?? KADraftState.Editing
    }

    // MARK: messages

    func getLatestMessageTimestamp(convId: Int64) -> KADateTime {
        if let conversations = session?.conversations() {
            return conversations.latestMessageTimestamp(convId)
        } else {
            return KAConversations.emptyConversationTimestamp()
        }
    }

    func getAllMessageIdsSorted(convId: Int64) -> [Int64] {
        if let messages = session?.messages() {
            var messageList = [Int64]()
            for msgId in messages.allForConversation(convId) {
                messageList.append(msgId.longLongValue)
            }
            let sortedMessageList = messageList.sort {
                (lhs: Int64, rhs: Int64) -> Bool in
                return lhs > rhs
            }
            return sortedMessageList
        } else {
            log.warning("No messages found for convId: \(convId)")
            return []
        }
    }

    func getMessageSentDate(messageId: Int64) -> KADateTime {
        if let messages = session?.messages() {
            return messages.dateSent(messageId)
        } else {
            return KAConversations.emptyConversationTimestamp()
        }
    }

    func getMessageUnread(messageId: Int64) -> Bool {
        return !(session?.messages()?.isRead(messageId) ?? true)
    }

    func setMessageUnread(messageId: Int64, value: Bool) {
        session?.messages()?.setRead(messageId, value: !value)
    }

    func getMessageText(messageId: Int64) -> String {
        return session?.messages()?.text(messageId) ?? ""
    }

    func removeMessage(messageId: Int64) {
        session?.messages()?.remove(messageId)
    }

    func getSenderName(messageId: Int64) -> String {
        return session?.senders()?.name(messageId) ?? ""
    }

    func getSenderNameOrAddress(messageId: Int64) -> String {
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

    func getSenderOrganization(messageId: Int64) -> String {
        return session?.senders()?.organization(messageId) ?? ""
    }

    func getSenderAvatar(messageId: Int64, size: CGSize) -> UIImage {
        if let senders = session?.senders() {
            let imageData = senders.avatar(messageId)

            if let image = UIImage(data: imageData) {
                return image
            } else {
                let name = getSenderNameOrAddress(messageId)
                let initials = getInitialsForName(name)
                return getAvatarWithText(initials, size: size)
            }

        } else {
            log.warning("No senders at session for messageId: \(messageId)")
            return getAvatarWithText("XY", size: size)
        }
    }

    func getSenderImprint(messageId: Int64) -> String {
        return session?.messages()?.footer(messageId) ?? ""
    }

    // MARK: message attachments

    func getMessageAttachmentsDownloaded(messageId: Int64)  -> Bool {
        return session?.messageAttachments()?.allAttachmentsDownloaded(messageId) ?? false
    }

    func getMessageAttachmentIds(messageId: Int64) -> [Int64]  {
        if let messageAttachments = session?.messageAttachments() {
            let attachmentIds = messageAttachments.allForMessage(messageId)
            return attachmentIds.map { $0.longLongValue }
        } else {
            return []
        }
    }

    func getMessageAttachmentFilename(messageId: Int64, attachmentId: Int64) -> String {
        return session?.messageAttachments()?.filename(messageId, attId: attachmentId) ?? ""
    }

    func getMessageAttachmentFilesize(messageId: Int64, attachmentId: Int64) -> Int64 {
        return session?.messageAttachments()?.size(messageId, attId: attachmentId) ?? 0
    }

    func downloadAttachments(messageId: Int64) {
        if let syncer = session?.syncer() {
            syncer.requestDownloadingAttachmentsForMessage(messageId)
        }
    }

    func saveMessageAttachment(messageId: Int64, attachmentId: Int64, path: String, delegate: MessageAttachmentsSaveToDelegate) {
        messageAttachmentsSaveToTask = session?.messageAttachments()?.saveToAsync(
            messageId,
            attId: attachmentId,
            path: path,
            listener: MessageAttachmentsSaveToListener(delegate: delegate)
        )
    }

    // MARK: draft attachments

    func addAttachmentToDraft(convId: Int64, path: String, delegate: DraftAttachmentsAddDelegate) {
        let mimeType = SwiftMime.sharedManager.lookupType(path) as String? ?? "application/octet-stream"
        addAttachmentTask = session?.draftAttachments()?.addAsync(
            convId,
            path: path,
            mimeType: mimeType,
            listener: DraftAttachmentsAddListener(delegate: delegate)
        )
    }

    func getDraftAttachmentIds(convId: Int64) -> [Int64]  {
        if let draftAttachments = session?.draftAttachments() {
            let attachmentIds = draftAttachments.allForDraft(convId)
            return attachmentIds.map { $0.longLongValue }
        } else {
            return []
        }
    }

    func getDraftAttachmentFilename(convId: Int64, attachmentId: Int64) -> String {
        return session?.draftAttachments()?.filename(convId, attId: attachmentId) ?? ""
    }

    func getDraftAttachmentFilesize(convId: Int64, attachmentId: Int64) -> Int64 {
        return session?.draftAttachments()?.size(convId, attId: attachmentId) ?? 0
    }

    func saveDraftAttachment(convId: Int64, attachmentId: Int64, path: String, delegate: DraftAttachmentsSaveToDelegate) {
        draftAttachmentsSaveToTask = session?.draftAttachments()?.saveToAsync(
            convId,
            attId: attachmentId,
            path: path,
            listener: DraftAttachmentsSaveToListener(delegate: delegate)
        )
    }

    func removeDraftAttachment(convId: Int64, attachmentId: Int64) {
        session?.draftAttachments()?.remove(convId, attId: attachmentId)
    }

    // MARK: little helpers

    class func getAppVersion() -> String {
        return NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as! String
    }

    class func getAppBuild() -> String {
        return NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as! String
    }

    func getVersions() -> [VersionTuple] {
        var result = [VersionTuple]()
        for componentAndVersion in client.versions() {
            let component = componentAndVersion.0
            let version = componentAndVersion.1
            result.append(VersionTuple(component, version))
        }
        return result.sort({ $0.component < $1.component })
    }

    func getAvatarWithText(text: String, size: CGSize) -> UIImage {
        let imageBG = UIImage.imageWithColor(colorAccent, size: size)
        return imageBG.drawTextToImageCentered(text)
    }

    class func getNetworkErrorText(error: KANetworkError) -> String {
        switch error {
        case .Forbidden:
            return NSLocalizedString("network_error_forbidden", comment: "")
        case .Protocol:
            return NSLocalizedString("network_error_protocol", comment: "")
        case .Unauthorized:
            return NSLocalizedString("network_error_unauthorized", comment: "")
        case .Server:
            return NSLocalizedString("network_error_server", comment: "")
        case .Connection:
            return NSLocalizedString("network_error_connection", comment: "")
        case .Unknown:
            return NSLocalizedString("network_error_unknown", comment: "")
        }
    }

    class func getLocalErrorText(error: KALocalError) -> String {
        switch error {
        case .Filesystem:
            return NSLocalizedString("local_error_filesystem", comment: "")
        case .Unknown:
            return NSLocalizedString("local_error_unknown", comment: "")
        }
    }

    class func friendlyFileSize(size: Int64) -> String {
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
        return NSString(format: "%.1f %@", convertedSize, unit) as String
    }

}
