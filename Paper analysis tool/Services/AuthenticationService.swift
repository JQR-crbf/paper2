import Foundation
import Combine

/// 身份验证服务，处理用户登录和注册
class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    // 模拟用户数据库
    private var users: [String: UserData] = [
        "admin": UserData(username: "admin", password: "admin123", email: "admin@example.com"),
        "test": UserData(username: "test", password: "test123", email: "test@example.com")
    ]
    
    // 当前登录用户
    @Published var currentUser: UserData?
    
    private init() {}
    
    /// 用户登录
    /// - Parameters:
    ///   - username: 用户名
    ///   - password: 密码
    /// - Returns: 登录是否成功
    func login(username: String, password: String) -> Bool {
        // 检查用户名和密码是否匹配
        if let userData = users[username.lowercased()], userData.password == password {
            currentUser = userData
            return true
        }
        return false
    }
    
    /// 用户注册
    /// - Parameters:
    ///   - username: 用户名
    ///   - password: 密码
    ///   - email: 电子邮件
    /// - Returns: 注册是否成功
    func register(username: String, password: String, email: String) -> Bool {
        // 检查用户名是否已存在
        let lowerUsername = username.lowercased()
        if users[lowerUsername] != nil {
            return false
        }
        
        // 检查邮箱是否已被使用
        for (_, userData) in users where userData.email.lowercased() == email.lowercased() {
            return false
        }
        
        // 创建新用户
        let newUser = UserData(username: username, password: password, email: email)
        users[lowerUsername] = newUser
        return true
    }
    
    /// 登出当前用户
    func logout() {
        currentUser = nil
    }
    
    /// 修改密码
    /// - Parameters:
    ///   - username: 用户名
    ///   - currentPassword: 当前密码
    ///   - newPassword: 新密码
    /// - Returns: 修改是否成功
    func changePassword(username: String, currentPassword: String, newPassword: String) -> Bool {
        if var userData = users[username.lowercased()], userData.password == currentPassword {
            userData.password = newPassword
            users[username.lowercased()] = userData
            return true
        }
        return false
    }
    
    /// 重置密码（模拟发送重置链接）
    /// - Parameter email: 用户邮箱
    /// - Returns: 重置请求是否成功
    func resetPassword(email: String) -> Bool {
        // 检查邮箱是否存在
        for (_, userData) in users where userData.email.lowercased() == email.lowercased() {
            // 模拟发送重置链接
            print("发送密码重置链接到: \(email)")
            return true
        }
        return false
    }
}

/// 用户数据模型
struct UserData: Codable, Identifiable {
    var id: String { username }
    let username: String
    var password: String
    let email: String
    var profileImageName: String?
    var displayName: String?
    var createdAt: Date = Date()
    var lastLogin: Date?
    
    init(username: String, password: String, email: String) {
        self.username = username
        self.password = password
        self.email = email
    }
} 