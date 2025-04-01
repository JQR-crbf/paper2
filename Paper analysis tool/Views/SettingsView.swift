//
//  SettingsView.swift
//  Paper analysis tool
//
//  Created by 金倩如AI on 2025/4/1.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var dataStore: DataStore
    @State private var showingResetAlert = false
    @State private var showingBackupSheet = false
    @State private var showingRestoreSheet = false
    @State private var showLogoutAlert = false
    
    // AI设置临时变量
    @State private var tempApiKeys: [AIServiceProvider: String] = [:]
    @State private var tempApiEndpoints: [AIServiceProvider: String] = [:]
    @State private var showSavedAlert = false
    @State private var enableKnowledgeBase: Bool = false
    @State private var knowledgeBaseId: String = ""
    
    var body: some View {
        Form {
            // 主题设置部分
            Section {
                Toggle("深色模式", isOn: $userSettings.isDarkMode)
                
                HStack {
                    Text("字体大小")
                    Spacer()
                    Slider(value: $userSettings.fontSize, in: 8...24, step: 1)
                        .frame(width: 150)
                    Text(String(format: "%.1f", userSettings.fontSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Picker("默认PDF视图模式", selection: $userSettings.defaultPageLayout) {
                    ForEach(PDFPageLayout.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            } header: {
                Text("显示设置")
            }
            
            // AI设置部分
            Section(header: Text("AI设置").font(.headline)) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("AI服务提供商", selection: $userSettings.aiServiceProvider) {
                        ForEach(AIServiceProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: userSettings.aiServiceProvider) { newValue in
                        // 当切换提供商时，更新模型选择
                        let compatibleModels = AIModel.allCases.filter { $0.provider == newValue }
                        if let firstCompatibleModel = compatibleModels.first {
                            userSettings.aiModel = firstCompatibleModel
                        }
                    }
                    
                    let compatibleModels = AIModel.allCases.filter { $0.provider == userSettings.aiServiceProvider }
                    
                    Picker("AI模型", selection: $userSettings.aiModel) {
                        ForEach(compatibleModels, id: \.self) { model in
                            Text(model.rawValue).tag(model)
                        }
                    }
                    .pickerStyle(DefaultPickerStyle())
                    
                    Text("API密钥配置")
                        .font(.headline)
                        .padding(.top, 10)
                    
                    SecureField("API密钥", text: Binding(
                        get: { tempApiKeys[userSettings.aiServiceProvider] ?? "" },
                        set: { tempApiKeys[userSettings.aiServiceProvider] = $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    
                    TextField("API端点 (可选)", text: Binding(
                        get: { tempApiEndpoints[userSettings.aiServiceProvider] ?? userSettings.aiServiceProvider.defaultEndpoint },
                        set: { tempApiEndpoints[userSettings.aiServiceProvider] = $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    
                    HStack {
                        Button(action: {
                            userSettings.aiApiKeys[userSettings.aiServiceProvider] = tempApiKeys[userSettings.aiServiceProvider] ?? ""
                            userSettings.aiApiEndpoints[userSettings.aiServiceProvider] = tempApiEndpoints[userSettings.aiServiceProvider] ?? userSettings.aiServiceProvider.defaultEndpoint
                            userSettings.saveSettings()
                            showSavedAlert = true
                        }) {
                            Text("保存API设置")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        if showSavedAlert {
                            Text("已保存！")
                                .foregroundColor(.green)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showSavedAlert = false
                                    }
                                }
                        }
                    }
                    
                    Toggle("使用模拟数据", isOn: $userSettings.useSimulatedData)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    // 通义千问知识库配置
                    if userSettings.aiServiceProvider == .tongyi {
                        Divider()
                        
                        Text("通义千问知识库配置")
                            .font(.headline)
                            .padding(.top, 5)
                        
                        Toggle("启用知识库检索", isOn: $enableKnowledgeBase)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                        
                        if enableKnowledgeBase {
                            TextField("知识库ID", text: $knowledgeBaseId)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            Button(action: {
                                userSettings.saveKnowledgeBaseSettings(enableKnowledgeBase: enableKnowledgeBase, knowledgeBaseId: knowledgeBaseId)
                                showSavedAlert = true
                            }) {
                                Text("保存知识库设置")
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            
                            Text("通义千问知识库可以提升论文分析能力")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 根据不同提供商显示相应的文档链接
                    switch userSettings.aiServiceProvider {
                    case .openAI:
                        Link("OpenAI API文档", destination: URL(string: "https://platform.openai.com/docs/api-reference")!)
                    case .tongyi:
                        Link("通义千问API文档", destination: URL(string: "https://help.aliyun.com/document_detail/2400395.html")!)
                    case .siliconFlow:
                        Link("硅基流动API文档", destination: URL(string: "https://cloud.siliconflow.cn/docs")!)
                    case .custom:
                        Text("请按照所选AI服务的格式配置API")
                    }
                }
                .padding(.vertical, 10)
            }
            
            // 存储设置部分
            Section {
                Button("立即清理缓存") {
                    // 调用缓存清理功能
                }
                .foregroundColor(.blue)
            } header: {
                Text("存储设置")
            }
            
            // 数据管理部分
            Section {
                Button("创建备份") {
                    showingBackupSheet = true
                }
                .foregroundColor(.blue)
                
                Button("从备份恢复") {
                    showingRestoreSheet = true
                }
                .foregroundColor(.blue)
                
                Button("重置所有设置") {
                    showingResetAlert = true
                }
                .foregroundColor(.red)
            } header: {
                Text("数据管理")
            }
            
            // 关于部分
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link("访问官方网站", destination: URL(string: "https://www.example.com")!)
                
                Link("隐私政策", destination: URL(string: "https://www.example.com/privacy")!)
            } header: {
                Text("关于")
            }
            
            // 账户管理部分
            Section(header: Text("账户管理").font(.headline)) {
                VStack(spacing: 10) {
                    if !userSettings.isGuestUser {
                        HStack {
                            Text("当前用户")
                            Spacer()
                            Text(userSettings.username)
                                .foregroundColor(.gray)
                        }
                        
                        NavigationLink(destination: AccountSettingsView()) {
                            Text("账户设置")
                        }
                    } else {
                        Text("您当前以访客身份登录")
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("注销")
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .onAppear {
            // 初始化临时密钥和端点
            for provider in AIServiceProvider.allCases {
                tempApiKeys[provider] = userSettings.aiApiKeys[provider] ?? ""
                tempApiEndpoints[provider] = userSettings.aiApiEndpoints[provider] ?? provider.defaultEndpoint
            }
        }
        .alert("重置确认", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                userSettings.resetToDefaults()
            }
        } message: {
            Text("确定要将所有设置恢复为默认值吗？此操作不会删除您的论文数据。")
        }
        .sheet(isPresented: $showingBackupSheet) {
            BackupView()
                .environmentObject(dataStore)
        }
        .sheet(isPresented: $showingRestoreSheet) {
            RestoreView()
                .environmentObject(dataStore)
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("确认注销"),
                message: Text("确定要注销当前账户吗？"),
                primaryButton: .destructive(Text("注销")) {
                    userSettings.logout()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
}

struct BackupView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("创建备份")
                    .font(.title)
                    .padding()
                
                Text("备份功能尚未实现")
                    .padding()
                
                Button("关闭") {
                    dismiss()
                }
                .padding()
            }
            .navigationBarTitle("备份", displayMode: .inline)
            .navigationBarItems(trailing: Button("关闭") {
                dismiss()
            })
        }
    }
}

struct RestoreView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("从备份恢复")
                    .font(.title)
                    .padding()
                
                Text("恢复功能尚未实现")
                    .padding()
                
                Button("关闭") {
                    dismiss()
                }
                .padding()
            }
            .navigationBarTitle("恢复", displayMode: .inline)
            .navigationBarItems(trailing: Button("关闭") {
                dismiss()
            })
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(UserSettings.shared)
            .environmentObject(DataStore())
    }
} 