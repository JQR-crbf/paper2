//
//  PaperSection.swift
//  Paper analysis tool
//
//  Created by 金倩如AI on 2023/4/1.
//

import Foundation

struct PaperSection: Identifiable, Codable {
    var id: UUID
    var title: String
    var level: Int
    var pageNumber: Int
    var content: String
    var subsections: [PaperSection]
    var keywords: [String]
    var summary: String?
    
    init(id: UUID = UUID(),
         title: String,
         level: Int = 1,
         pageNumber: Int,
         content: String,
         subsections: [PaperSection] = [],
         keywords: [String] = [],
         summary: String? = nil) {
        self.id = id
        self.title = title
        self.level = level
        self.pageNumber = pageNumber
        self.content = content
        self.subsections = subsections
        self.keywords = keywords
        self.summary = summary
    }
}

// PaperSection 扩展，添加辅助方法
extension PaperSection {
    // 添加子章节
    mutating func addSubsection(_ section: PaperSection) {
        subsections.append(section)
    }
    
    // 移除子章节
    mutating func removeSubsection(at index: Int) {
        subsections.remove(at: index)
    }
    
    // 添加关键词
    mutating func addKeyword(_ keyword: String) {
        if !keywords.contains(keyword) {
            keywords.append(keyword)
        }
    }
    
    // 更新摘要
    mutating func updateSummary(_ newSummary: String) {
        self.summary = newSummary
    }
    
    // 获取章节的层级标题
    var leveledTitle: String {
        let indent = String(repeating: "    ", count: level - 1)
        return "\(indent)\(title)"
    }
    
    // 获取所有子章节（包括子章节的子章节）
    var allSubsections: [PaperSection] {
        var result = [PaperSection]()
        for section in subsections {
            result.append(section)
            result.append(contentsOf: section.allSubsections)
        }
        return result
    }
    
    // 计算章节的字数
    var wordCount: Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    // 获取章节的预览文本
    var preview: String {
        let maxLength = 200
        if content.count <= maxLength {
            return content
        }
        let index = content.index(content.startIndex, offsetBy: maxLength)
        return content[..<index] + "..."
    }
} 