import Foundation
import SwiftUI

struct Tag: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var color: TagColor
    var count: Int = 0
    
    init(id: UUID = UUID(), name: String, color: TagColor = .blue, count: Int = 0) {
        self.id = id
        self.name = name
        self.color = color
        self.count = count
    }
    
    // Equatable协议实现
    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.id == rhs.id
    }
    
    // Hashable协议实现
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// 定义标签颜色枚举
enum TagColor: String, Codable, CaseIterable, Identifiable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case pink
    case gray
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .gray: return .gray
        }
    }
    
    var name: String {
        switch self {
        case .red: return "红色"
        case .orange: return "橙色"
        case .yellow: return "黄色"
        case .green: return "绿色"
        case .blue: return "蓝色"
        case .purple: return "紫色"
        case .pink: return "粉色"
        case .gray: return "灰色"
        }
    }
    
    static var random: TagColor {
        let allColors = TagColor.allCases
        return allColors.randomElement() ?? .blue
    }
}

// 扩展Tag
extension Tag {
    // 获取带有透明度的标签颜色
    var backgroundColor: Color {
        color.color.opacity(0.2)
    }
    
    // 随机生成一个标签
    static func random(name: String) -> Tag {
        Tag(name: name, color: .random)
    }
    
    // 预定义的标签
    static var predefinedTags: [Tag] {
        [
            Tag(name: "重要", color: .red),
            Tag(name: "待复习", color: .yellow),
            Tag(name: "已读", color: .green),
            Tag(name: "未读", color: .gray),
            Tag(name: "经典", color: .purple),
            Tag(name: "综述", color: .blue),
            Tag(name: "研究方向", color: .orange),
            Tag(name: "参考文献", color: .pink)
        ]
    }
} 