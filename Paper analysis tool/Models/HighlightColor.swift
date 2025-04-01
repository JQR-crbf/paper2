import Foundation
import SwiftUI

enum HighlightColor: String, Codable, CaseIterable, Identifiable {
    case yellow
    case green
    case blue
    case pink
    case purple
    case orange
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .pink: return .pink
        case .purple: return .purple
        case .orange: return .orange
        }
    }
    
    var name: String {
        switch self {
        case .yellow: return "黄色"
        case .green: return "绿色"
        case .blue: return "蓝色"
        case .pink: return "粉色"
        case .purple: return "紫色"
        case .orange: return "橙色"
        }
    }
} 