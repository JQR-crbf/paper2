import Foundation
import Combine
import PDFKit

class SearchService: ObservableObject {
    // 发布属性
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var searchQuery: String = "" {
        didSet {
            guard !searchQuery.isEmpty else {
                searchResults = []
                return
            }
            
            debouncedSearch()
        }
    }
    
    // 错误处理
    @Published var error: Error?
    
    // 依赖的服务
    private let paperLibraryService: PaperLibraryService
    private let pdfService: PDFService
    private let storageManager: StorageManager
    
    // Debounce定时器
    private var debounceTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // 搜索延迟时间（毫秒）
    private let debounceDelay: TimeInterval = 0.3
    
    // 搜索设置
    private var searchInTitles: Bool = true
    private var searchInAuthors: Bool = true
    private var searchInAbstracts: Bool = true
    private var searchInContent: Bool = true
    private var searchInNotes: Bool = true
    private var searchInTags: Bool = true
    
    init(paperLibraryService: PaperLibraryService, pdfService: PDFService, storageManager: StorageManager) {
        self.paperLibraryService = paperLibraryService
        self.pdfService = pdfService
        self.storageManager = storageManager
    }
    
    // MARK: - 公共方法
    
    // 更新搜索设置
    func updateSearchSettings(inTitles: Bool? = nil, inAuthors: Bool? = nil, inAbstracts: Bool? = nil, inContent: Bool? = nil, inNotes: Bool? = nil, inTags: Bool? = nil) {
        if let inTitles = inTitles {
            searchInTitles = inTitles
        }
        if let inAuthors = inAuthors {
            searchInAuthors = inAuthors
        }
        if let inAbstracts = inAbstracts {
            searchInAbstracts = inAbstracts
        }
        if let inContent = inContent {
            searchInContent = inContent
        }
        if let inNotes = inNotes {
            searchInNotes = inNotes
        }
        if let inTags = inTags {
            searchInTags = inTags
        }
        
        // 如果有搜索查询，刷新搜索结果
        if !searchQuery.isEmpty {
            search()
        }
    }
    
    // 手动触发搜索
    func search() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        // 取消之前的定时器
        debounceTimer?.invalidate()
        
        isSearching = true
        
        // 获取所有论文
        let papers = paperLibraryService.papers
        
        // 执行搜索
        performSearch(query: searchQuery, in: papers)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.error = error
                }
                self?.isSearching = false
            }, receiveValue: { [weak self] results in
                self?.searchResults = results
                self?.isSearching = false
            })
            .store(in: &cancellables)
    }
    
    // 清除搜索结果
    func clearSearch() {
        searchQuery = ""
        searchResults = []
    }
    
    // MARK: - 私有辅助方法
    
    // 延迟搜索（减少API调用）
    private func debouncedSearch() {
        // 取消之前的定时器
        debounceTimer?.invalidate()
        
        // 创建新的定时器
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceDelay, repeats: false) { [weak self] _ in
            self?.search()
        }
    }
    
    // 执行搜索操作
    private func performSearch(query: String, in papers: [Paper]) -> AnyPublisher<[SearchResult], Error> {
        // 1. 初始化搜索结果
        var publishers: [AnyPublisher<[SearchResult], Error>] = []
        
        // 2. 搜索元数据（标题、作者、摘要等）
        publishers.append(searchMetadata(query: query, in: papers))
        
        // 3. 如果设置了搜索内容，添加内容搜索
        if searchInContent {
            publishers.append(searchContent(query: query, in: papers))
        }
        
        // 4. 如果设置了搜索笔记，添加笔记搜索
        if searchInNotes {
            publishers.append(searchNotes(query: query, in: papers))
        }
        
        // 5. 合并所有搜索结果
        return Publishers.MergeMany(publishers)
            .collect()
            .map { resultsArray -> [SearchResult] in
                // 合并并去重
                let allResults = resultsArray.flatMap { $0 }
                var uniqueResults: [SearchResult] = []
                
                for result in allResults {
                    if !uniqueResults.contains(where: { $0.id == result.id }) {
                        uniqueResults.append(result)
                    }
                }
                
                // 按相关性排序
                return uniqueResults.sorted { $0.relevance > $1.relevance }
            }
            .eraseToAnyPublisher()
    }
    
    // 搜索元数据（标题、作者、摘要、标签）
    private func searchMetadata(query: String, in papers: [Paper]) -> AnyPublisher<[SearchResult], Error> {
        return Future<[SearchResult], Error> { promise in
            var results: [SearchResult] = []
            
            for paper in papers {
                var foundInPaper = false
                var relevance: Double = 0
                var snippets: [String] = []
                
                // 搜索标题
                if self.searchInTitles && paper.title.localizedCaseInsensitiveContains(query) {
                    foundInPaper = true
                    relevance += 1.0
                    snippets.append("标题: \(paper.title)")
                }
                
                // 搜索作者
                if self.searchInAuthors {
                    for author in paper.authors {
                        if author.localizedCaseInsensitiveContains(query) {
                            foundInPaper = true
                            relevance += 0.8
                            snippets.append("作者: \(author)")
                            break
                        }
                    }
                }
                
                // 搜索摘要
                if self.searchInAbstracts && paper.abstract.localizedCaseInsensitiveContains(query) {
                    foundInPaper = true
                    relevance += 0.7
                    
                    // 提取摘要中包含查询词的部分作为片段
                    if let range = paper.abstract.range(of: query, options: .caseInsensitive) {
                        let start = max(0, paper.abstract.distance(from: paper.abstract.startIndex, to: range.lowerBound) - 20)
                        let end = min(paper.abstract.count, paper.abstract.distance(from: paper.abstract.startIndex, to: range.upperBound) + 20)
                        
                        let startIndex = paper.abstract.index(paper.abstract.startIndex, offsetBy: start)
                        let endIndex = paper.abstract.index(paper.abstract.startIndex, offsetBy: end)
                        let snippet = paper.abstract[startIndex..<endIndex]
                        
                        snippets.append("摘要: ...\(snippet)...")
                    }
                }
                
                // 搜索标签
                if self.searchInTags {
                    for tag in paper.tags {
                        if tag.name.localizedCaseInsensitiveContains(query) {
                            foundInPaper = true
                            relevance += 0.6
                            snippets.append("标签: \(tag.name)")
                            break
                        }
                    }
                }
                
                // 如果在该论文中找到了匹配项，创建搜索结果
                if foundInPaper {
                    let result = SearchResult(
                        id: UUID(),
                        paperId: paper.id,
                        title: paper.title,
                        snippets: snippets,
                        resultType: .paperMetadata,
                        relevance: relevance,
                        pageNumber: nil
                    )
                    results.append(result)
                }
            }
            
            promise(.success(results))
        }.eraseToAnyPublisher()
    }
    
    // 搜索论文内容
    private func searchContent(query: String, in papers: [Paper]) -> AnyPublisher<[SearchResult], Error> {
        let contentPublishers = papers.map { paper -> AnyPublisher<[SearchResult], Error> in
            return searchPDFContent(query: query, paper: paper)
        }
        
        return Publishers.MergeMany(contentPublishers)
            .collect()
            .map { resultsArray in
                return resultsArray.flatMap { $0 }
            }
            .eraseToAnyPublisher()
    }
    
    // 搜索单个PDF文档内容
    private func searchPDFContent(query: String, paper: Paper) -> AnyPublisher<[SearchResult], Error> {
        return Future<[SearchResult], Error> { promise in
            // 检查PDF文件URL是否存在
            guard let fileURL = paper.fileURL, let document = PDFDocument(url: fileURL) else {
                promise(.success([]))
                return
            }
            
            var results: [SearchResult] = []
            
            // 遍历每一页
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                guard let pageContent = page.string else { continue }
                
                // 搜索当前页
                if pageContent.localizedCaseInsensitiveContains(query) {
                    // 查找所有匹配位置
                    var searchRange = pageContent.startIndex..<pageContent.endIndex
                    var matches: [Range<String.Index>] = []
                    
                    while let range = pageContent.range(of: query, options: .caseInsensitive, range: searchRange) {
                        matches.append(range)
                        searchRange = range.upperBound..<pageContent.endIndex
                    }
                    
                    // 为每个匹配创建片段
                    for match in matches {
                        let start = max(0, pageContent.distance(from: pageContent.startIndex, to: match.lowerBound) - 40)
                        let end = min(pageContent.count, pageContent.distance(from: pageContent.startIndex, to: match.upperBound) + 40)
                        
                        let startIndex = pageContent.index(pageContent.startIndex, offsetBy: start)
                        let endIndex = pageContent.index(pageContent.startIndex, offsetBy: end)
                        let snippet = pageContent[startIndex..<endIndex]
                        
                        // 创建搜索结果
                        let result = SearchResult(
                            id: UUID(),
                            paperId: paper.id,
                            title: paper.title,
                            snippets: ["页面 \(pageIndex + 1): ...\(snippet)..."],
                            resultType: .paperContent,
                            relevance: 0.5, // 内容匹配的相关性较低
                            pageNumber: pageIndex + 1
                        )
                        results.append(result)
                    }
                }
            }
            
            promise(.success(results))
        }.eraseToAnyPublisher()
    }
    
    // 搜索笔记
    private func searchNotes(query: String, in papers: [Paper]) -> AnyPublisher<[SearchResult], Error> {
        return Future<[SearchResult], Error> { promise in
            var results: [SearchResult] = []
            
            for paper in papers {
                // 确保笔记数组不为nil
                guard let notes = paper.notes else { continue }
                
                // 搜索该论文的所有笔记
                for note in notes {
                    if note.content.localizedCaseInsensitiveContains(query) {
                        // 创建片段
                        let start = max(0, note.content.range(of: query, options: .caseInsensitive)?.lowerBound.utf16Offset(in: note.content) ?? 0 - 30)
                        let snippet = note.content.count > 60 
                            ? "...\(String(note.content.dropFirst(start).prefix(60)))..."
                            : note.content
                        
                        // 创建搜索结果
                        let result = SearchResult(
                            id: UUID(),
                            paperId: paper.id,
                            title: paper.title,
                            snippets: ["笔记: \(snippet)"],
                            resultType: .note,
                            relevance: 0.7, // 笔记匹配的相关性中等
                            pageNumber: note.pageNumber
                        )
                        results.append(result)
                    }
                }
            }
            
            promise(.success(results))
        }.eraseToAnyPublisher()
    }
}

// MARK: - 相关模型

// 搜索结果类型
enum SearchResultType: String, Codable {
    case paperMetadata = "元数据"
    case paperContent = "内容"
    case note = "笔记"
    case codeSnippet = "代码片段"
    
    var icon: String {
        switch self {
        case .paperMetadata:
            return "doc.text"
        case .paperContent:
            return "text.magnifyingglass"
        case .note:
            return "note.text"
        case .codeSnippet:
            return "curlybraces"
        }
    }
}

// 搜索结果模型
struct SearchResult: Identifiable, Equatable {
    var id: UUID
    var paperId: UUID
    var title: String
    var snippets: [String]
    var resultType: SearchResultType
    var relevance: Double // 搜索结果的相关性评分 (0-1)
    var pageNumber: Int?
    
    // Equatable实现
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

// 错误类型
enum SearchError: Error {
    case invalidSearchQuery
    case pdfReadError
    case searchFailed
    
    var localizedDescription: String {
        switch self {
        case .invalidSearchQuery:
            return "无效的搜索查询"
        case .pdfReadError:
            return "PDF读取错误"
        case .searchFailed:
            return "搜索失败"
        }
    }
} 