//
//  FavoritesView.swift
//  Paper analysis tool
//
//  Created by 金倩如AI on 2025/4/1.
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var searchText = ""
    
    var favoritePapers: [Paper] {
        let favorites = dataStore.papers.filter { $0.isFavorite }
        if searchText.isEmpty {
            return favorites
        } else {
            return favorites.filter { paper in
                paper.title.localizedCaseInsensitiveContains(searchText) ||
                paper.authors.joined(separator: ", ").localizedCaseInsensitiveContains(searchText) ||
                paper.abstract.localizedCaseInsensitiveContains(searchText) ||
                paper.keywords.joined(separator: ", ").localizedCaseInsensitiveContains(searchText) ||
                paper.tags.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) })
            }
        }
    }
    
    var body: some View {
        VStack {
            // 搜索栏
            SearchBar(text: $searchText, placeholder: "搜索收藏的论文...")
                .padding(.horizontal)
            
            if favoritePapers.isEmpty {
                // 空状态视图
                VStack(spacing: 20) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("没有收藏的论文")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    Text("您可以通过点击论文卡片中的星标图标来收藏论文")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 收藏列表
                List {
                    ForEach(favoritePapers) { paper in
                        PaperCardView(paper: paper)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // 导航到论文详情页面
                            }
                            .contextMenu {
                                Button(action: {
                                    // 取消收藏
                                    var updatedPaper = paper
                                    updatedPaper.isFavorite = false
                                    dataStore.updatePaper(updatedPaper)
                                }) {
                                    Label("取消收藏", systemImage: "star.slash")
                                }
                                
                                Button(action: {
                                    // 编辑论文
                                }) {
                                    Label("编辑", systemImage: "pencil")
                                }
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesView()
            .environmentObject(DataStore())
    }
} 