/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import LibKullo
import SwiftKeychainWrapper

class StorageManager {

    //MARK: - public interface

    let userAddress: KAAddress

    class func getLastUserAddress() -> KAAddress? {
        let keychain = KeychainWrapper.standard
        if let addrString = keychain.string(forKey: KEY_ADDRESS, withAccessibility: .afterFirstUnlock) {
            return KAAddressHelpers.create(addrString)
        }

        // try old accessibility setting because we're potentially running before migrate() has run
        if let addrString = keychain.string(forKey: KEY_ADDRESS) {
            return KAAddressHelpers.create(addrString)
        }
        return nil
    }

    class func getAccounts() -> [KAAddress] {
        let keys = KeychainWrapper.standard.allKeys().filter(StorageManager.masterkeyBlock0Filter)
        return keys.flatMap(addressFromBlockKey).sorted(by: { (lhs, rhs) in
            lhs.description() < rhs.description()
        })
    }

    init(address: KAAddress) {
        userAddress = address
        userAddressString = address.description()

        migrate()
    }

    func loadCredentials() -> Credentials? {
        var blockList = [String]()
        for index in 0...15 {
            blockList.append(keychain.string(forKey: getBlockKey(index), withAccessibility: .afterFirstUnlock)!)
        }
        guard let masterKey = KAMasterKeyHelpers.create(fromDataBlocks: blockList) else {
            return nil
        }
        return Credentials(address: userAddress, masterKey: masterKey)
    }

    func migrateUserSettings(_ userSettings: KAUserSettings) {
        // If these keys exist, they have been written with default accessibility, so don't pass .AfterFirstUnlock
        if let name = keychain.string(forKey: nameKey) {
            userSettings.setName(name)
            keychain.removeObject(forKey: nameKey)
        }
        if let organization = keychain.string(forKey: organizationKey) {
            userSettings.setOrganization(organization)
            keychain.removeObject(forKey: organizationKey)
        }
        if let footer = keychain.string(forKey: footerKey) {
            userSettings.setFooter(footer)
            keychain.removeObject(forKey: footerKey)
        }
        if var avatarMimeType = keychain.string(forKey: avatarTypeKey) {
            // fix wrong MIME type that has been set previously by this app
            if avatarMimeType == "image/jpg" {
                avatarMimeType = "image/jpeg"
            }
            userSettings.setAvatarMimeType(avatarMimeType)
            keychain.removeObject(forKey: avatarTypeKey)
        }
        if let avatar = loadAvatar() {
            userSettings.setAvatar(avatar)
            saveAvatar(nil)
        }
    }

    func saveLoggedInUser(masterKey: KAMasterKey?) {
        keychain.set(
            userAddress.description(),
            forKey: StorageManager.KEY_ADDRESS,
            withAccessibility: .afterFirstUnlock)

        if let blockList = masterKey?.blocks {
            for (index, block) in blockList.enumerated() {
                keychain.set(block, forKey: getBlockKey(index), withAccessibility: .afterFirstUnlock)
            }
        }
    }

    var dbPath: String {
        return "\(userDirectory)/sync.db"
    }

    class func getTempPathForView(_ viewName: String, filename: String = "") -> String {
        let dir = "\(NSTemporaryDirectory())/\(viewName)"
        StorageManager.createDirectory(dir)
        return "\(dir)/\(filename)"
    }

    func deleteUserData() {
        StorageManager.removeFileOrDirectoryIfPossible(userDirectory)
        for index in 0...15 {
            keychain.removeObject(forKey: getBlockKey(index), withAccessibility: .afterFirstUnlock)
        }

        if let lastUserAddress = StorageManager.getLastUserAddress(), lastUserAddress == userAddress {
            keychain.removeObject(forKey: StorageManager.KEY_ADDRESS, withAccessibility: .afterFirstUnlock)
        }
    }


    //MARK: - private implementation

    private let keychain = KeychainWrapper.standard

    private static let CURRENT_STORAGE_VERSION = 2
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
                    "\(documentsDirectory)/\(userAddress.localPart)",
                    to: userDirectory)

                // move avatar into user directory and remove address from filename
                StorageManager.moveFileOrDirectoryIfPossible(
                    "\(documentsDirectory)/user_avatar_\(userAddressString)",
                    to: avatarPath)

                // remove address and closing parenthesis from DB filename
                moveDb(
                    "\(userDirectory)/\(userAddress.localPart).db)",
                    to: dbPath)

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

    private func getStorageVersion() -> Int {
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

    private func setStorageVersion(_ storageVersion: Int) {
        keychain.set(storageVersion, forKey: StorageManager.KEY_STORAGE_VERSION, withAccessibility: .afterFirstUnlock)
    }

    private func moveDb(_ from: String, to: String) {
        StorageManager.moveFileOrDirectoryIfPossible(from, to: to)
        StorageManager.moveFileOrDirectoryIfPossible("\(from)-wal", to: "\(to)-wal")
        StorageManager.moveFileOrDirectoryIfPossible("\(from)-shm", to: "\(to)-shm")
    }

    private static func masterkeyBlock0Filter(_ key: String) -> Bool {
        return key.hasPrefix("masterkey_") && key.hasSuffix("_block_0")
    }

    private static func addressFromBlockKey(_ key: String) -> KAAddress? {
        let keySplitByUnderscore = key.split(
            separator: "_",
            maxSplits: 2,
            omittingEmptySubsequences: false)
        guard keySplitByUnderscore.count >= 3 else { return nil }

        return KAAddressHelpers.create(String(keySplitByUnderscore[1]))
    }

    private func getBlockKey(_ index: Int) -> String {
        return "masterkey_\(userAddressString)_block_\(index)"
    }

    private func getDeprecatedBlockKey(_ index: Int) -> String {
        return "block_\(index)"
    }

    private var nameKey: String {
        return "user_name_\(userAddressString)"
    }

    private var organizationKey: String {
        return "user_organization_\(userAddressString)"
    }

    private var footerKey: String {
        return "user_footer_\(userAddressString)"
    }

    private var avatarTypeKey: String {
        return "user_avatar_mime_type_\(userAddressString)"
    }

    private var documentsDirectory: String {
        return NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true).first!
    }

    private var userDirectory: String {
        let userDir = "\(documentsDirectory)/\(userAddress.description())"
        StorageManager.createDirectory(userDir)
        StorageManager.excludeDirectoryFromBackup(userDir)
        return userDir
    }

    private var avatarPath: String {
        return "\(userDirectory)/avatar.jpg"
    }

    private func loadAvatar() -> Data? {
        return try? Data(contentsOf: URL(fileURLWithPath: avatarPath))
    }

    private func saveAvatar(_ avatar: Data?) {
        precondition(avatar == nil || avatar!.count > 0)

        if let avatar = avatar {
            do {
                try avatar.write(to: URL(fileURLWithPath: avatarPath), options: [.atomic])
            } catch let err {
                log.error("Writing the avatar to \(self.avatarPath) failed: \(err)")
            }

        } else {
            StorageManager.removeFileOrDirectoryIfPossible(avatarPath)
        }
    }

    //MARK: utilities

    private class func createDirectory(_ path: String) {
        let fileManager = FileManager.default
        if (!fileManager.fileExists(atPath: path)) {
            try! fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
    }

    private class func excludeDirectoryFromBackup(_ path: String) {
        var url = URL(fileURLWithPath: path, isDirectory: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try! url.setResourceValues(resourceValues)
    }

    private class func moveFileOrDirectoryIfPossible(_ from: String, to: String) {
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

        _ = try? fileManager.moveItem(atPath: from, toPath: to)
    }

    class func removeFileOrDirectoryIfPossible(_ path: String) {
        _ = try? FileManager.default.removeItem(atPath: path)
    }

}
