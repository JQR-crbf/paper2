import Foundation
import Combine

class StorageManager {
    // 单例实例
    static let shared = StorageManager()
    
    // 数据存储目录
    private let storageDirectory: URL
    
    // 文件管理器
    private let fileManager = FileManager.default
    
    // 发布的错误信息
    let error = PassthroughSubject<Error, Never>()
    
    private init() {
        // 设置存储目录
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        storageDirectory = documentsDirectory.appendingPathComponent("AppData", isDirectory: true)
        
        // 创建存储目录
        createStorageDirectoryIfNeeded()
    }
    
    // MARK: - 公共方法
    
    // 保存可编码对象到文件
    func save<T: Encodable>(_ object: T, to filename: String) throws {
        let url = storageURL(for: filename)
        let data = try JSONEncoder().encode(object)
        try data.write(to: url)
    }
    
    // 从文件加载可解码对象
    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T? {
        let url = storageURL(for: filename)
        
        // 检查文件是否存在
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
    
    // 删除文件
    func delete(filename: String) throws {
        let url = storageURL(for: filename)
        
        // 检查文件是否存在
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        
        try fileManager.removeItem(at: url)
    }
    
    // 检查文件是否存在
    func fileExists(filename: String) -> Bool {
        let url = storageURL(for: filename)
        return fileManager.fileExists(atPath: url.path)
    }
    
    // 列出所有保存的文件
    func listFiles() -> [String] {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
            return fileURLs.map { $0.lastPathComponent }
        } catch {
            self.error.send(error)
            return []
        }
    }
    
    // 获取文件的URL
    func storageURL(for filename: String) -> URL {
        return storageDirectory.appendingPathComponent(filename)
    }
    
    // 获取文件大小
    func fileSize(filename: String) -> Int64? {
        let url = storageURL(for: filename)
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            self.error.send(error)
            return nil
        }
    }
    
    // 创建备份
    func createBackup() throws -> URL {
        let backupDirectory = storageDirectory.appendingPathComponent("Backups", isDirectory: true)
        
        // 创建备份目录
        if !fileManager.fileExists(atPath: backupDirectory.path) {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        }
        
        // 生成备份文件名
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let backupFilename = "backup_\(timestamp).zip"
        let backupURL = backupDirectory.appendingPathComponent(backupFilename)
        
        // 创建备份文件
        let filesToBackup = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
            .filter { $0.path != backupDirectory.path }
        
        // 创建ZIP文件
        let coordinator = NSFileCoordinator()
        let error: NSError? = nil
        
        for url in filesToBackup {
            var coordinateError: NSError?
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinateError) { (coordinatedURL) in
                // 实际应用中，应该将文件添加到ZIP存档中
            }
            
            if let e = coordinateError {
                self.error.send(e)
                break
            }
        }
        
        // 创建示例备份文件
        let dummyData = Data("这是备份文件内容".utf8)
        do {
            try dummyData.write(to: backupURL)
        } catch {
            self.error.send(error)
        }

        if let error = error {
            throw error
        }
        
        return backupURL
    }
    
    // 从备份恢复
    func restoreFromBackup(at url: URL) throws {
        // 实际应用中，这里应该实现从ZIP文件恢复的逻辑
        // 首先清除当前存储目录
        // 然后解压ZIP文件到存储目录
        
        // 这里只是示例代码
        let backupFiles = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
        
        for file in backupFiles where file.path != url.path {
            try fileManager.removeItem(at: file)
        }
        
        // 假设解压文件并恢复
        let dummyData = try Data(contentsOf: url)
        let dummyFilename = "restored_data.json"
        let dummyURL = storageDirectory.appendingPathComponent(dummyFilename)
        try dummyData.write(to: dummyURL)
    }
    
    // MARK: - 清理方法
    
    // 清空所有存储的数据
    func clearAllData() throws {
        let contents = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
        
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
    
    // 清除过期的缓存文件
    func clearExpiredCache(olderThan days: Int) throws {
        let cacheDirectory = storageDirectory.appendingPathComponent("Cache", isDirectory: true)
        
        // 如果缓存目录不存在，则无需操作
        guard fileManager.fileExists(atPath: cacheDirectory.path) else {
            return
        }
        
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        for url in contents {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let creationDate = attributes[.creationDate] as? Date, creationDate < cutoffDate {
                try fileManager.removeItem(at: url)
            }
        }
    }
    
    // MARK: - 私有辅助方法
    
    // 创建存储目录
    private func createStorageDirectoryIfNeeded() {
        do {
            if !fileManager.fileExists(atPath: storageDirectory.path) {
                try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            }
        } catch {
            self.error.send(error)
        }
    }
}

// MARK: - 错误类型
enum StorageError: Error {
    case fileNotFound(String)
    case writeError(String)
    case readError(String)
    case directoryCreationFailed(String)
    case backupFailed(String)
    case restoreFailed(String)
    
    var localizedDescription: String {
        switch self {
        case .fileNotFound(let filename):
            return "找不到文件: \(filename)"
        case .writeError(let filename):
            return "写入文件失败: \(filename)"
        case .readError(let filename):
            return "读取文件失败: \(filename)"
        case .directoryCreationFailed(let path):
            return "创建目录失败: \(path)"
        case .backupFailed(let reason):
            return "创建备份失败: \(reason)"
        case .restoreFailed(let reason):
            return "恢复备份失败: \(reason)"
        }
    }
} 