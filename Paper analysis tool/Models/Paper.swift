//
//  Paper.swift
//  Paper analysis tool
//
//  Created by 金倩如AI on 2023/4/1.
//

import Foundation
import SwiftUI

struct Paper: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var authors: [String]
    var publicationDate: Date?
    var journal: String?
    var abstract: String
    var keywords: [String]
    var doi: String?
    var fileURL: URL?
    var dateAdded: Date
    var lastOpened: Date?
    var tags: [Tag]
    var categories: [Category]
    var isFavorite: Bool
    var readingProgress: ReadingProgress?
    var notes: [Note]?
    var highlights: [TextHighlight]?
    var readStatus: ReadStatus = .unread
    var userRating: Int? // 1-5星评分
    var sections: [PaperSection]? // 论文章节
    
    // 阅读状态枚举
    enum ReadStatus: String, Codable, CaseIterable {
        case unread = "未读"
        case reading = "阅读中"
        case completed = "已读完"
        case toReview = "待复习"
        
        var systemImage: String {
            switch self {
            case .unread: return "book.closed"
            case .reading: return "book"
            case .completed: return "checkmark.circle"
            case .toReview: return "arrow.clockwise.circle"
            }
        }
    }
    
    // 用于编码和解码URL
    enum CodingKeys: String, CodingKey {
        case id, title, authors, publicationDate, journal, abstract, keywords, doi
        case fileURLString, dateAdded, lastOpened, tags, categories, isFavorite, readingProgress, notes
        case readStatus, userRating, highlights, sections
    }
    
    init(id: UUID = UUID(),
         title: String,
         authors: [String],
         publicationDate: Date? = nil,
         journal: String? = nil,
         abstract: String = "",
         keywords: [String] = [],
         doi: String? = nil,
         fileURL: URL? = nil,
         dateAdded: Date = Date(),
         lastOpened: Date? = nil,
         tags: [Tag] = [],
         categories: [Category] = [],
         isFavorite: Bool = false,
         readingProgress: ReadingProgress? = nil,
         notes: [Note]? = nil,
         highlights: [TextHighlight]? = nil,
         readStatus: ReadStatus = .unread,
         userRating: Int? = nil,
         sections: [PaperSection]? = nil) {
        self.id = id
        self.title = title
        self.authors = authors
        self.publicationDate = publicationDate
        self.journal = journal
        self.abstract = abstract
        self.keywords = keywords
        self.doi = doi
        self.fileURL = fileURL
        self.dateAdded = dateAdded
        self.lastOpened = lastOpened
        self.tags = tags
        self.categories = categories
        self.isFavorite = isFavorite
        self.readingProgress = readingProgress
        self.notes = notes
        self.highlights = highlights
        self.readStatus = readStatus
        self.userRating = userRating
        self.sections = sections
    }
    
    // 自定义编码方法
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(authors, forKey: .authors)
        try container.encodeIfPresent(publicationDate, forKey: .publicationDate)
        try container.encodeIfPresent(journal, forKey: .journal)
        try container.encode(abstract, forKey: .abstract)
        try container.encode(keywords, forKey: .keywords)
        try container.encodeIfPresent(doi, forKey: .doi)
        if let fileURL = fileURL {
            try container.encode(fileURL.path, forKey: .fileURLString)
        }
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encodeIfPresent(lastOpened, forKey: .lastOpened)
        try container.encode(tags, forKey: .tags)
        try container.encode(categories, forKey: .categories)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(readingProgress, forKey: .readingProgress)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(highlights, forKey: .highlights)
        try container.encode(readStatus, forKey: .readStatus)
        try container.encodeIfPresent(userRating, forKey: .userRating)
        try container.encodeIfPresent(sections, forKey: .sections)
    }
    
    // 自定义解码方法
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        authors = try container.decode([String].self, forKey: .authors)
        publicationDate = try container.decodeIfPresent(Date.self, forKey: .publicationDate)
        journal = try container.decodeIfPresent(String.self, forKey: .journal)
        abstract = try container.decode(String.self, forKey: .abstract)
        keywords = try container.decode([String].self, forKey: .keywords)
        doi = try container.decodeIfPresent(String.self, forKey: .doi)
        
        if let fileURLString = try container.decodeIfPresent(String.self, forKey: .fileURLString) {
            fileURL = URL(fileURLWithPath: fileURLString)
        } else {
            fileURL = nil
        }
        
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        lastOpened = try container.decodeIfPresent(Date.self, forKey: .lastOpened)
        tags = try container.decode([Tag].self, forKey: .tags)
        categories = try container.decode([Category].self, forKey: .categories)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        readingProgress = try container.decodeIfPresent(ReadingProgress.self, forKey: .readingProgress)
        notes = try container.decodeIfPresent([Note].self, forKey: .notes)
        highlights = try container.decodeIfPresent([TextHighlight].self, forKey: .highlights)
        readStatus = try container.decodeIfPresent(ReadStatus.self, forKey: .readStatus) ?? .unread
        userRating = try container.decodeIfPresent(Int.self, forKey: .userRating)
        sections = try container.decodeIfPresent([PaperSection].self, forKey: .sections)
    }
    
    // Equatable协议实现
    static func == (lhs: Paper, rhs: Paper) -> Bool {
        lhs.id == rhs.id
    }
    
    static var example: Paper {
        Paper(
            title: "深度学习在自然语言处理中的应用",
            authors: ["张三", "李四", "王五"],
            publicationDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()),
            journal: "计算机科学与技术",
            abstract: "本文探讨了深度学习技术如何改变自然语言处理领域，特别是Transformer架构和BERT模型的影响。我们分析了这些技术在文本分类、命名实体识别和机器翻译等任务中的应用，并讨论了未来的研究方向。",
            keywords: ["深度学习", "自然语言处理", "BERT", "Transformer", "注意力机制"],
            doi: nil,
            fileURL: URL(fileURLWithPath: "/Users/example/Documents/papers/nlp_paper.pdf"),
            dateAdded: Date(),
            lastOpened: Date(),
            tags: [
                Tag(name: "AI", color: .blue),
                Tag(name: "NLP", color: .green),
                Tag(name: "重要", color: .red)
            ],
            categories: [],
            isFavorite: true,
            readingProgress: ReadingProgress(currentPage: 5, totalPages: 10),
            notes: [],
            highlights: nil,
            readStatus: .reading,
            userRating: 4
        )
    }
    
    // 添加获取一个空的Paper对象的静态属性
    static var empty: Paper {
        Paper(
            title: "",
            authors: [""],
            publicationDate: nil,
            journal: nil,
            abstract: "",
            keywords: [],
            doi: nil,
            fileURL: nil,
            dateAdded: Date(),
            lastOpened: nil,
            tags: [],
            categories: [],
            isFavorite: false,
            readingProgress: nil,
            notes: nil,
            highlights: nil,
            readStatus: .unread,
            userRating: nil
        )
    }
}

// 扩展获取格式化的属性
extension Paper {
    // 格式化的作者列表
    var formattedAuthors: String {
        authors.joined(separator: ", ")
    }
    
    // 格式化的日期
    var formattedDate: String {
        guard let date = publicationDate else {
            return "未知日期"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // 简短的摘要
    var shortAbstract: String {
        if abstract.count <= 200 {
            return abstract
        }
        return abstract.prefix(200) + "..."
    }
    
    // 格式化的关键词
    var formattedKeywords: String {
        keywords.joined(separator: ", ")
    }
    
    // 阅读进度的百分比表示
    var readingProgressPercent: Int {
        Int(readingProgress?.percentage ?? 0.0)
    }
    
    // 上次打开的相对时间
    var timeAgoLastOpened: String {
        timeAgo(from: lastOpened)
    }
    
    // 添加日期的相对时间
    var timeAgoAdded: String {
        timeAgo(from: dateAdded)
    }
    
    // 计算相对时间的辅助方法
    private func timeAgo(from date: Date?) -> String {
        guard let date = date else {
            return "未知时间"
        }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let year = components.year, year > 0 {
            return year == 1 ? "1年前" : "\(year)年前"
        }
        
        if let month = components.month, month > 0 {
            return month == 1 ? "1个月前" : "\(month)个月前"
        }
        
        if let day = components.day, day > 0 {
            return day == 1 ? "昨天" : "\(day)天前"
        }
        
        if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1小时前" : "\(hour)小时前"
        }
        
        if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1分钟前" : "\(minute)分钟前"
        }
        
        return "刚刚"
    }
} 