import Foundation

struct ReadingProgress: Codable, Equatable {
    var currentPage: Int = 0
    var totalPages: Int = 0
    var lastReadTime: Date = Date()
    var completedSections: [Int] = []
    var bookmarks: [Int] = []
    
    // 返回0-1.0之间的阅读进度百分比
    var percentage: Double {
        guard totalPages > 0 else { return 0.0 }
        return Double(currentPage + 1) / Double(totalPages)
    }
    
    // 用于表示显示在界面上的完成百分比
    var displayPercentage: String {
        let percent = Int(percentage * 100)
        return "\(percent)%"
    }
    
    // 剩余页数
    var remainingPages: Int {
        guard totalPages > 0 else { return 0 }
        return totalPages - (currentPage + 1)
    }
    
    // 是否已完成阅读
    var isCompleted: Bool {
        currentPage >= totalPages - 1
    }
    
    // 添加书签
    mutating func addBookmark(_ page: Int) {
        if !bookmarks.contains(page) {
            bookmarks.append(page)
            bookmarks.sort()
        }
    }
    
    // 移除书签
    mutating func removeBookmark(_ page: Int) {
        bookmarks.removeAll { $0 == page }
    }
    
    // 标记章节为已完成
    mutating func markSectionAsCompleted(_ sectionIndex: Int) {
        if !completedSections.contains(sectionIndex) {
            completedSections.append(sectionIndex)
            completedSections.sort()
        }
    }
    
    // 获取上次阅读时间的友好表示
    var lastReadTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastReadTime)
    }
    
    // 距离上次阅读的时间
    var timeSinceLastRead: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: lastReadTime, to: Date())
        
        if let days = components.day, days > 0 {
            return "\(days)天前"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)小时前"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)分钟前"
        } else {
            return "刚刚"
        }
    }
    
    // 实现Equatable协议
    static func == (lhs: ReadingProgress, rhs: ReadingProgress) -> Bool {
        lhs.currentPage == rhs.currentPage &&
        lhs.totalPages == rhs.totalPages &&
        lhs.lastReadTime == rhs.lastReadTime &&
        lhs.completedSections == rhs.completedSections &&
        lhs.bookmarks == rhs.bookmarks
    }
} 