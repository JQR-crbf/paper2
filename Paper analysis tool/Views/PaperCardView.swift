//
//  PaperCardView.swift
//  Paper analysis tool
//
//  Created by 金倩如AI on 2023/4/1.
//

import SwiftUI

struct PaperCardView: View {
    let paper: Paper
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题和收藏状态
            HStack {
                Text(paper.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
                
                if paper.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            
            // 作者和日期
            HStack {
                Text(paper.formattedAuthors)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                if let date = paper.publicationDate {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 期刊/会议
            if let journal = paper.journal, !journal.isEmpty {
                Text(journal)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // 摘要
            if !paper.abstract.isEmpty {
                Text(paper.shortAbstract)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.top, 2)
            }
            
            // 标签
            if !paper.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(paper.tags) { tag in
                            Text(tag.name)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(tag.color.color.opacity(0.2))
                                .cornerRadius(5)
                        }
                    }
                }
            }
            
            // 阅读进度和状态
            HStack {
                // 阅读状态
                Label(paper.readStatus.rawValue, systemImage: paper.readStatus.systemImage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 阅读进度
                if let progress = paper.readingProgress, progress.percentage > 0 {
                    ProgressView(value: progress.percentage)
                        .frame(width: 100)
                    Text("\(paper.readingProgressPercent)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct PaperCardView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            PaperCardView(paper: Paper.example)
            PaperCardView(paper: Paper(
                title: "一种基于深度强化学习的自动驾驶决策系统",
                authors: ["李明", "张华"],
                publicationDate: Date().addingTimeInterval(-60*60*24*30*2),
                journal: "中国人工智能学会学报",
                abstract: "本研究提出了一种新的自动驾驶决策系统，结合了深度强化学习与传统规划方法的优势。我们在虚拟环境和真实道路测试中验证了该系统的有效性和安全性。",
                keywords: ["自动驾驶", "深度强化学习", "决策系统"],
                doi: "10.1234/ai.2023.01.002",
                fileURL: URL(fileURLWithPath: "/Users/example/Documents/papers/driving_paper.pdf"),
                tags: [Tag(name: "自动驾驶", color: .green)],
                readingProgress: ReadingProgress(currentPage: 3, totalPages: 10),
                readStatus: .reading
            ))
        }
        .listStyle(PlainListStyle())
        .previewLayout(.sizeThatFits)
    }
} 