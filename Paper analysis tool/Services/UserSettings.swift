//
//  UserSettings.swift
//  Paper analysis tool
//
//  Created by 金倩如AI on 2023/4/1.
//

import Foundation
import SwiftUI
import Combine

// 在类定义之前添加必要的枚举
enum ColorSchemePreference: String, CaseIterable {
    case light = "浅色"
    case dark = "深色"
    case system = "跟随系统"
}

enum AppLanguage: String, CaseIterable {
    case english = "English"
    case chinese = "中文"
}

enum PDFPageLayout: String, CaseIterable {
    case single = "单页"
    case continuous = "连续"
    case double = "双页"
}

// 修改AIModel枚举以支持各个提供商的不同模型
enum AIModel: String, CaseIterable {
    // OpenAI模型
    case gpt35 = "GPT-3.5"
    case gpt4 = "GPT-4"
    
    // 通义千问模型
    case qwenTurbo = "通义千问-Turbo"
    case qwenPlus = "通义千问-Plus"
    case qwenMax = "通义千问-Max"
    
    // 硅基流动模型
    case deepseekV2 = "Deepseek-V2"
    case deepseekV3 = "Deepseek-V3"
    case deepseekCoder = "Deepseek-Coder"
    
    // 其他模型
    case claude = "Claude"
    case gemini = "Gemini"
    
    var provider: AIServiceProvider {
        switch self {
        case .gpt35, .gpt4:
            return .openAI
        case .qwenTurbo, .qwenPlus, .qwenMax:
            return .tongyi
        case .deepseekV2, .deepseekV3, .deepseekCoder:
            return .siliconFlow
        case .claude, .gemini:
            return .custom
        }
    }
    
    var apiIdentifier: String {
        switch self {
        case .gpt35:
            return "gpt-3.5-turbo"
        case .gpt4:
            return "gpt-4"
        case .qwenTurbo:
            return "qwen-turbo"
        case .qwenPlus:
            return "qwen-plus"
        case .qwenMax:
            return "qwen-max"
        case .deepseekV2:
            return "deepseek-v2"
        case .deepseekV3:
            return "deepseek-v3"
        case .deepseekCoder:
            return "deepseek-coder"
        case .claude:
            return "claude-3-opus-20240229"
        case .gemini:
            return "gemini-pro"
        }
    }
}

enum BackupFrequency: String, CaseIterable {
    case daily = "每天"
    case weekly = "每周"
    case monthly = "每月"
    case never = "从不"
}

/**
 * UserSettings类用于管理用户偏好设置
 * 
 * 注意: 通常应通过shared单例访问此类实例，例如：
 * ```
 * UserSettings.shared
 * ```
 * 直接初始化此类仅用于SwiftUI预览和测试目的。
 */
class UserSettings: ObservableObject {
    // 单例实例
    static let shared = UserSettings()
    
    // 主题设置
    @Published var colorScheme: ColorSchemePreference = .system {
        didSet {
            UserDefaults.standard.set(colorScheme.rawValue, forKey: "colorScheme")
        }
    }
    
    @Published var isDarkMode: Bool = false {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
            colorScheme = isDarkMode ? .dark : .light
        }
    }
    
    @Published var language: AppLanguage = .chinese {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "language")
        }
    }
    
    // 阅读设置
    @Published var defaultPDFZoom: Double = 1.0 {
        didSet {
            UserDefaults.standard.set(defaultPDFZoom, forKey: "defaultPDFZoom")
        }
    }
    
    @Published var defaultPageLayout: PDFPageLayout = .single {
        didSet {
            UserDefaults.standard.set(defaultPageLayout.rawValue, forKey: "defaultPageLayout")
        }
    }
    
    @Published var fontSize: Double = 16.0 {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: "fontSize")
        }
    }
    
    @Published var highlightColor: HighlightColor = .yellow {
        didSet {
            UserDefaults.standard.set(highlightColor.rawValue, forKey: "highlightColor")
        }
    }
    
    @Published var showPageNumber: Bool = true {
        didSet {
            UserDefaults.standard.set(showPageNumber, forKey: "showPageNumber")
        }
    }
    
    @Published var keepLastReadPage: Bool = true {
        didSet {
            UserDefaults.standard.set(keepLastReadPage, forKey: "keepLastReadPage")
        }
    }
    
    @Published var automaticNightMode: Bool = true {
        didSet {
            UserDefaults.standard.set(automaticNightMode, forKey: "automaticNightMode")
        }
    }
    
    // AI分析设置
    @Published var aiServiceProvider: AIServiceProvider = .openAI {
        didSet {
            UserDefaults.standard.set(aiServiceProvider.rawValue, forKey: "aiServiceProvider")
        }
    }
    
    @Published var aiApiKeys: [AIServiceProvider: String] = [:] {
        didSet {
            // 保存密钥
            for (provider, key) in aiApiKeys {
                storeEncryptedApiKey(key, for: provider)
            }
        }
    }
    
    @Published var aiModel: AIModel = .gpt4 {
        didSet {
            UserDefaults.standard.set(aiModel.rawValue, forKey: "aiModel")
            // 确保服务提供商与模型匹配
            aiServiceProvider = aiModel.provider
        }
    }
    
    @Published var aiApiEndpoints: [AIServiceProvider: String] = [:] {
        didSet {
            // 保存各提供商的API端点
            for (provider, endpoint) in aiApiEndpoints {
                UserDefaults.standard.set(endpoint, forKey: "aiApiEndpoint_\(provider.rawValue)")
            }
        }
    }
    
    @Published var useSimulatedData: Bool = true {
        didSet {
            UserDefaults.standard.set(useSimulatedData, forKey: "useSimulatedData")
        }
    }
    
    // 文件导入设置
    @Published var automaticMetadataExtraction: Bool = true {
        didSet {
            UserDefaults.standard.set(automaticMetadataExtraction, forKey: "automaticMetadataExtraction")
        }
    }
    
    @Published var storeFilesCentrally: Bool = true {
        didSet {
            UserDefaults.standard.set(storeFilesCentrally, forKey: "storeFilesCentrally")
        }
    }
    
    @Published var defaultImportLocation: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] {
        didSet {
            // 在iOS中使用更简单的方法保存URL路径
            UserDefaults.standard.set(defaultImportLocation.path, forKey: "defaultImportLocation")
        }
    }
    
    // 通知设置
    @Published var enableNotifications: Bool = true {
        didSet {
            UserDefaults.standard.set(enableNotifications, forKey: "enableNotifications")
        }
    }
    
    // 备份设置
    @Published var autoBackupEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(autoBackupEnabled, forKey: "autoBackupEnabled")
        }
    }
    
    @Published var backupFrequency: BackupFrequency = .weekly {
        didSet {
            UserDefaults.standard.set(backupFrequency.rawValue, forKey: "backupFrequency")
        }
    }
    
    // 用户界面设置
    @Published var defaultTab: Int = 0 {
        didSet {
            UserDefaults.standard.set(defaultTab, forKey: "defaultTab")
        }
    }
    
    @Published var showBibliographicInfo: Bool = true {
        didSet {
            UserDefaults.standard.set(showBibliographicInfo, forKey: "showBibliographicInfo")
        }
    }
    
    // 知识库设置
    @Published var enableKnowledgeBase: Bool = false {
        didSet {
            UserDefaults.standard.set(enableKnowledgeBase, forKey: "enableKnowledgeBase")
        }
    }
    
    @Published var knowledgeBaseId: String = "" {
        didSet {
            UserDefaults.standard.set(knowledgeBaseId, forKey: "knowledgeBaseId")
        }
    }
    
    // 登录相关设置
    @Published var isLoggedIn: Bool = false {
        didSet {
            UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
        }
    }
    
    @Published var username: String = "" {
        didSet {
            UserDefaults.standard.set(username, forKey: "username")
        }
    }
    
    @Published var isGuestUser: Bool = false {
        didSet {
            UserDefaults.standard.set(isGuestUser, forKey: "isGuestUser")
        }
    }
    
    @Published var autoLogin: Bool = false {
        didSet {
            UserDefaults.standard.set(autoLogin, forKey: "autoLogin")
        }
    }
    
    // 兼容性属性 - 为了兼容老版本
    var apiKey: String {
        get {
            return aiApiKeys[aiServiceProvider] ?? ""
        }
        set {
            aiApiKeys[aiServiceProvider] = newValue
        }
    }
    
    var baseURL: String {
        get {
            return aiApiEndpoints[aiServiceProvider] ?? aiServiceProvider.defaultEndpoint
        }
        set {
            aiApiEndpoints[aiServiceProvider] = newValue
        }
    }
    
    /// 获取当前选中的AI服务配置
    func getCurrentAISettings() -> (apiKey: String, baseURL: String, model: String, enableKnowledgeBase: Bool, knowledgeBaseId: String) {
        let provider = aiServiceProvider
        let apiKey = aiApiKeys[provider] ?? ""
        let baseURL = aiApiEndpoints[provider] ?? provider.defaultEndpoint
        let model = aiModel.apiIdentifier
        
        return (
            apiKey: apiKey,
            baseURL: baseURL,
            model: model,
            enableKnowledgeBase: enableKnowledgeBase,
            knowledgeBaseId: knowledgeBaseId
        )
    }
    
    // 初始化方法
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        // 加载主题设置
        if let colorSchemeValue = UserDefaults.standard.string(forKey: "colorScheme"),
           let scheme = ColorSchemePreference(rawValue: colorSchemeValue) {
            colorScheme = scheme
        }
        
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        
        if let languageValue = UserDefaults.standard.string(forKey: "language"),
           let lang = AppLanguage(rawValue: languageValue) {
            language = lang
        }
        
        // 加载阅读设置
        defaultPDFZoom = UserDefaults.standard.double(forKey: "defaultPDFZoom")
        if defaultPDFZoom == 0 { defaultPDFZoom = 1.0 }
        
        if let layoutValue = UserDefaults.standard.string(forKey: "defaultPageLayout"),
           let layout = PDFPageLayout(rawValue: layoutValue) {
            defaultPageLayout = layout
        }
        
        fontSize = UserDefaults.standard.double(forKey: "fontSize")
        if fontSize == 0 { fontSize = 16.0 }
        
        if let highlightValue = UserDefaults.standard.string(forKey: "highlightColor"),
           let highlight = HighlightColor(rawValue: highlightValue) {
            highlightColor = highlight
        }
        
        showPageNumber = UserDefaults.standard.bool(forKey: "showPageNumber")
        keepLastReadPage = UserDefaults.standard.bool(forKey: "keepLastReadPage")
        automaticNightMode = UserDefaults.standard.bool(forKey: "automaticNightMode")
        
        // 加载API设置
        if let providerValue = UserDefaults.standard.string(forKey: "aiServiceProvider"),
           let provider = AIServiceProvider(rawValue: providerValue) {
            aiServiceProvider = provider
        }
        
        // 加载所有服务提供商的API密钥
        var keys: [AIServiceProvider: String] = [:]
        for provider in AIServiceProvider.allCases {
            if let apiKey = loadEncryptedApiKey(for: provider) {
                keys[provider] = apiKey
            }
        }
        aiApiKeys = keys
        
        // 加载所有服务提供商的API端点
        var endpoints: [AIServiceProvider: String] = [:]
        for provider in AIServiceProvider.allCases {
            if let endpoint = UserDefaults.standard.string(forKey: "aiApiEndpoint_\(provider.rawValue)") {
                endpoints[provider] = endpoint
            } else {
                endpoints[provider] = provider.defaultEndpoint
            }
        }
        aiApiEndpoints = endpoints
        
        if let modelValue = UserDefaults.standard.string(forKey: "aiModel"),
           let model = AIModel(rawValue: modelValue) {
            aiModel = model
        }
        
        // 兼容旧的API端点设置
        if let endpoint = UserDefaults.standard.string(forKey: "aiApiEndpoint") {
            aiApiEndpoints[.openAI] = endpoint
        }
        
        useSimulatedData = UserDefaults.standard.bool(forKey: "useSimulatedData")
        
        // 加载文件导入设置
        automaticMetadataExtraction = UserDefaults.standard.bool(forKey: "automaticMetadataExtraction")
        storeFilesCentrally = UserDefaults.standard.bool(forKey: "storeFilesCentrally")
        
        if let savedPath = UserDefaults.standard.string(forKey: "defaultImportLocation") {
            let url = URL(fileURLWithPath: savedPath)
            if FileManager.default.fileExists(atPath: url.path) {
                defaultImportLocation = url
            }
        }
        
        // 加载通知设置
        enableNotifications = UserDefaults.standard.bool(forKey: "enableNotifications")
        
        // 加载备份设置
        autoBackupEnabled = UserDefaults.standard.bool(forKey: "autoBackupEnabled")
        
        if let backupFrequencyValue = UserDefaults.standard.string(forKey: "backupFrequency"),
           let frequency = BackupFrequency(rawValue: backupFrequencyValue) {
            backupFrequency = frequency
        }
        
        // 加载用户界面设置
        defaultTab = UserDefaults.standard.integer(forKey: "defaultTab")
        showBibliographicInfo = UserDefaults.standard.bool(forKey: "showBibliographicInfo")
        
        // 加载知识库设置
        enableKnowledgeBase = UserDefaults.standard.bool(forKey: "enableKnowledgeBase")
        knowledgeBaseId = UserDefaults.standard.string(forKey: "knowledgeBaseId") ?? ""
        
        // 加载登录设置
        isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        username = UserDefaults.standard.string(forKey: "username") ?? ""
        isGuestUser = UserDefaults.standard.bool(forKey: "isGuestUser")
        autoLogin = UserDefaults.standard.bool(forKey: "autoLogin")
    }
    
    // 重置所有设置
    func resetToDefaults() {
        colorScheme = .system
        isDarkMode = false
        language = .chinese
        defaultPDFZoom = 1.0
        defaultPageLayout = .single
        fontSize = 16.0
        highlightColor = .yellow
        showPageNumber = true
        keepLastReadPage = true
        automaticNightMode = true
        
        // 重置AI设置
        aiServiceProvider = .openAI
        aiApiKeys = [:]
        aiModel = .gpt4
        
        // 重置所有提供商的API端点为默认值
        var defaultEndpoints: [AIServiceProvider: String] = [:]
        for provider in AIServiceProvider.allCases {
            defaultEndpoints[provider] = provider.defaultEndpoint
        }
        aiApiEndpoints = defaultEndpoints
        
        useSimulatedData = true
        automaticMetadataExtraction = true
        storeFilesCentrally = true
        defaultImportLocation = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        enableNotifications = true
        autoBackupEnabled = true
        backupFrequency = .weekly
        defaultTab = 0
        showBibliographicInfo = true
        
        // 重置知识库设置
        enableKnowledgeBase = false
        knowledgeBaseId = ""
        
        // 重置登录设置
        isLoggedIn = false
        username = ""
        isGuestUser = false
        autoLogin = false
    }
    
    // API密钥的安全存储
    private func storeEncryptedApiKey(_ key: String, for provider: AIServiceProvider) {
        // 简单加密，实际应用中应使用KeyChain
        let encryptedKey = key.data(using: .utf8)?.base64EncodedString() ?? ""
        UserDefaults.standard.set(encryptedKey, forKey: "encryptedApiKey_\(provider.rawValue)")
    }
    
    private func loadEncryptedApiKey(for provider: AIServiceProvider) -> String? {
        let key = "encryptedApiKey_\(provider.rawValue)"
        
        // 尝试获取特定提供商的密钥
        guard let encryptedKey = UserDefaults.standard.string(forKey: key) else {
            // 如果没有特定提供商的密钥，且是OpenAI提供商，则尝试读取旧的通用密钥
            if provider == .openAI,
               let legacyKey = UserDefaults.standard.string(forKey: "encryptedApiKey"),
               let data = Data(base64Encoded: legacyKey),
               let key = String(data: data, encoding: .utf8) {
                return key
            }
            return nil
        }
        
        guard let data = Data(base64Encoded: encryptedKey),
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key
    }
    
    // 添加API密钥的保存方法
    func saveApiKey(_ key: String, for provider: AIServiceProvider) {
        aiApiKeys[provider] = key
    }
    
    /// 保存所有设置到UserDefaults
    func saveSettings() {
        // 显式保存所有设置
        UserDefaults.standard.set(colorScheme.rawValue, forKey: "colorScheme")
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        UserDefaults.standard.set(language.rawValue, forKey: "language")
        
        UserDefaults.standard.set(defaultPDFZoom, forKey: "defaultPDFZoom")
        UserDefaults.standard.set(defaultPageLayout.rawValue, forKey: "defaultPageLayout")
        UserDefaults.standard.set(fontSize, forKey: "fontSize")
        UserDefaults.standard.set(highlightColor.rawValue, forKey: "highlightColor")
        UserDefaults.standard.set(showPageNumber, forKey: "showPageNumber")
        UserDefaults.standard.set(keepLastReadPage, forKey: "keepLastReadPage")
        UserDefaults.standard.set(automaticNightMode, forKey: "automaticNightMode")
        
        UserDefaults.standard.set(aiServiceProvider.rawValue, forKey: "aiServiceProvider")
        UserDefaults.standard.set(aiModel.rawValue, forKey: "aiModel")
        UserDefaults.standard.set(useSimulatedData, forKey: "useSimulatedData")
        
        // 保存各提供商的API端点
        for (provider, endpoint) in aiApiEndpoints {
            UserDefaults.standard.set(endpoint, forKey: "aiApiEndpoint_\(provider.rawValue)")
        }
        
        // 保存各提供商的API密钥
        for (provider, key) in aiApiKeys {
            storeEncryptedApiKey(key, for: provider)
        }
        
        UserDefaults.standard.set(automaticMetadataExtraction, forKey: "automaticMetadataExtraction")
        UserDefaults.standard.set(storeFilesCentrally, forKey: "storeFilesCentrally")
        UserDefaults.standard.set(defaultImportLocation.path, forKey: "defaultImportLocation")
        
        UserDefaults.standard.set(enableNotifications, forKey: "enableNotifications")
        UserDefaults.standard.set(autoBackupEnabled, forKey: "autoBackupEnabled")
        UserDefaults.standard.set(backupFrequency.rawValue, forKey: "backupFrequency")
        
        UserDefaults.standard.set(defaultTab, forKey: "defaultTab")
        UserDefaults.standard.set(showBibliographicInfo, forKey: "showBibliographicInfo")
        
        // 保存知识库设置
        UserDefaults.standard.set(enableKnowledgeBase, forKey: "enableKnowledgeBase")
        UserDefaults.standard.set(knowledgeBaseId, forKey: "knowledgeBaseId")
    }
    
    // 保存知识库设置
    func saveKnowledgeBaseSettings(enableKnowledgeBase: Bool, knowledgeBaseId: String) {
        self.enableKnowledgeBase = enableKnowledgeBase
        self.knowledgeBaseId = knowledgeBaseId
        
        // 显式保存到UserDefaults
        UserDefaults.standard.set(enableKnowledgeBase, forKey: "enableKnowledgeBase")
        UserDefaults.standard.set(knowledgeBaseId, forKey: "knowledgeBaseId")
    }
    
    // 用户登出方法
    func logout() {
        isLoggedIn = false
        username = ""
        isGuestUser = false
        autoLogin = false
        
        // 清除保存的登录信息
        UserDefaults.standard.removeObject(forKey: "savedUsername")
        if let savedUsername = UserDefaults.standard.string(forKey: "savedUsername") {
            _ = KeychainManager.delete(username: savedUsername)
        }
    }
} 