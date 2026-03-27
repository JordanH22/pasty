import Foundation
import CryptoKit
import os.log

final class EncryptionService: @unchecked Sendable {
    static let shared = EncryptionService()
    
    private let keychainKey = "pasty_encryption_key"
    private let logger = Logger(subsystem: "com.pasty.app", category: "security")
    
    private init() {}
    
    // MARK: - Key Management
    
    /// Gets or creates the symmetric encryption key from Keychain
    private func getOrCreateKey() -> SymmetricKey {
        // Try to load existing key
        if let existingKeyData = KeychainService.shared.retrieveData(forKey: keychainKey) {
            return SymmetricKey(data: existingKeyData)
        }
        
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        KeychainService.shared.saveData(keyData, forKey: keychainKey)
        
        logger.info("Generated new AES-256 encryption key")
        return newKey
    }
    
    // MARK: - Encrypt
    
    func encrypt(_ plaintext: String) throws -> String {
        guard let data = plaintext.data(using: .utf8) else {
            throw EncryptionError.encodingFailed
        }
        
        let key = getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return combined.base64EncodedString()
    }
    
    // MARK: - Decrypt
    
    func decrypt(_ ciphertext: String) throws -> String {
        guard let data = Data(base64Encoded: ciphertext) else {
            throw EncryptionError.decodingFailed
        }
        
        let key = getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decodingFailed
        }
        
        return plaintext
    }
}

// MARK: - Errors

enum EncryptionError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case encryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode text for encryption."
        case .decodingFailed: return "Failed to decode encrypted data."
        case .encryptionFailed: return "Encryption operation failed."
        }
    }
}
