/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import LibKullo
import SwiftKeychainWrapper

class StorageManager {

    fileprivate let keychain = KeychainWrapper.standard

    //MARK: public interface

    let userAddress: KAAddress

    class func getLastUserAddress() -> KAAddress? {
        let keychain = KeychainWrapper.standard
        if let addrString = keychain.string(forKey: KEY_ADDRESS, withAccessibility: .afterFirstUnlock) {
            return KAAddress.create(addrString)
        }

        // try old accessibility setting because we're potentially running before migrate() has run
        if let addrString = keychain.string(forKey: KEY_ADDRESS) {
            return KAAddress.create(addrString)
        }
        return nil
    }

    init(address: KAAddress) {
        userAddress = address
        userAddressString = address.toString()

        migrate()
    }

    func loadCredentials() -> Credentials? {
        var blockList = [String]()
        for index in 0...15 {
            blockList.append(keychain.string(forKey: getBlockKey(index), withAccessibility: .afterFirstUnlock)!)
        }
        guard let masterKey = KAMasterKey.create(fromDataBlocks: blockList) else {
            return nil
        }
        return Credentials(address: userAddress, masterKey: masterKey)
    }

    func migrateUserSettings(_ userSettings: KAUserSettings) {
        // If these keys exist, the have been written with default accessibility, so don't pass .AfterFirstUnlock
        if let name = keychain.string(forKey: getNameKey()) {
            userSettings.setName(name)
            keychain.removeObject(forKey: getNameKey())
        }
        if let organization = keychain.string(forKey: getOrganizationKey()) {
            userSettings.setOrganization(organization)
            keychain.removeObject(forKey: getOrganizationKey())
        }
        if let footer = keychain.string(forKey: getFooterKey()) {
            userSettings.setFooter(footer)
            keychain.removeObject(forKey: getFooterKey())
        }
        if var avatarMimeType = keychain.string(forKey: getAvatarTypeKey()) {
            // fix wrong MIME type that has been set previously by this app
            if avatarMimeType == "image/jpg" {
                avatarMimeType = "image/jpeg"
            }
            userSettings.setAvatarMimeType(avatarMimeType)
            keychain.removeObject(forKey: getAvatarTypeKey())
        }
        if let avatar = loadAvatar() {
            userSettings.setAvatar(avatar)
            saveAvatar(nil)
        }
    }

    func saveCredentials(_ address: KAAddress, masterKey: KAMasterKey) {
        keychain.set(address.toString(), forKey: StorageManager.KEY_ADDRESS, withAccessibility: .afterFirstUnlock)

        let blockList = masterKey.dataBlocks()
        for (index, block) in blockList.enumerated() {
            keychain.set(block, forKey: getBlockKey(index), withAccessibility: .afterFirstUnlock)
        }
    }

    func getDbPath() -> String {
        return "\(getUserDirectory())/sync.db"
    }

    class func getTempPathForView(_ viewName: String, filename: String = "") -> String {
        let dir = "\(NSTemporaryDirectory())/\(viewName)"
        StorageManager.createDirectory(dir)
        return "\(dir)/\(filename)"
    }

    func deleteAllData() {
        StorageManager.removeFileOrDirectoryIfPossible(getUserDirectory())
        if !keychain.removeAllKeys() {
            log.error("Couldn't delete all keychain data.")
        }
    }


    //MARK: private implementation

    fileprivate static let CURRENT_STORAGE_VERSION = 2
    fileprivate let userAddressString: String

    fileprivate static let KEY_ADDRESS = "kullo_address"
    fileprivate static let KEY_STORAGE_VERSION = "kullo_storage_version"
    fileprivate static let DEFAULTS_KEY_STORAGE_VERSION = "KulloStorageVersion"

    fileprivate func migrate() {
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
                    if let block = keychain.string(forKey: deprecatedBlockKey) {
                        keychain.set(block, forKey: getBlockKey(index))
                        keychain.removeObject(forKey: deprecatedBlockKey)
                    }
                }

            case 1:
                // convert address from default accessibility to AfterFirstUnlock
                if let addrString = keychain.string(forKey: StorageManager.KEY_ADDRESS) {
                    keychain.removeObject(forKey: StorageManager.KEY_ADDRESS)
                    keychain.set(addrString, forKey: StorageManager.KEY_ADDRESS, withAccessibility: .afterFirstUnlock)
                }

                // convert MasterKey blocks from default accessibility to AfterFirstUnlock
                for index in 0...15 {
                    let blockKey = getBlockKey(index);
                    if let block = keychain.string(forKey: blockKey) {
                        keychain.removeObject(forKey: blockKey)
                        keychain.set(block, forKey: getBlockKey(index), withAccessibility: .afterFirstUnlock)
                    }
                }
                break

            default:
                preconditionFailure("unsupported storage version: \(storageVersion)")
            }
            storageVersion += 1
            setStorageVersion(storageVersion)

            log.info("Finished migration to storage version \(storageVersion)")
        }
    }

    fileprivate func getStorageVersion() -> Int {
        if let storageVersion = keychain.integer(forKey: StorageManager.KEY_STORAGE_VERSION, withAccessibility: .afterFirstUnlock) {
            return storageVersion
        }

        // try to move storage version from deprecated encoding (string) and accessibility level
        if let storageVersion = keychain.string(forKey: StorageManager.KEY_STORAGE_VERSION) {
            if let storageVersion = Int(storageVersion) {
                keychain.removeObject(forKey: StorageManager.KEY_STORAGE_VERSION)
                setStorageVersion(storageVersion)
                return storageVersion
            }
        }

        // try to move storage version from deprecated location (UserDefaults) to KeyChain
        let defaults = UserDefaults.standard
        let storageVersion = defaults.integer(forKey: StorageManager.DEFAULTS_KEY_STORAGE_VERSION)

        if storageVersion > 0 {
            setStorageVersion(storageVersion)
            defaults.removeObject(forKey: StorageManager.DEFAULTS_KEY_STORAGE_VERSION)
            defaults.synchronize()
        }
        return storageVersion
    }

    fileprivate func setStorageVersion(_ storageVersion: Int) {
        keychain.set(storageVersion, forKey: StorageManager.KEY_STORAGE_VERSION, withAccessibility: .afterFirstUnlock)
    }

    fileprivate func moveDb(_ from: String, to: String) {
        StorageManager.moveFileOrDirectoryIfPossible(from, to: to)
        StorageManager.moveFileOrDirectoryIfPossible("\(from)-wal", to: "\(to)-wal")
        StorageManager.moveFileOrDirectoryIfPossible("\(from)-shm", to: "\(to)-shm")
    }

    fileprivate func getBlockKey(_ index: Int) -> String {
        return "masterkey_\(userAddressString)_block_\(index)"
    }

    fileprivate func getDeprecatedBlockKey(_ index: Int) -> String {
        return "block_\(index)"
    }

    fileprivate func getNameKey() -> String {
        return "user_name_\(userAddressString)"
    }

    fileprivate func getOrganizationKey() -> String {
        return "user_organization_\(userAddressString)"
    }

    fileprivate func getFooterKey() -> String {
        return "user_footer_\(userAddressString)"
    }

    fileprivate func getAvatarTypeKey() -> String {
        return "user_avatar_mime_type_\(userAddressString)"
    }

    fileprivate func getDocumentsDirectory() -> String {
        return NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true).first!
    }

    fileprivate func getUserDirectory() -> String {
        let userDir = "\(getDocumentsDirectory())/\(userAddress.toString())"
        StorageManager.createDirectory(userDir)
        StorageManager.excludeDirectoryFromBackup(userDir)
        return userDir
    }

    fileprivate func getAvatarPath() -> String {
        return "\(getUserDirectory())/avatar.jpg"
    }

    fileprivate func loadAvatar() -> Data? {
        return (try? Data(contentsOf: URL(fileURLWithPath: getAvatarPath())))
    }

    fileprivate func saveAvatar(_ avatar: Data?) {
        precondition(avatar == nil || avatar!.count > 0)

        if let avatar = avatar {
            let avatarPath = getAvatarPath()
            do {
                try avatar.write(to: URL(fileURLWithPath: avatarPath), options: [.atomic])
            } catch let err {
                log.error("Writing the avatar to \(avatarPath) failed: \(err)")
            }

        } else {
            StorageManager.removeFileOrDirectoryIfPossible(getAvatarPath())
        }
    }

    fileprivate class func createDirectory(_ path: String) {
        let fileManager = FileManager.default
        if (!fileManager.fileExists(atPath: path)) {
            try! fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
    }

    fileprivate class func excludeDirectoryFromBackup(_ path: String) {
        var url = URL(fileURLWithPath: path, isDirectory: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try! url.setResourceValues(resourceValues)
    }

    fileprivate class func moveFileOrDirectoryIfPossible(_ from: String, to: String) {
        let fileManager = FileManager.default

        // do nothing if source doesn't exist
        if !fileManager.fileExists(atPath: from) {
            return
        }

        // delete target directory if it exists and is empty
        if let contents = try? fileManager.contentsOfDirectory(atPath: to) {
            if contents.isEmpty {
                removeFileOrDirectoryIfPossible(to)
            }
        }

        do {
            try fileManager.moveItem(atPath: from, toPath: to)
        } catch {
            // ignore
        }
    }

    class func removeFileOrDirectoryIfPossible(_ path: String) {
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            // ignore
        }
    }

}
