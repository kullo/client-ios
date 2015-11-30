/* Copyright 2015 Kullo GmbH. All rights reserved. */

import LibKullo
import XCGLogger

class KulloConnector {

    typealias VersionTuple = (component: String, version: String)

    // MARK: Properties

    static let sharedInstance = KulloConnector()

    private let client: KAClient
    private var session: KASession?
    private var storage: StorageManager?

    private var checkLoginTask: KAAsyncTask?
    private var createSessionTask: KAAsyncTask?
    private var syncTask: KAAsyncTask?
    private var clientAddressExistsTask: KAAsyncTask?
    private var addAttachmentTask: KAAsyncTask?
    private var messageAttachmentsSaveToTask: KAAsyncTask?

    // MARK: delegates

    //FIXME: make weak
    private var syncDelegates = [SyncDelegate]()
    private var sessionEventsDelegates = [SessionEventsDelegate]()

    // MARK: initialization

    private init() {
        client = KAClient.create()!
        log.info("\(client.versions())");
    }

    // MARK: Login

    func checkForStoredCredentialsAndCreateSession(delegate: ClientCreateSessionDelegate) -> Bool {
        if let address = StorageManager.getLastUserAddress() {
            storage = StorageManager(address: address)

            if let userSettings = storage!.loadUserSettings() {
                createSession(userSettings, delegate: delegate)
                return true;
            }
        }

        log.info("No stored user settings found");
        return false;
    }

    func checkLogin(address: String, masterKeyBlocks: [String], delegate: ClientCheckLoginDelegate) {
        log.info("Logging in with address \(address)")
        
        if let kaAddress = KAAddress.create(address),
            let kaMasterKey = KAMasterKey.createFromDataBlocks(masterKeyBlocks) {

            checkLoginTask = client.checkLoginAsync(
                kaAddress,
                masterKey: kaMasterKey,
                listener: ClientCheckLoginListener(delegate: delegate))
        }
    }
    
    // MARK: Login - input validation
    class func isValidKulloAddress(address: String) -> Bool {
        return (KAAddress.create(address) != nil)
    }
    
    class func isValidMasterKeyBlock(block: String) -> Bool {
        return KAMasterKey.isValidBlock(block)
    }
    
    // MARK: Logout
    
    func logout() {
        log.info("Logging out user.");
        
        checkLoginTask?.cancel()
        createSessionTask?.cancel()
        syncTask?.cancel()
        clientAddressExistsTask?.cancel()
        addAttachmentTask?.cancel()
        messageAttachmentsSaveToTask?.cancel()

        session = nil;
        storage!.deleteAllData()
        storage = nil

        log.info("User logged out.");
    }
    
    //MARK: Session creation
    
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
        return self.session != nil
    }

    func setSession(session: KASession) {
        self.session = session
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
    
    //MARK: Session events
    
    func addSessionEventsDelegate(delegate: SessionEventsDelegate) {
        sessionEventsDelegates.append(delegate)
    }

    func removeSessionEventsDelegate(delegate: SessionEventsDelegate) {
        sessionEventsDelegates = sessionEventsDelegates.filter { $0 !== delegate }
    }
    
    func sessionListener_internalEvent(event: KAInternalEvent?) {
        if let events = session?.notify(event) {
            for event in events as! [KAEvent] {
                switch event.event {
                case KAEventType.ConversationAdded:
                    informDelegatesConversationAdded(event.conversationId)
                case KAEventType.ConversationChanged:
                    informDelegatesConversationChanged(event.conversationId)
                case KAEventType.ConversationRemoved:
                    informDelegatesConversationRemoved(event.conversationId)
                case KAEventType.MessageAdded:
                    informDelegatesMessageAdded(event.conversationId, msgId: event.messageId)
                case KAEventType.MessageRemoved:
                    informDelegatesMessageRemoved(event.conversationId, msgId: event.messageId)
                case KAEventType.MessageAttachmentsDownloadedChanged:
                    informDelegatesMessageAttachmentsDownloadedChanged(event.conversationId, msgId: event.messageId)
                case KAEventType.DraftStateChanged:
                    informDelegatesDraftStateChanged(event.conversationId)
                case KAEventType.DraftTextChanged:
                    informDelegatesDraftTextChanged(event.conversationId)
                case KAEventType.DraftAttachmentAdded:
                    informDelegatesDraftAttachmentAdded(event.conversationId)
                case KAEventType.DraftAttachmentRemoved:
                    informDelegatesDraftAttachmentRemoved(event.conversationId)

                default:
                    log.warning("Unhandled event type: \(event.event)")
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
    
    func informDelegatesMessageAdded(convId: Int64, msgId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventMessageAdded?(convId, msgId: msgId)
        }
    }
    
    func informDelegatesMessageRemoved(convId: Int64, msgId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventMessageRemoved?(convId, msgId: msgId)
        }
    }
    
    func informDelegatesMessageAttachmentsDownloadedChanged(convId: Int64, msgId: Int64) {
        for delegate in self.sessionEventsDelegates {
            delegate.sessionEventMessageAttachmentsDownloadedChanged?(convId, msgId: msgId)
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
    
    // MARK: Synchronization

    func addSyncDelegate(delegate: SyncDelegate) {
        syncDelegates.append(delegate)
    }

    func removeSyncDelegate(delegate: SyncDelegate) {
        syncDelegates = syncDelegates.filter { $0 !== delegate }
    }

    func sync(syncMode: KASyncMode) {
        syncTask = session?.syncer()?.runAsync(syncMode, listener: SyncerRunListener(kulloConnector: self))
    }
    
    func syncerRunListener_draftAttachmentsTooBig(convId: Int64) {
        for delegate in syncDelegates {
            delegate.syncErrorDraftAttachmentsTooBig(convId)
        }
    }
    
    func syncerRunListener_finished() {
        for delegate in syncDelegates {
            delegate.syncFinished()
        }
    }
    
    func syncerRunListener_error(error: KANetworkError) {
        let errorText = KulloConnector.getNetworkErrorText(error)
        
        for delegate in syncDelegates {
            delegate.syncError(errorText)
        }
    }

    
    // MARK: Conversations
    
    func getAllConversationIdsSorted() -> [Int64] {
        if let conversations = session?.conversations()! {
            var allConversationIDs = [Int64]()
            for convId in conversations.all() as! [NSNumber] {
                allConversationIDs.append(convId.longLongValue)
            }

            let sortedConversationIds = allConversationIDs.sort({
                let firstTimestamp = getLatestMessageTimestamp($0)
                let secondTimestamp = getLatestMessageTimestamp($1)
                return (firstTimestamp.compare(secondTimestamp) == .OrderedDescending)
            })

            return sortedConversationIds

        } else {
            return [];
        }
    }
    
    func getConversationNameOrPlaceHolder(convId: Int64) -> String {
        let addresses = getParticipantAdresses(convId);
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

        return avatars;
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
        
        if let conversations = session?.conversations() {
            conversations.remove(convId)
        }
    }
    
    // MARK: participant senders
    
    func getParticipantAdresses(convId: Int64) -> Set<KAAddress> {
        if let conversations = session?.conversations() {
            return conversations.participants(convId) as! Set<KAAddress>

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
    
    func getClientName() -> String {
        if let userSettings = session?.userSettings() {
            return userSettings.name()
        } else {
            return ""
        }
    }
    
    func getClientOrganization() -> String {
        if let userSettings = session?.userSettings() {
            return userSettings.organization()
        } else {
            return ""
        }
    }
    
    func getClientFooter() -> String {
        if let userSettings = session?.userSettings() {
            return userSettings.footer()
        } else {
            return ""
        }
    }
    
    func setClientName(name: String) {
        if let userSettings = session?.userSettings() {
            userSettings.setName(name)
        }
    }
    
    func setClientOrganization(organization: String) {
        if let userSettings = session?.userSettings() {
            userSettings.setOrganization(organization)
        }
    }
    
    func setClientFooter(footer: String) {
        if let userSettings = session?.userSettings() {
            userSettings.setFooter(footer)
        }
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
            if let imageData = getCompressedImageFromData(newAvatarImage, quality: avatarBestQuality) {
                userSettings.setAvatar(imageData)
                userSettings.setAvatarMimeType("image/jpg")
            }
        }
    }
    
    func getCompressedImageFromData(image: UIImage, quality: CGFloat) -> NSData? {
        if let imageData = UIImageJPEGRepresentation(image, quality) {
            if imageData.length > avatarMaxSize {
                return getCompressedImageFromData(image, quality: quality - avatarQualityDownsamplingSteps)
            } else {
                return imageData
            }
        } else {
            return nil
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
                drafts.setText(convId, text: message);
            }
        }
    }
    
    func clearDraftForConversation(convId: Int64) {
        if let drafts = session?.drafts() {
            drafts.clear(convId)
        }
    }
    
    func getDraftText(convId: Int64) -> String {
        if let drafts = session?.drafts() {
            return drafts.text(convId)
        } else {
            return ""
        }
    }
    
    func getDraftState(convId: Int64) -> KADraftState {
        if let drafts = session?.drafts() {
            return drafts.state(convId)
        } else {
            log.warning("No draft state found for convId: \(convId), sending Editing state back.")
            return KADraftState.Editing
        }
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
            for msgId in messages.allForConversation(convId) as! [NSNumber] {
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

    func getMessageText(messageId: Int64) -> String {
        if let messages = session?.messages() {
            return messages.text(messageId)
        } else {
            log.warning("Could not get messages from session for messageId: \(messageId)")
            return ""
        }
    }

    func getSenderName(messageId: Int64) -> String {
        if let senders = session?.senders() {
            return senders.name(messageId)
        } else {
            log.warning("No senders at session for messageId: \(messageId)")
            return ""
        }
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
        if let senders = session?.senders() {
            return senders.organization(messageId)
        } else {
            log.warning("No senders at session for messageId: \(messageId)")
            return ""
        }
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
        if let messages = session?.messages() {
            return messages.footer(messageId)
        } else {
            log.warning("Could not get messages from session for messageId: \(messageId)")
            return ""
        }
    }
    
    // MARK: message attachments
    
    func getMessageAttachmentsDownloaded(messageId: Int64)  -> Bool {
        if let messageAttachments = session?.messageAttachments() {
            return messageAttachments.allAttachmentsDownloaded(messageId)
            
        } else {
            log.warning("No KAMessageAttachments object found at session.")
            return false
        }
        
    }
    
    func getMessageAttachmentsIds(messageId: Int64) -> [Int64]  {
        if let messageAttachments = session?.messageAttachments() {
            
            var messageAttachmentIds = [Int64]()
            for messageAttachmentId in messageAttachments.allForMessage(messageId) as! [NSNumber] {
                messageAttachmentIds.append(messageAttachmentId.longLongValue)
            }
            
            return messageAttachmentIds
        } else {
            log.warning("No message attachments found at session")
            return []
        }
    }
    
    func getMessageAttachmentFilename(messageId: Int64, attachmentId: Int64) -> String {
        if let messageAttachments = session?.messageAttachments() {
            return messageAttachments.filename(messageId, attId: attachmentId)
        } else {
            log.warning("No message attachments found at session")
            return ""
        }
    }
    
    func getMessageAttachmentFilesize(messageId: Int64, attachmentId: Int64) -> Int64 {
        if let messageAttachments = session?.messageAttachments() {
            return messageAttachments.size(messageId, attId: attachmentId)
        } else {
            log.warning("No message attachments found at session")
            return 0
        }
    }
    
    func getMessageAttachmentMimeType(messageId: Int64, attachmentId: Int64) -> String {
        if let messageAttachments = session?.messageAttachments() {
            return messageAttachments.mimeType(messageId, attId: attachmentId)
        } else {
            log.warning("No message attachments found at session")
            return ""
        }
    }
    
    func downloadAttachments(messageId: Int64) {
        syncTask = session?.syncer()?.downloadAttachmentsForMessageAsync(messageId, listener: SyncerRunListener(kulloConnector: self))
    }

    func saveMessageAttachment(messageId: Int64, attachmentId: Int64, path: String, delegate: MessageAttachmentsSaveToDelegate) {
        messageAttachmentsSaveToTask = session?.messageAttachments()?.saveToAsync(
            messageId,
            attId: attachmentId,
            path: path,
            listener: MessageAttachmentsSaveToListener(delegate: delegate)
        )
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
            let component = componentAndVersion.0 as! String
            let version = componentAndVersion.1 as! String
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
        case KANetworkError.Forbidden:
            return NSLocalizedString("network_error_forbidden", comment: "")
        case KANetworkError.Protocol:
            return NSLocalizedString("network_error_protocol", comment: "")
        case KANetworkError.Unauthorized:
            return NSLocalizedString("network_error_unauthorized", comment: "")
        case KANetworkError.Server:
            return NSLocalizedString("network_error_server", comment: "")
        case KANetworkError.Connection:
            return NSLocalizedString("network_error_connection", comment: "")
        }
    }

    class func getLocalErrorText(error: KALocalError) -> String {
        switch error {
        case KALocalError.Filesystem:
            return NSLocalizedString("local_error_filesystem", comment: "")
        case KALocalError.Unknown:
            return NSLocalizedString("local_error_unknown", comment: "")
        }
    }

}
