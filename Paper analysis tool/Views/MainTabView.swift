//
//  MainTabView.swift
//  Paper analysis tool
//
//  Created by 金倩如AI on 2025/4/1.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var dataStore: DataStore
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                LibraryView()
                    .navigationTitle("论文库")
            }
            .tabItem {
                Label("论文库", systemImage: "book")
            }
            .tag(0)
            
            NavigationView {
                FavoritesView()
                    .navigationTitle("收藏")
            }
            .tabItem {
                Label("收藏", systemImage: "star")
            }
            .tag(1)
            
            NavigationView {
                SettingsView()
                    .navigationTitle("设置")
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
            .tag(2)
        }
        .onAppear {
            // 设置默认选中的标签页
            selectedTab = userSettings.defaultTab
        }
        .onChange(of: selectedTab) { _, newValue in
            // 保存用户选择的标签页
            userSettings.defaultTab = newValue
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(UserSettings.shared)
            .environmentObject(DataStore())
    }
} 