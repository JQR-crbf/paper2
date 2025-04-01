import Foundation
import Security

/// 钥匙串管理器，用于安全存储用户凭证
class KeychainManager {
    enum KeychainError: Error {
        case duplicateEntry
        case unknown(OSStatus)
        case notFound
        case invalidData
    }
    
    /// 保存用户名和密码到钥匙串
    /// - Parameters:
    ///   - username: 用户名
    ///   - password: 密码
    /// - Returns: 操作是否成功
    static func save(username: String, password: String) -> Bool {
        // 在保存前先尝试删除已有项
        _ = delete(username: username)
        
        let passwordData = password.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: username,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        return status == errSecSuccess
    }
    
    /// 从钥匙串获取指定用户名的密码
    /// - Parameter username: 用户名
    /// - Returns: 密码或者nil（如果未找到）
    static func get(username: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: username,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        guard let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// 从钥匙串删除指定用户名的密码
    /// - Parameter username: 用户名
    /// - Returns: 操作是否成功
    static func delete(username: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: username
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// 更新钥匙串中指定用户名的密码
    /// - Parameters:
    ///   - username: 用户名
    ///   - newPassword: 新密码
    /// - Returns: 操作是否成功
    static func update(username: String, newPassword: String) -> Bool {
        let passwordData = newPassword.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: username
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: passwordData
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        return status == errSecSuccess
    }
} 