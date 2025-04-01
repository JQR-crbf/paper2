//
//  Note.swift
//  Paper analysis tool
//
//  Created by 金倩如AI on 2023/4/1.
//

import Foundation
import SwiftUI

struct Note: Identifiable, Codable {
    var id: UUID
    var content: String
    var timestamp: Date
    var pageNumber: Int
    var tags: [Tag]
    var highlightColor: HighlightColor?
    var relatedText: String?
    var paperId: UUID
    
    init(id: UUID = UUID(), 
         content: String, 
         timestamp: Date = Date(), 
         pageNumber: Int, 
         tags: [Tag] = [], 
         highlightColor: HighlightColor? = nil,
         relatedText: String? = nil,
         paperId: UUID) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.pageNumber = pageNumber
        self.tags = tags
        self.highlightColor = highlightColor
        self.relatedText = relatedText
        self.paperId = paperId
    }
}

// 笔记类型扩展，添加一些辅助方法
extension Note {
    // 添加标签
    mutating func addTag(_ tag: Tag) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }
    
    // 移除标签
    mutating func removeTag(_ tag: Tag) {
        tags.removeAll { $0.id == tag.id }
    }
    
    // 更新高亮颜色
    mutating func updateHighlight(_ color: HighlightColor?) {
        self.highlightColor = color
    }
    
    // 格式化时间戳
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}