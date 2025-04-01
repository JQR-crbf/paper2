import SwiftUI

struct LoginView: View {
    @EnvironmentObject var userSettings: UserSettings
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var email: String = ""
    @State private var isRegistering: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var isAuthenticating: Bool = false
    @State private var rememberMe: Bool = true
    
    // 模拟用户身份验证服务
    @ObservedObject private var authService = AuthenticationService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                LinearGradient(gradient: 
                    Gradient(colors: [Color.blue.opacity(0.5), Color.purple.opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 应用标志
                    VStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                        
                        Text("论文分析工具")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(isRegistering ? "创建账号" : "欢迎回来")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 30)
                    
                    // 表单
                    VStack(spacing: 15) {
                        // 登录表单容器
                        VStack(spacing: 15) {
                            // 用户名输入
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(.gray)
                                TextField("用户名", text: $username)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                            
                            // 邮箱输入 (仅注册时显示)
                            if isRegistering {
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.gray)
                                    TextField("邮箱", text: $email)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                .padding()
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(10)
                            }
                            
                            // 密码输入
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(.gray)
                                SecureField("密码", text: $password)
                            }
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                            
                            // 记住登录信息选项
                            if !isRegistering {
                                Toggle("记住我", isOn: $rememberMe)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.top, 5)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // 登录/注册按钮
                        Button(action: {
                            isAuthenticating = true
                            if isRegistering {
                                registerUser()
                            } else {
                                loginUser()
                            }
                        }) {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(width: 24, height: 24)
                            } else {
                                Text(isRegistering ? "注册" : "登录")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                        .disabled(isAuthenticating || !isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.6)
                        
                        // 切换登录/注册
                        Button(action: {
                            isRegistering.toggle()
                            // 切换时清空输入
                            password = ""
                            if isRegistering {
                                email = ""
                            }
                        }) {
                            Text(isRegistering ? "已有账号？登录" : "没有账号？注册")
                                .foregroundColor(.white)
                                .underline()
                        }
                        .padding(.top, 10)
                        
                        // 访客登录选项
                        if !isRegistering {
                            Button(action: guestLogin) {
                                Text("访客模式")
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.top, 10)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .alert(isPresented: $showingAlert) {
                    Alert(
                        title: Text(alertTitle),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("确定"))
                    )
                }
                .onAppear {
                    // 尝试自动登录
                    if let savedUsername = UserDefaults.standard.string(forKey: "savedUsername"),
                       let savedPassword = KeychainManager.get(username: savedUsername) {
                        username = savedUsername
                        password = savedPassword
                        if userSettings.autoLogin {
                            loginUser()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // 验证表单是否有效
    private var isFormValid: Bool {
        if isRegistering {
            // 注册表单验证
            return !username.isEmpty && !password.isEmpty && !email.isEmpty && password.count >= 6 && isValidEmail(email)
        } else {
            // 登录表单验证
            return !username.isEmpty && !password.isEmpty
        }
    }
    
    // 登录功能
    private func loginUser() {
        // 模拟网络延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if authService.login(username: username, password: password) {
                // 登录成功
                userSettings.isLoggedIn = true
                userSettings.username = username
                
                // 保存登录信息（如果选择了"记住我"）
                if rememberMe {
                    UserDefaults.standard.set(username, forKey: "savedUsername")
                    KeychainManager.save(username: username, password: password)
                    userSettings.autoLogin = true
                } else {
                    userSettings.autoLogin = false
                }
                
                isAuthenticating = false
            } else {
                // 登录失败
                isAuthenticating = false
                alertTitle = "登录失败"
                alertMessage = "用户名或密码错误。请重试。"
                showingAlert = true
            }
        }
    }
    
    // 注册功能
    private func registerUser() {
        // 模拟网络延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if authService.register(username: username, password: password, email: email) {
                // 注册成功
                isAuthenticating = false
                alertTitle = "注册成功"
                alertMessage = "您的账号已创建。现在可以登录了。"
                showingAlert = true
                isRegistering = false
            } else {
                // 注册失败
                isAuthenticating = false
                alertTitle = "注册失败"
                alertMessage = "用户名或邮箱已被使用。请尝试其他用户名或邮箱。"
                showingAlert = true
            }
        }
    }
    
    // 访客登录
    private func guestLogin() {
        userSettings.isLoggedIn = true
        userSettings.username = "访客用户"
        userSettings.isGuestUser = true
    }
    
    // 验证邮箱格式
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(UserSettings())
    }
} 