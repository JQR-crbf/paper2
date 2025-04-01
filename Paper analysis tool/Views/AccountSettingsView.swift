import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.presentationMode) var presentationMode
    
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @State private var showingPasswordSection = false
    @State private var isSaving = false
    
    // 身份验证服务
    private let authService = AuthenticationService.shared
    
    var body: some View {
        Form {
            if !userSettings.isGuestUser {
                Section(header: Text("个人信息").font(.headline)) {
                    VStack(alignment: .center, spacing: 20) {
                        // 头像
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            Text(String(userSettings.username.prefix(1).uppercased()))
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 10)
                        
                        // 用户名
                        Text(userSettings.username)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    
                    // 显示名称
                    HStack {
                        Text("显示名称")
                        Spacer()
                        TextField("设置显示名称", text: $displayName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // 电子邮箱
                    HStack {
                        Text("电子邮箱")
                        Spacer()
                        TextField("设置电子邮箱", text: $email)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                
                Section(header: Text("安全设置").font(.headline)) {
                    Toggle("修改密码", isOn: $showingPasswordSection)
                    
                    if showingPasswordSection {
                        SecureField("当前密码", text: $currentPassword)
                        SecureField("新密码", text: $newPassword)
                            .onChange(of: newPassword) { _, _ in
                                validatePassword()
                            }
                        SecureField("确认新密码", text: $confirmPassword)
                            .onChange(of: confirmPassword) { _, _ in
                                validatePassword()
                            }
                        
                        if !passwordValidationMessage.isEmpty {
                            Text(passwordValidationMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section {
                    Button(action: saveChanges) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("保存更改")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(!isFormValid || isSaving)
                }
            } else {
                Section {
                    Text("访客账户无法修改账户设置。请注册一个账户以使用此功能。")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
        .navigationTitle("账户设置")
        .onAppear(perform: loadUserData)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("确定")) {
                    if alertTitle == "成功" {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
    }
    
    private var passwordValidationMessage: String {
        if newPassword.isEmpty || confirmPassword.isEmpty {
            return ""
        }
        
        if newPassword.count < 6 {
            return "密码长度至少为6个字符"
        }
        
        if newPassword != confirmPassword {
            return "两次输入的密码不一致"
        }
        
        return ""
    }
    
    private var isFormValid: Bool {
        if showingPasswordSection {
            return !currentPassword.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty && 
                   newPassword == confirmPassword && newPassword.count >= 6
        }
        return true
    }
    
    private func loadUserData() {
        // 如果用户是访客，不加载数据
        if userSettings.isGuestUser {
            return
        }
        
        // 从数据库或UserSettings加载数据
        if let userData = authService.currentUser {
            displayName = userData.displayName ?? ""
            email = userData.email
        }
    }
    
    private func saveChanges() {
        // 如果用户是访客，不保存数据
        if userSettings.isGuestUser {
            return
        }
        
        isSaving = true
        
        // 模拟网络延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            var success = true
            var message = "个人信息已更新"
            
            // 保存个人信息
            // TODO: 实现实际的数据保存逻辑
            
            // 修改密码（如果需要）
            if showingPasswordSection && !currentPassword.isEmpty && !newPassword.isEmpty {
                if authService.changePassword(username: userSettings.username, 
                                             currentPassword: currentPassword, 
                                             newPassword: newPassword) {
                    // 更新保存的密码（如果有）
                    if let savedUsername = UserDefaults.standard.string(forKey: "savedUsername"),
                       savedUsername == userSettings.username {
                        _ = KeychainManager.update(username: savedUsername, newPassword: newPassword)
                    }
                    
                    message = "个人信息和密码已更新"
                } else {
                    success = false
                    message = "当前密码不正确"
                }
            }
            
            isSaving = false
            
            alertTitle = success ? "成功" : "错误"
            alertMessage = message
            showingAlert = true
            
            // 清空密码字段
            if success {
                currentPassword = ""
                newPassword = ""
                confirmPassword = ""
                showingPasswordSection = false
            }
        }
    }
    
    private func validatePassword() {
        // 验证逻辑已在passwordValidationMessage计算属性中实现
        // 此方法仅用于onChange事件的回调
    }
}

struct AccountSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AccountSettingsView()
                .environmentObject(UserSettings.shared)
        }
    }
} 