//
//  PaperAnalysisTool.swift
//  Paper analysis tool
//
//  Created by 金倩如AI on 2023/4/1.
//

import SwiftUI

@main
struct PaperAnalysisTool: App {
    @StateObject private var dataStore = DataStore()
    @StateObject private var userSettings = UserSettings.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if userSettings.isLoggedIn {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(dataStore)
            .environmentObject(userSettings)
            .preferredColorScheme(userSettings.isDarkMode ? .dark : .light)
        }
    }
} 