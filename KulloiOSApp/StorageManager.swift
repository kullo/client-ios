/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import SwiftKeychainWrapper
import LibKullo

class StorageManager {

    //MARK: public interface

    let userAddress: KAAddress

    class func getLastUserAddress() -> KAAddress? {
        if let addrString = KeychainWrapper.stringForKey(KEY_ADDRESS) {
            return KAAddress.create(addrString)
        }
        return nil
    }

    init(address: KAAddress) {
        userAddress = address
        userAddressString = address.toString()

        migrate()
    }

    func loadUserSettings() -> KAUserSettings? {
        var blockList = [String]()
        for index in 0...15 {
            blockList.append(KeychainWrapper.stringForKey(getBlockKey(index))!)
        }
        if let masterKey = KAMasterKey.createFromDataBlocks(blockList) {
            let userSettings = KAUserSettings.create(userAddress, masterKey: masterKey)!

            if let name = KeychainWrapper.stringForKey(getNameKey()) {
                userSettings.setName(name)
            }
            if let organization = KeychainWrapper.stringForKey(getOrganizationKey()) {
                userSettings.setOrganization(organization)
            }
            if let footer = KeychainWrapper.stringForKey(getFooterKey()) {
                userSettings.setFooter(footer)
            }
            if var avatarMimeType = KeychainWrapper.stringForKey(getAvatarTypeKey()) {
                // fix wrong MIME type that has been set previously by this app
                if avatarMimeType == "image/jpg" {
                    avatarMimeType = "image/jpeg"
                }
                userSettings.setAvatarMimeType(avatarMimeType)
            }
            userSettings.setAvatar(loadAvatar() ?? NSData())
            return userSettings
        }

        return nil
    }

    func saveCredentials(address: KAAddress, masterKey: KAMasterKey) {
        KeychainWrapper.setString(address.toString(), forKey: StorageManager.KEY_ADDRESS)

        let blockList = masterKey.dataBlocks()
        for (index, block) in blockList.enumerate() {
            KeychainWrapper.setString(block, forKey: getBlockKey(index))
        }
    }

    func saveEditableUserSettings(userSettings: KAUserSettings) {
        var saveStates : [Bool] = []
        saveStates.append(KeychainWrapper.setString(userSettings.name(), forKey: getNameKey()))
        saveStates.append(KeychainWrapper.setString(userSettings.organization(), forKey: getOrganizationKey()))
        saveStates.append(KeychainWrapper.setString(userSettings.footer(), forKey: getFooterKey()))
        saveStates.append(KeychainWrapper.setString(userSettings.avatarMimeType(), forKey: getAvatarTypeKey()))

        for (index, saveState) in saveStates.enumerate() {
            if !saveState {
                log.error("Storing of user settings failed for position: \(index)")
            }
        }

        let avatar = userSettings.avatar()
        saveAvatar(avatar.length > 0 ? avatar : nil)
    }

    func getDbPath() -> String {
        return "\(getUserDirectory())/sync.db"
    }

    class func getTempPathForView(viewName: String, filename: String = "") -> String {
        let dir = "\(NSTemporaryDirectory())/\(viewName)"
        StorageManager.createDirectory(dir)
        return "\(dir)/\(filename)"
    }

    func deleteAllData() {
        StorageManager.removeFileOrDirectoryIfPossible(getUserDirectory())

        KeychainWrapper.removeObjectForKey(StorageManager.KEY_ADDRESS)
        for index in 0...15 {
            KeychainWrapper.removeObjectForKey(getDeprecatedBlockKey(index))
            KeychainWrapper.removeObjectForKey(getBlockKey(index))
        }
        KeychainWrapper.removeObjectForKey(getNameKey())
        KeychainWrapper.removeObjectForKey(getOrganizationKey())
        KeychainWrapper.removeObjectForKey(getFooterKey())
        KeychainWrapper.removeObjectForKey(getAvatarTypeKey())
    }


    //MARK: private implementation

    private static let CURRENT_STORAGE_VERSION = 1
    private let userAddressString: String

    private static let KEY_ADDRESS = "kullo_address"
    private static let KEY_STORAGE_VERSION = "kullo_storage_version"
    private static let DEFAULTS_KEY_STORAGE_VERSION = "KulloStorageVersion"

    private func migrate() {
        var storageVersion = getStorageVersion()
        while storageVersion < StorageManager.CURRENT_STORAGE_VERSION {
            switch storageVersion {
            case 0:
                // add domain to user directory name
                StorageManager.moveFileOrDirectoryIfPossible(
                    "\(getDocumentsDirectory())/\(userAddress.localPart())",
                    to: getUserDirectory())

                // move avatar into user directory and remove address from filename
                StorageManager.moveFileOrDirectoryIfPossible(
                    "\(getDocumentsDirectory())/user_avatar_\(userAddressString)",
                    to: getAvatarPath())

                // remove address and closing parenthesis from DB filename
                moveDb(
                    "\(getUserDirectory())/\(userAddress.localPart()).db)",
                    to: getDbPath())

                // add address to MasterKey block key
                for index in 0...15 {
                    let deprecatedBlockKey = getDeprecatedBlockKey(index);
                    if let block = KeychainWrapper.stringForKey(deprecatedBlockKey) {
                        KeychainWrapper.setString(block, forKey: getBlockKey(index))
                        KeychainWrapper.removeObjectForKey(deprecatedBlockKey)
                    }
                }

            default:
                preconditionFailure("unsupported storage version: \(storageVersion)")
            }
            ++storageVersion
            setStorageVersion(storageVersion)

            log.info("Finished migration to storage version \(storageVersion)")
        }
    }

    private func getStorageVersion() -> Int {
        if let storageVersion = KeychainWrapper.stringForKey(StorageManager.KEY_STORAGE_VERSION) {
            if let storageVersion = Int(storageVersion) {
                return storageVersion
            }
        }

        // try to move storage version from deprecated location (UserDefaults) to KeyChain
        let defaults = NSUserDefaults.standardUserDefaults()
        let storageVersion = defaults.integerForKey(StorageManager.DEFAULTS_KEY_STORAGE_VERSION)

        if storageVersion > 0 {
            setStorageVersion(storageVersion)
            defaults.removeObjectForKey(StorageManager.DEFAULTS_KEY_STORAGE_VERSION)
            defaults.synchronize()
        }
        return storageVersion
    }

    private func setStorageVersion(storageVersion: Int) {
        KeychainWrapper.setString(String(storageVersion), forKey: StorageManager.KEY_STORAGE_VERSION)
    }

    private func moveDb(from: String, to: String) {
        StorageManager.moveFileOrDirectoryIfPossible(from, to: to)
        StorageManager.moveFileOrDirectoryIfPossible("\(from)-wal", to: "\(to)-wal")
        StorageManager.moveFileOrDirectoryIfPossible("\(from)-shm", to: "\(to)-shm")
    }

    private func getBlockKey(index: Int) -> String {
        return "masterkey_\(userAddressString)_block_\(index)"
    }

    private func getDeprecatedBlockKey(index: Int) -> String {
        return "block_\(index)"
    }

    private func getNameKey() -> String {
        return "user_name_\(userAddressString)"
    }

    private func getOrganizationKey() -> String {
        return "user_organization_\(userAddressString)"
    }

    private func getFooterKey() -> String {
        return "user_footer_\(userAddressString)"
    }

    private func getAvatarTypeKey() -> String {
        return "user_avatar_mime_type_\(userAddressString)"
    }

    private func getDocumentsDirectory() -> String {
        return NSSearchPathForDirectoriesInDomains(
            .DocumentDirectory, .UserDomainMask, true).first!
    }

    private func getUserDirectory() -> String {
        let userDir = "\(getDocumentsDirectory())/\(userAddress.toString())"
        StorageManager.createDirectory(userDir)
        StorageManager.excludeDirectoryFromBackup(userDir)
        return userDir
    }

    private func getAvatarPath() -> String {
        return "\(getUserDirectory())/avatar.jpg"
    }

    private func loadAvatar() -> NSData? {
        return NSData(contentsOfFile: getAvatarPath())
    }

    private func saveAvatar(avatar: NSData?) {
        precondition(avatar == nil || avatar!.length > 0)

        if let avatar = avatar {
            let avatarPath = getAvatarPath()
            if !avatar.writeToFile(avatarPath, atomically: true) {
                log.error("Writing the avatar to \(avatarPath) failed.")
            }

        } else {
            StorageManager.removeFileOrDirectoryIfPossible(getAvatarPath())
        }
    }

    private class func createDirectory(path: String) {
        let fileManager = NSFileManager.defaultManager()
        if (!fileManager.fileExistsAtPath(path)) {
            try! fileManager.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
        }
    }

    private class func excludeDirectoryFromBackup(path: String) {
        let url = NSURL.init(fileURLWithPath: path, isDirectory: true)
        try! url.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
    }

    private class func moveFileOrDirectoryIfPossible(from: String, to: String) {
        let fileManager = NSFileManager.defaultManager()

        // do nothing if source doesn't exist
        if !fileManager.fileExistsAtPath(from) {
            return
        }

        // delete target directory if it exists and is empty
        if let contents = try? fileManager.contentsOfDirectoryAtPath(to) {
            if contents.isEmpty {
                removeFileOrDirectoryIfPossible(to)
            }
        }

        do {
            try fileManager.moveItemAtPath(from, toPath: to)
        } catch {
            // ignore
        }
    }

    private class func removeFileOrDirectoryIfPossible(path: String) {
        do {
            try NSFileManager.defaultManager().removeItemAtPath(path)
        } catch {
            // ignore
        }
    }

}
