import Foundation
import Combine
import PDFKit
import SwiftUI

class PaperLibraryService: ObservableObject {
    // 已导入的所有论文
    @Published private(set) var papers: [Paper] = []
    @Published private(set) var categories: [Category] = []
    @Published private(set) var isImporting: Bool = false
    @Published var searchQuery: String = ""
    
    // 错误处理
    @Published var error: Error?
    
    // 持久化和导入路径
    private let storageManager: StorageManager
    private let importDirectory: URL
    private var cancellables = Set<AnyCancellable>()
    
    // 依赖的服务
    private let pdfService: PDFService
    private let aiService: AIAnalysisService
    
    init(storageManager: StorageManager, pdfService: PDFService, aiService: AIAnalysisService) {
        self.storageManager = storageManager
        self.pdfService = pdfService
        self.aiService = aiService
        
        // 设置导入目录
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.importDirectory = documentsDirectory.appendingPathComponent("ImportedPapers", isDirectory: true)
        
        // 创建导入目录（如果不存在）
        createImportDirectoryIfNeeded()
        
        // 加载保存的数据
        loadSavedData()
        
        // 监听搜索查询变化
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 数据访问方法
    
    // 筛选后的论文（基于搜索查询）
    var filteredPapers: [Paper] {
        if searchQuery.isEmpty {
            return papers
        }
        
        return papers.filter { paper in
            paper.title.localizedCaseInsensitiveContains(searchQuery) ||
            paper.authors.joined(separator: ", ").localizedCaseInsensitiveContains(searchQuery) ||
            paper.abstract.localizedCaseInsensitiveContains(searchQuery) ||
            paper.keywords.joined(separator: ", ").localizedCaseInsensitiveContains(searchQuery) ||
            paper.tags.map(\.name).joined(separator: ", ").localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    // 获取特定类别的论文
    func papers(in category: Category) -> [Paper] {
        papers.filter { $0.categories.contains(where: { $0.id == category.id }) }
    }
    
    // 获取有特定标签的论文
    func papers(withTag tag: Tag) -> [Paper] {
        papers.filter { $0.tags.contains(where: { $0.id == tag.id }) }
    }
    
    // MARK: - 论文导入和管理
    
    // 导入新论文
    func importPaper(from url: URL) -> AnyPublisher<Paper, Error> {
        isImporting = true
        
        // 1. 复制文件到应用的文档目录
        return copyPaperFile(from: url)
            .flatMap { [weak self] destinationURL -> AnyPublisher<Paper, Error> in
                guard let self = self else {
                    return Fail(error: LibraryError.serviceUnavailable).eraseToAnyPublisher()
                }
                
                // 2. 从PDF中提取元数据
                return self.extractMetadata(from: destinationURL)
                    .map { metadata -> Paper in
                        let paper = Paper(
                            id: UUID(),
                            title: metadata.title ?? "未命名论文",
                            authors: metadata.authors,
                            publicationDate: metadata.date,
                            journal: metadata.journal,
                            abstract: metadata.abstract ?? "",
                            keywords: metadata.keywords,
                            doi: metadata.doi,
                            fileURL: destinationURL,
                            dateAdded: Date(),
                            lastOpened: Date(),
                            tags: [],
                            categories: [],
                            isFavorite: false,
                            readingProgress: nil,
                            notes: []
                        )
                        return paper
                    }
                    .flatMap { [weak self] paper -> AnyPublisher<Paper, Error> in
                        guard let self = self else {
                            return Fail(error: LibraryError.serviceUnavailable).eraseToAnyPublisher()
                        }
                        
                        // 3. 如果设置了自动分析，则执行AI分析
                        if UserSettings.shared.automaticMetadataExtraction {
                            return self.analyzePaper(paper)
                                .handleEvents(receiveOutput: { analyzedPaper in
                                    // 4. 将论文添加到库中并保存
                                    self.addPaperToLibrary(analyzedPaper)
                                    self.isImporting = false
                                })
                                .eraseToAnyPublisher()
                        } else {
                            // 4. 直接添加论文到库中并返回
                            self.addPaperToLibrary(paper)
                            self.isImporting = false
                            return Just(paper)
                                .setFailureType(to: Error.self)
                                .eraseToAnyPublisher()
                        }
                    }
                    .eraseToAnyPublisher()
            }
            .handleEvents(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.error = error
                }
                self?.isImporting = false
            })
            .eraseToAnyPublisher()
    }
    
    // 将已创建的论文对象添加到库中
    private func addPaperToLibrary(_ paper: Paper) {
        papers.append(paper)
        savePapers()
    }
    
    // 更新现有论文
    func updatePaper(_ paper: Paper) {
        if let index = papers.firstIndex(where: { $0.id == paper.id }) {
            papers[index] = paper
            savePapers()
        }
    }
    
    // 删除论文
    func deletePaper(_ paper: Paper) {
        // 从库中删除
        papers.removeAll { $0.id == paper.id }
        
        // 尝试删除文件
        do {
            if let fileURL = paper.fileURL {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("删除文件失败: \(error.localizedDescription)")
        }
        
        savePapers()
    }
    
    // MARK: - 类别管理
    
    // 添加新类别
    func addCategory(_ category: Category) {
        categories.append(category)
        saveCategories()
    }
    
    // 更新类别
    func updateCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories()
        }
    }
    
    // 删除类别
    func deleteCategory(_ category: Category) {
        // 从所有论文中移除该类别
        for i in 0..<papers.count {
            papers[i].categories.removeAll { $0.id == category.id }
        }
        
        // 从类别列表中删除
        categories.removeAll { $0.id == category.id }
        
        saveCategories()
        savePapers()
    }
    
    // 将论文添加到类别
    func addPaper(_ paper: Paper, toCategory category: Category) {
        guard let paperIndex = papers.firstIndex(where: { $0.id == paper.id }) else { return }
        
        // 检查论文是否已在该类别中
        if !papers[paperIndex].categories.contains(where: { $0.id == category.id }) {
            papers[paperIndex].categories.append(category)
            savePapers()
        }
    }
    
    // 从类别中移除论文
    func removePaper(_ paper: Paper, fromCategory category: Category) {
        guard let paperIndex = papers.firstIndex(where: { $0.id == paper.id }) else { return }
        
        papers[paperIndex].categories.removeAll { $0.id == category.id }
        savePapers()
    }
    
    // MARK: - 标签管理
    
    // 添加标签到论文
    func addTag(_ tag: Tag, toPaper paper: Paper) {
        guard let paperIndex = papers.firstIndex(where: { $0.id == paper.id }) else { return }
        
        // 检查论文是否已有该标签
        if !papers[paperIndex].tags.contains(where: { $0.id == tag.id }) {
            papers[paperIndex].tags.append(tag)
            savePapers()
        }
    }
    
    // 从论文中移除标签
    func removeTag(_ tag: Tag, fromPaper paper: Paper) {
        guard let paperIndex = papers.firstIndex(where: { $0.id == paper.id }) else { return }
        
        papers[paperIndex].tags.removeAll { $0.id == tag.id }
        savePapers()
    }
    
    // MARK: - 笔记管理
    
    // 添加笔记到论文
    func addNote(_ note: Note, toPaper paper: Paper) {
        guard let paperIndex = papers.firstIndex(where: { $0.id == paper.id }) else { return }
        
        // 确保notes数组存在
        if papers[paperIndex].notes == nil {
            papers[paperIndex].notes = []
        }
        
        papers[paperIndex].notes?.append(note)
        savePapers()
    }
    
    // 更新论文中的笔记
    func updateNote(_ note: Note, inPaper paper: Paper) {
        guard let paperIndex = papers.firstIndex(where: { $0.id == paper.id }),
              let notes = papers[paperIndex].notes,
              let noteIndex = notes.firstIndex(where: { $0.id == note.id }) else { return }
        
        papers[paperIndex].notes?[noteIndex] = note
        savePapers()
    }
    
    // 从论文中删除笔记
    func deleteNote(_ note: Note, fromPaper paper: Paper) {
        guard let paperIndex = papers.firstIndex(where: { $0.id == paper.id }) else { return }
        
        // 确保notes数组存在
        if papers[paperIndex].notes != nil {
            papers[paperIndex].notes?.removeAll(where: { $0.id == note.id })
        }
        savePapers()
    }
    
    // MARK: - 收藏管理
    
    // 切换论文的收藏状态
    func toggleFavorite(for paper: Paper) {
        guard let paperIndex = papers.firstIndex(where: { $0.id == paper.id }) else { return }
        
        papers[paperIndex].isFavorite.toggle()
        savePapers()
    }
    
    // 获取所有收藏的论文
    var favoritePapers: [Paper] {
        papers.filter { $0.isFavorite }
    }
    
    // MARK: - 阅读进度
    
    // 更新论文的阅读进度
    func updateReadingProgress(_ progress: ReadingProgress, for paper: Paper) {
        guard let paperIndex = papers.firstIndex(where: { $0.id == paper.id }) else { return }
        
        papers[paperIndex].readingProgress = progress
        papers[paperIndex].lastOpened = Date()
        savePapers()
    }
    
    // 获取最近阅读的论文
    var recentlyReadPapers: [Paper] {
        return papers.sorted(by: { 
            guard let date1 = $0.lastOpened, let date2 = $1.lastOpened else {
                // 如果一个日期为nil，将其视为较早的日期
                return $0.lastOpened != nil && $1.lastOpened == nil
            }
            return date1 > date2
        })
    }
    
    // MARK: - 辅助方法
    
    // 创建导入目录
    private func createImportDirectoryIfNeeded() {
        do {
            if !FileManager.default.fileExists(atPath: importDirectory.path) {
                try FileManager.default.createDirectory(at: importDirectory, withIntermediateDirectories: true)
            }
        } catch {
            print("创建导入目录失败: \(error.localizedDescription)")
        }
    }
    
    // 复制论文文件到应用目录
    private func copyPaperFile(from sourceURL: URL) -> AnyPublisher<URL, Error> {
        Future<URL, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(LibraryError.serviceUnavailable))
                return
            }
            
            do {
                // 生成唯一文件名
                let fileName = "\(UUID().uuidString).pdf"
                let destinationURL = self.importDirectory.appendingPathComponent(fileName)
                
                // 复制文件
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                promise(.success(destinationURL))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // 从PDF中提取元数据
    private func extractMetadata(from url: URL) -> AnyPublisher<PaperMetadata, Error> {
        return Future<PaperMetadata, Error> { promise in
            // 加载PDF并提取基本信息
            if self.pdfService.loadDocument(from: url) {
                // 提取基本元数据
                let metadata = PaperMetadata(
                    title: self.pdfService.extractTitle(),
                    authors: self.pdfService.extractAuthors(),
                    date: Date(), // PDF中通常难以准确提取日期
                    journal: nil, // 需要额外处理才能获取期刊信息
                    abstract: self.pdfService.generateAbstract(),
                    keywords: self.pdfService.extractKeywords(),
                    doi: nil // 也需要额外处理
                )
                promise(.success(metadata))
            } else {
                promise(.failure(LibraryError.metadataExtractionFailed))
            }
        }.eraseToAnyPublisher()
    }
    
    // 使用AI分析论文
    private func analyzePaper(_ paper: Paper) -> AnyPublisher<Paper, Error> {
        guard let fileURL = paper.fileURL else {
            return Fail(error: LibraryError.fileNotFound).eraseToAnyPublisher()
        }
        
        return pdfService.extractText(from: fileURL)
            .flatMap { [weak self] text -> AnyPublisher<Paper, Error> in
                guard let self = self else {
                    return Fail(error: LibraryError.serviceUnavailable).eraseToAnyPublisher()
                }
                
                // 使用extractedText生成摘要（如果论文没有摘要）
                if paper.abstract.isEmpty {
                    return self.aiService.generateSummary(from: text)
                        .map { summary -> Paper in
                            var updatedPaper = paper
                            updatedPaper.abstract = summary
                            return updatedPaper
                        }
                        .eraseToAnyPublisher()
                } else {
                    return Just(paper)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - 持久化
    
    // 加载保存的数据
    private func loadSavedData() {
        do {
            papers = try storageManager.load([Paper].self, from: "papers.json") ?? []
            categories = try storageManager.load([Category].self, from: "categories.json") ?? []
            
            // 添加默认类别（如果没有）
            if categories.isEmpty {
                let defaultCategories = [
                    Category(id: UUID(), name: "未分类", color: .gray),
                    Category(id: UUID(), name: "机器学习", color: .blue),
                    Category(id: UUID(), name: "自然语言处理", color: .green),
                    Category(id: UUID(), name: "计算机视觉", color: .purple)
                ]
                categories = defaultCategories
                saveCategories()
            }
        } catch {
            print("加载数据失败: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    // 保存论文数据
    private func savePapers() {
        do {
            try storageManager.save(papers, to: "papers.json")
        } catch {
            print("保存论文失败: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    // 保存类别数据
    private func saveCategories() {
        do {
            try storageManager.save(categories, to: "categories.json")
        } catch {
            print("保存类别失败: \(error.localizedDescription)")
            self.error = error
        }
    }
}

// MARK: - 辅助类型

// 论文元数据结构
struct PaperMetadata {
    var title: String?
    var authors: [String] = []
    var date: Date?
    var journal: String?
    var abstract: String?
    var keywords: [String] = []
    var doi: String?
}

// 错误类型
enum LibraryError: Error {
    case fileImportFailed
    case metadataExtractionFailed
    case fileNotFound
    case serviceUnavailable
    
    var localizedDescription: String {
        switch self {
        case .fileImportFailed:
            return "导入文件失败"
        case .metadataExtractionFailed:
            return "提取元数据失败"
        case .fileNotFound:
            return "找不到文件"
        case .serviceUnavailable:
            return "服务不可用"
        }
    }
} 