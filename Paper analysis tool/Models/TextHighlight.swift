import Foundation
import SwiftUI

struct TextHighlight: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    var color: HighlightColor
    var pageNumber: Int
    var note: String?
    var date: Date
    var position: HighlightPosition?
    
    init(
        id: UUID = UUID(),
        text: String,
        color: HighlightColor = .yellow,
        pageNumber: Int,
        note: String? = nil,
        date: Date = Date(),
        position: HighlightPosition? = nil
    ) {
        self.id = id
        self.text = text
        self.color = color
        self.pageNumber = pageNumber
        self.note = note
        self.date = date
        self.position = position
    }
    
    static func == (lhs: TextHighlight, rhs: TextHighlight) -> Bool {
        lhs.id == rhs.id
    }
}

// 记录高亮在页面中的位置
struct HighlightPosition: Codable, Equatable {
    var pageIndex: Int
    var startIndex: Int
    var length: Int
    
    var range: NSRange {
        NSRange(location: startIndex, length: length)
    }
}

// 扩展TextHighlight提供格式化的输出
extension TextHighlight {
    // 格式化的日期显示
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // 裁剪后的文本（如果太长）
    var truncatedText: String {
        if text.count <= 50 {
            return text
        }
        return String(text.prefix(50)) + "..."
    }
    
    // 高亮位置的描述
    var locationDescription: String {
        "第\(pageNumber)页"
    }
} 