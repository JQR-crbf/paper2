import Foundation
import SwiftUI

struct Category: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var color: Color
    var iconName: String?
    var description: String?
    var parentId: UUID?
    
    // 用于编码和解码Color
    enum CodingKeys: String, CodingKey {
        case id, name, iconName, description, parentId
        case colorRed, colorGreen, colorBlue, colorOpacity
    }
    
    init(id: UUID = UUID(),
         name: String,
         color: Color = .blue,
         iconName: String? = nil,
         description: String? = nil,
         parentId: UUID? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.iconName = iconName
        self.description = description
        self.parentId = parentId
    }
    
    // 自定义编码方法
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(iconName, forKey: .iconName)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        
        // 解析颜色组件
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0
        
        #if canImport(UIKit)
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        #elseif canImport(AppKit)
        if let cgColor = NSColor(color).cgColor {
            let components = cgColor.components ?? [0, 0, 0, 0]
            red = components[0]
            green = components[1]
            blue = components[2]
            opacity = components[3]
        }
        #endif
        
        // 编码颜色组件
        try container.encode(red, forKey: .colorRed)
        try container.encode(green, forKey: .colorGreen)
        try container.encode(blue, forKey: .colorBlue)
        try container.encode(opacity, forKey: .colorOpacity)
    }
    
    // 自定义解码方法
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        
        // 解码颜色组件
        let red = try container.decode(CGFloat.self, forKey: .colorRed)
        let green = try container.decode(CGFloat.self, forKey: .colorGreen)
        let blue = try container.decode(CGFloat.self, forKey: .colorBlue)
        let opacity = try container.decode(CGFloat.self, forKey: .colorOpacity)
        
        // 创建Color
        #if canImport(UIKit)
        color = Color(UIColor(red: red, green: green, blue: blue, alpha: opacity))
        #elseif canImport(AppKit)
        color = Color(NSColor(red: red, green: green, blue: blue, alpha: opacity))
        #else
        color = Color.blue
        #endif
    }
    
    // 为Equatable协议实现等价性检查
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }
    
    // 为Hashable协议实现hash函数
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // 生成随机颜色的类别
    static func randomCategory(name: String) -> Category {
        let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .yellow]
        let icons = ["folder", "tag", "book", "note", "doc", "tray", "bookmark"]
        
        return Category(
            name: name,
            color: colors.randomElement() ?? .blue,
            iconName: icons.randomElement()
        )
    }
    
    // 预定义的类别集合
    static var predefinedCategories: [Category] {
        [
            Category(id: UUID(), name: "机器学习", color: .blue, iconName: "cpu"),
            Category(id: UUID(), name: "自然语言处理", color: .green, iconName: "text.bubble"),
            Category(id: UUID(), name: "计算机视觉", color: .purple, iconName: "eye"),
            Category(id: UUID(), name: "强化学习", color: .orange, iconName: "gamecontroller"),
            Category(id: UUID(), name: "图神经网络", color: .red, iconName: "network"),
            Category(id: UUID(), name: "生物信息学", color: .teal, iconName: "allergens"),
            Category(id: UUID(), name: "医学影像", color: .indigo, iconName: "heart.text.square"),
            Category(id: UUID(), name: "未分类", color: .gray, iconName: "folder")
        ]
    }
}

// 为SwiftUI和Combine使用的扩展
extension Category {
    // 返回适当的图标（如果没有指定则使用默认值）
    var icon: String {
        iconName ?? "folder"
    }
    
    // 返回带有透明度的颜色，适用于背景
    var backgroundColor: Color {
        color.opacity(0.2)
    }
    
    // 确定文本颜色（基于背景颜色）
    var textColor: Color {
        // 简化的亮度检测，实际应用中应该使用更复杂的算法
        isColorBright ? .black : .white
    }
    
    // 简单检测颜色是否明亮
    private var isColorBright: Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        
        #if canImport(UIKit)
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: nil)
        #elseif canImport(AppKit)
        if let cgColor = NSColor(color).cgColor {
            let components = cgColor.components ?? [0, 0, 0, 0]
            red = components[0]
            green = components[1]
            blue = components[2]
        }
        #endif
        
        // 使用感知亮度公式
        let brightness = (red * 299 + green * 587 + blue * 114) / 1000
        return brightness > 0.6
    }
} 