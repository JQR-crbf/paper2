//
//  PaperDetailView.swift
//  Paper analysis tool
//
//  Created by 金倩如AI on 2025/4/1.
//

import SwiftUI
import PDFKit
import Combine

struct PaperDetailView: View {
    let paper: Paper
    let pdfService: PDFService
    
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var wordService = WordService()
    
    @State private var currentPage = 0
    @State private var showingMetadata = false
    @State private var showingAnalysisView = false
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var searchResults: [PDFSelection] = []
    @State private var isSearching = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var currentSearchResult: PDFSelection? = nil
    @State private var showingPDFReader = false
    
    var tabs = ["内容", "笔记", "结构", "分析", "关键词", "代码片段"]
    
    // 定义明确的初始化方法
    init(paper: Paper, pdfService: PDFService) {
        self.paper = paper
        self.pdfService = pdfService
    }
    
    var body: some View {
        VStack {
            // 顶部导航栏
            HStack {
                Button(action: {
                    // 返回上一页
                }) {
                    Image(systemName: "chevron.left")
                }
                
                Spacer()
                
                Text(paper.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    showingMetadata = true
                }) {
                    Image(systemName: "info.circle")
                }
            }
            .padding()
            
            // 标签栏
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                        Button(action: {
                            selectedTab = index
                        }) {
                            Text(tab)
                                .foregroundColor(selectedTab == index ? .blue : .gray)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // 内容区域
            TabView(selection: $selectedTab) {
                documentViewerSection
                    .tabItem {
                        Label("阅读", systemImage: "doc.text")
                    }
                    .tag(0)
                    .overlay(
                        VStack {
                            Spacer()
                            
                            Button(action: {
                                if let _ = paper.fileURL, paper.fileURL?.pathExtension.lowercased() == "pdf" {
                                    showingPDFReader = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "book.fill")
                                    Text("全屏阅读")
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .shadow(radius: 3)
                            }
                            .padding(.bottom, 20)
                        },
                        alignment: .bottom
                    )
                
                NotesView(paper: paper, currentPage: currentPage)
                    .tabItem {
                        Label("笔记", systemImage: "note.text")
                    }
                    .tag(1)
                
                if let fileURL = paper.fileURL, fileURL.pathExtension.lowercased() == "pdf" {
                    PaperStructureView(pdfService: pdfService)
                        .tabItem {
                            Label("结构", systemImage: "list.bullet")
                        }
                        .tag(2)
                }
                
                PaperAnalysisView(paper: paper, pdfService: pdfService)
                    .tabItem {
                        Label("分析", systemImage: "brain")
                    }
                    .tag(3)
                
                if let fileURL = paper.fileURL, fileURL.pathExtension.lowercased() == "pdf" {
                    KeywordsAnalysisView(paper: paper, pdfService: pdfService)
                        .tabItem {
                            Label("关键词", systemImage: "tag")
                        }
                        .tag(4)
                }
                
                CodeSnippetView(paper: paper)
                    .tabItem {
                        Label("代码片段", systemImage: "text.code")
                    }
                    .tag(5)
            }
        }
        .sheet(isPresented: $showingMetadata) {
            PaperMetadataView(paper: paper)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showingPDFReader) {
            PDFReaderView(paper: paper)
                .environmentObject(dataStore)
        }
        .onAppear {
            // 根据文档类型加载相应的服务
            if let fileURL = paper.fileURL {
                if fileURL.pathExtension.lowercased() == "pdf" {
                    if pdfService.loadDocument(from: fileURL) {
                        print("PDF加载成功: \(paper.title)")
                    } else {
                        print("PDF加载失败: \(fileURL.path)")
                    }
                } else if fileURL.pathExtension.lowercased() == "docx" || fileURL.pathExtension.lowercased() == "doc" {
                    if wordService.loadDocument(from: fileURL) {
                        print("Word文档加载成功: \(paper.title)")
                    } else {
                        print("Word文档加载失败: \(fileURL.path)")
                    }
                }
            }
        }
    }
    
    private var documentViewerSection: some View {
        Group {
            if let fileURL = paper.fileURL {
                if fileURL.pathExtension.lowercased() == "pdf" {
                    PDFViewerContainer(
                        document: pdfService.document,
                        currentPage: $currentPage,
                        totalPages: .constant(pdfService.pageCount),
                        searchText: $searchText,
                        searchResults: $searchResults,
                        currentSearchResult: $currentSearchResult,
                        isSearching: $isSearching
                    )
                } else if fileURL.pathExtension.lowercased() == "docx" || fileURL.pathExtension.lowercased() == "doc" {
                    WordViewerContainer(documentURL: fileURL, wordService: wordService)
                } else {
                    Text("不支持的文档格式")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                }
            } else {
                Text("文件URL不可用")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
        }
    }
    
    private func performSearch() {
        if !searchText.isEmpty {
            isSearching = true
            DispatchQueue.global(qos: .userInitiated).async {
                let results = pdfService.search(for: searchText)
                DispatchQueue.main.async {
                    searchResults = results
                    isSearching = false
                    
                    // 如果有结果，跳转到第一个结果所在页面
                    if let firstResult = results.first,
                       let firstPage = firstResult.pages.first {
                        // 找到页面索引
                        for i in 0..<pdfService.pageCount {
                            if let page = pdfService.page(at: i),
                               page == firstPage {
                                currentPage = i
                                break
                            }
                        }
                    }
                }
            }
        }
    }
}

// PDF查看器容器
struct PDFViewerContainer: UIViewRepresentable {
    let document: PDFDocument?
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var searchText: String
    @Binding var searchResults: [PDFSelection]
    @Binding var currentSearchResult: PDFSelection?
    @Binding var isSearching: Bool
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
        pdfView.displayDirection = .vertical
        pdfView.document = document
        
        // 设置代理
        pdfView.delegate = context.coordinator
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // 更新当前页
        if let document = pdfView.document,
           currentPage >= 0 && currentPage < document.pageCount,
           let page = document.page(at: currentPage) {
            pdfView.go(to: page)
        }
        
        // 高亮搜索结果
        if let currentSearchResult = currentSearchResult,
           !searchResults.isEmpty && !isSearching {
            pdfView.highlightedSelections = [currentSearchResult]
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFViewerContainer
        
        init(_ parent: PDFViewerContainer) {
            self.parent = parent
        }
        
        func pdfViewPageChanged(_ pdfView: PDFView) {
            if let currentPage = pdfView.currentPage,
               let document = pdfView.document {
                for i in 0..<document.pageCount {
                    if let page = document.page(at: i),
                       page == currentPage {
                        parent.currentPage = i
                        break
                    }
                }
            }
        }
    }
}

// Word文档查看容器
struct WordViewerContainer: View {
    let documentURL: URL
    @ObservedObject var wordService: WordService
    
    var body: some View {
        ZStack {
            if wordService.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if wordService.documentContent.isEmpty {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("加载失败")
                        .font(.headline)
                    Text("无法读取文档内容")
                }
            } else {
                ScrollView {
                    Text(wordService.documentContent)
                        .padding()
                }
            }
        }
        .onAppear {
            if wordService.documentContent.isEmpty {
                _ = wordService.loadDocument(from: documentURL)
            }
        }
    }
}

// 论文元数据视图
struct PaperMetadataView: View {
    let paper: Paper
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                Text(paper.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                // 作者
                VStack(alignment: .leading, spacing: 4) {
                    Text("作者")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(paper.formattedAuthors)
                        .font(.body)
                }
                
                // 发表日期
                VStack(alignment: .leading, spacing: 4) {
                    Text("发表日期")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(paper.formattedDate)
                        .font(.body)
                }
                
                // 期刊
                if let journal = paper.journal, !journal.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("期刊")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(journal)
                            .font(.body)
                    }
                }
                
                // 关键词
                if !paper.keywords.isEmpty {
                    VStack(alignment: .leading) {
                        Text("关键词")
                            .font(.headline)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(paper.keywords, id: \.self) { keyword in
                                Text(keyword)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                
                // 摘要
                if !paper.abstract.isEmpty {
                    VStack(alignment: .leading) {
                        Text("摘要")
                            .font(.headline)
                        
                        Text(paper.abstract)
                            .lineSpacing(4)
                    }
                }
                
                // 文件信息
                VStack(alignment: .leading) {
                    Text("文件信息")
                        .font(.headline)
                    
                    if let fileURL = paper.fileURL {
                        Text("文件路径: \(fileURL.lastPathComponent)")
                            .font(.caption)
                    }
                    
                    Text("添加日期: \(formatDate(paper.dateAdded))")
                        .font(.caption)
                }
            }
            .padding()
        }
        .navigationTitle("论文信息")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// 笔记视图
struct NotesView: View {
    let paper: Paper
    let currentPage: Int
    @EnvironmentObject var dataStore: DataStore
    @State private var newNote = ""
    
    var body: some View {
        VStack {
            if let notes = paper.notes, !notes.isEmpty {
                List {
                    ForEach(notes) { note in
                        VStack(alignment: .leading) {
                            HStack {
                                Text("笔记")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(note.formattedTimestamp)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(note.content)
                                .font(.body)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                    }
                    .onDelete { indexSet in
                        // 删除笔记的逻辑需要通过数据存储实现
                        let updatedPaper = paper
                        if updatedPaper.notes == nil {
                            return
                        }
                        
                        // 创建要删除的笔记数组
                        let notesToDelete = indexSet.map { updatedPaper.notes![$0] }
                        
                        // 逐个删除笔记
                        for note in notesToDelete {
                            dataStore.deleteNote(note)
                        }
                    }
                }
            } else {
                EmptyStateView(
                    title: "暂无笔记",
                    message: "添加笔记记录论文的要点和思考",
                    systemImage: "note.text",
                    buttonTitle: "添加笔记",
                    action: {}
                )
                .padding()
            }
            
            // 添加笔记输入框
            HStack {
                TextField("添加新笔记...", text: $newNote)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: {
                    if !newNote.isEmpty {
                        // 创建新笔记
                        let note = Note(
                            id: UUID(),
                            content: newNote,
                            timestamp: Date(),
                            pageNumber: currentPage,
                            tags: [],
                            paperId: paper.id
                        )
                        
                        // 添加笔记到数据存储
                        dataStore.addNote(note)
                        
                        newNote = ""
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .imageScale(.large)
                }
                .disabled(newNote.isEmpty)
            }
            .padding()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// 论文结构视图
struct PaperStructureView: View {
    let pdfService: PDFService
    @State private var sections: [PaperSection] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("正在分析论文结构...")
            } else if sections.isEmpty {
                EmptyStateView(
                    title: "无法识别结构",
                    message: "未能识别出论文章节结构",
                    systemImage: "doc.text.magnifyingglass",
                    buttonTitle: "",
                    action: {}
                )
                .padding()
            } else {
                List(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(section.level == 1 ? .headline : .subheadline)
                            .fontWeight(section.level == 1 ? .bold : .medium)
                        
                        Text("第\(section.pageNumber)页")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !section.content.isEmpty {
                            Text(section.content.prefix(100))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            // 分析论文结构
            DispatchQueue.global(qos: .userInitiated).async {
                let detectedSections = pdfService.identifySections()
                DispatchQueue.main.async {
                    sections = detectedSections
                    isLoading = false
                }
            }
        }
    }
}

// 论文分析视图
final class PaperAnalysisView: View, ObservableObject {
    let paper: Paper
    let pdfService: PDFService
    
    @EnvironmentObject var userSettings: UserSettings
    @StateObject private var aiService = AIAnalysisService()
    @Published var analysisResult: String = ""
    @Published var isAnalyzing = false
    @Published var selectedAnalysisType: AnalysisType = .summary
    @Published var progressValue: Double = 0
    @Published var keyConcepts: [ConceptItem] = []
    @Published var methodAnalysis: MethodAnalysisResult?
    @Published var contributionsAnalysis: ContributionsAnalysisResult?
    @Published var futureDirections: FutureDirectionsResult?
    @Published var literatureConnections: LiteratureConnectionsResult?
    @Published var researchQuestions: [String] = []
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var hasResults = false
    
    // 声明一个公共的 cancellables 集合
    private var cancellables = Set<AnyCancellable>()
    
    init(paper: Paper, pdfService: PDFService) {
        self.paper = paper
        self.pdfService = pdfService
    }
    
    enum AnalysisType: String, CaseIterable, Identifiable {
        case summary = "摘要总结"
        case keyConcepts = "关键概念"
        case methods = "方法分析"
        case contributions = "主要贡献"
        case futureDirections = "未来方向"
        case researchQuestions = "研究问题"
        case literatureReview = "文献关联"
        case knowledgeGraph = "知识图谱"
        
        var id: String { self.rawValue }
        
        var systemImage: String {
            switch self {
            case .summary: return "text.redaction"
            case .keyConcepts: return "lightbulb"
            case .methods: return "wrench.and.screwdriver"
            case .contributions: return "star"
            case .futureDirections: return "arrow.right.circle"
            case .researchQuestions: return "questionmark.circle"
            case .literatureReview: return "books.vertical"
            case .knowledgeGraph: return "graph"
            }
        }
    }
    
    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AnalysisType.allCases) { type in
                        Button(action: {
                            if self.selectedAnalysisType != type {
                                self.selectedAnalysisType = type
                                self.hasResults = false
                                self.clearCurrentResults()
                            }
                        }) {
                            HStack {
                                Image(systemName: type.systemImage)
                                Text(type.rawValue)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(self.getBackgroundColor(for: type))
                            .foregroundColor(self.getForegroundColor(for: type))
                            .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            if isAnalyzing {
                VStack {
                    ProgressView("正在分析...", value: progressValue, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding()
                    
                    Text(String(format: "%.0f%%", progressValue * 100))
                        .font(.caption)
                }
                .padding()
            } else if !self.hasResultForCurrentType() {
                EmptyStateView(
                    title: "开始分析",
                    message: "使用AI分析该论文的\(self.selectedAnalysisType.rawValue)，获取关键见解",
                    systemImage: self.selectedAnalysisType.systemImage,
                    buttonTitle: "开始分析",
                    action: {
                        self.performAnalysis()
                    }
                )
                .padding()
            } else {
                analysisResultView
                    .padding()
                    .animation(.easeInOut, value: selectedAnalysisType)
            }
            
            if self.hasResultForCurrentType() {
                Button(action: {
                    self.clearCurrentResults()
                    self.performAnalysis()
                }) {
                    Text("重新分析")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .onAppear {
            self.setupAIService()
        }
        .alert(isPresented: Binding<Bool>(
            get: { self.showError },
            set: { self.showError = $0 }
        )) {
            Alert(title: Text("分析失败"), message: Text(errorMessage), dismissButton: .default(Text("确定")))
        }
        .onReceive(aiService.$isAnalyzing) { value in
            self.isAnalyzing = value
        }
        .onReceive(aiService.$progress) { value in
            self.progressValue = value
        }
        .onReceive(aiService.$error) { value in
            if let error = value {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
    
    @ViewBuilder
    private var analysisResultView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(selectedAnalysisType.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 4)
                
                switch selectedAnalysisType {
                case .summary:
                    Text(analysisResult)
                        .lineSpacing(6)
                
                case .keyConcepts:
                    ForEach(keyConcepts) { concept in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(concept.name)
                                    .font(.headline)
                                Spacer()
                                HStack(spacing: 1) {
                                    ForEach(0..<concept.importance, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.caption)
                                    }
                                    ForEach(0..<(5-concept.importance), id: \.self) { _ in
                                        Image(systemName: "star")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                }
                            }
                            
                            Text(concept.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                
                case .methods:
                    if let methodAnalysis = methodAnalysis {
                        methodAnalysisView(methodAnalysis)
                    }
                
                case .contributions:
                    if let contributionsAnalysis = contributionsAnalysis {
                        contributionsAnalysisView(contributionsAnalysis)
                    }
                
                case .futureDirections:
                    if let futureDirections = futureDirections {
                        futureDirectionsView(futureDirections)
                    }
                
                case .researchQuestions:
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(researchQuestions.indices, id: \.self) { index in
                            HStack(alignment: .top) {
                                Text("\(index + 1).")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Text(self.researchQuestions[index])
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                
                case .literatureReview:
                    if let literatureConnections = literatureConnections {
                        literatureConnectionsView(literatureConnections)
                    }
                
                case .knowledgeGraph:
                    knowledgeGraphView(for: paper)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private func methodAnalysisView(_ analysis: MethodAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("主要方法")
                    .font(.headline)
                Text(analysis.mainApproach)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("使用的数据集")
                    .font(.headline)
                ForEach(analysis.datasets, id: \.self) { dataset in
                    HStack {
                        Image(systemName: "database")
                            .foregroundColor(.blue)
                        Text(dataset)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("评估指标")
                    .font(.headline)
                ForEach(analysis.evaluationMetrics, id: \.self) { metric in
                    HStack {
                        Image(systemName: "chart.bar")
                            .foregroundColor(.green)
                        Text(metric)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("方法局限性")
                    .font(.headline)
                ForEach(analysis.limitations, id: \.self) { limitation in
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(limitation)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func contributionsAnalysisView(_ analysis: ContributionsAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !analysis.theoretical.isEmpty {
                contributionSection(title: "理论贡献", items: analysis.theoretical, iconName: "lightbulb", color: .yellow)
            }
            
            if !analysis.methodological.isEmpty {
                contributionSection(title: "方法贡献", items: analysis.methodological, iconName: "hammer", color: .blue)
            }
            
            if !analysis.practical.isEmpty {
                contributionSection(title: "实践应用", items: analysis.practical, iconName: "gear", color: .green)
            }
            
            if !analysis.limitations.isEmpty {
                contributionSection(title: "研究局限性", items: analysis.limitations, iconName: "exclamationmark.triangle", color: .orange)
            }
        }
    }
    
    @ViewBuilder
    private func contributionSection(title: String, items: [String], iconName: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top) {
                    Image(systemName: iconName)
                        .foregroundColor(color)
                        .frame(width: 24, height: 24)
                    
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func futureDirectionsView(_ directions: FutureDirectionsResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !directions.shortTerm.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("短期研究方向")
                        .font(.headline)
                    
                    ForEach(directions.shortTerm, id: \.self) { direction in
                        HStack(alignment: .top) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                            
                            Text(direction)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
            
            if !directions.longTerm.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("长期研究方向")
                        .font(.headline)
                    
                    ForEach(directions.longTerm, id: \.self) { direction in
                        HStack(alignment: .top) {
                            Image(systemName: "arrow.right.to.line.alt")
                                .foregroundColor(.purple)
                                .frame(width: 24, height: 24)
                            
                            Text(direction)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.05))
                .cornerRadius(8)
            }
            
            if !directions.potentialImpact.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("潜在影响")
                        .font(.headline)
                    
                    ForEach(directions.potentialImpact, id: \.self) { impact in
                        HStack(alignment: .top) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24, height: 24)
                            
                            Text(impact)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private func literatureConnectionsView(_ connections: LiteratureConnectionsResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !connections.relatedFields.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("相关研究领域")
                        .font(.headline)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(connections.relatedFields, id: \.self) { field in
                            Text(field)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(16)
                        }
                    }
                }
            }
            
            if !connections.keyPapers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("相关论文")
                        .font(.headline)
                    
                    ForEach(connections.keyPapers) { paper in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(paper.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Text(paper.authors)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(paper.year)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(paper.relationship)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
            
            if !connections.researchGaps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("研究空白")
                        .font(.headline)
                    
                    ForEach(connections.researchGaps, id: \.self) { gap in
                        HStack(alignment: .top) {
                            Image(systemName: "puzzlepiece")
                                .foregroundColor(.purple)
                            
                            Text(gap)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    private func setupAIService() {
        // 获取当前AI设置
        let (apiKey, baseURL, model, enableKnowledgeBase, knowledgeBaseId) = userSettings.getCurrentAISettings()
        
        // 更新AI服务配置
        aiService.updateSettings(
            apiKey: apiKey,
            baseURL: baseURL,
            useSimulatedData: userSettings.useSimulatedData,
            selectedModel: model,
            serviceProvider: userSettings.aiServiceProvider,
            enableKnowledgeBase: enableKnowledgeBase,
            knowledgeBaseId: knowledgeBaseId
        )
    }
    
    private func hasResultForCurrentType() -> Bool {
        if !self.hasResults {
            switch selectedAnalysisType {
            case .summary: self.hasResults = !analysisResult.isEmpty
            case .keyConcepts: self.hasResults = !keyConcepts.isEmpty
            case .methods: self.hasResults = methodAnalysis != nil
            case .contributions: self.hasResults = contributionsAnalysis != nil
            case .futureDirections: self.hasResults = futureDirections != nil
            case .researchQuestions: self.hasResults = !researchQuestions.isEmpty
            case .literatureReview: self.hasResults = literatureConnections != nil
            case .knowledgeGraph: self.hasResults = true
            }
        }
        return self.hasResults
    }
    
    func clearCurrentResults() {
        analysisResult = ""
        keyConcepts = []
        methodAnalysis = nil
        contributionsAnalysis = nil
        futureDirections = nil
        researchQuestions = []
        literatureConnections = nil
    }
    
    func performAnalysis() {
        setupAIService()
        
        // 确保有内容可分析
        let pdfText = pdfService.extractText(from: 0)
        if pdfText.isEmpty {
            errorMessage = "无法提取PDF文本内容"
            showError = true
            return
        }
        
        let text = !paper.abstract.isEmpty ? paper.abstract : pdfText
        
        switch selectedAnalysisType {
        case .summary:
            aiService.generateSummary(from: text)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                        }
                    },
                    receiveValue: { result in
                        self.analysisResult = result
                    }
                )
                .store(in: &cancellables)
            
        case .keyConcepts:
            aiService.extractKeyConcepts(from: text)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                        }
                    },
                    receiveValue: { result in
                        self.keyConcepts = result
                    }
                )
                .store(in: &cancellables)
            
        case .methods:
            aiService.analyzeMethodology(from: text)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                        }
                    },
                    receiveValue: { result in
                        self.methodAnalysis = result
                    }
                )
                .store(in: &cancellables)
            
        case .contributions:
            aiService.analyzeContributions(from: text)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                        }
                    },
                    receiveValue: { result in
                        self.contributionsAnalysis = result
                    }
                )
                .store(in: &cancellables)
            
        case .futureDirections:
            aiService.analyzeFutureDirections(from: text)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                        }
                    },
                    receiveValue: { result in
                        self.futureDirections = result
                    }
                )
                .store(in: &cancellables)
            
        case .researchQuestions:
            aiService.generateResearchQuestions(from: text)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                        }
                    },
                    receiveValue: { result in
                        self.researchQuestions = result
                    }
                )
                .store(in: &cancellables)
            
        case .literatureReview:
            aiService.analyzeLiteratureConnections(paperTitle: paper.title, abstract: paper.abstract)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                        }
                    },
                    receiveValue: { result in
                        self.literatureConnections = result
                    }
                )
                .store(in: &cancellables)
            
        case .knowledgeGraph:
            // Implementation of knowledge graph analysis
            break
        }
    }
    
    // 辅助方法用于简化背景色和前景色的计算
    private func getBackgroundColor(for type: AnalysisType) -> Color {
        return self.selectedAnalysisType == type ? Color.blue : Color.gray.opacity(0.2)
    }
    
    private func getForegroundColor(for type: AnalysisType) -> Color {
        return self.selectedAnalysisType == type ? .white : .primary
    }
}

// 流式布局（用于标签展示）
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            
            if x + viewSize.width > width {
                y += maxHeight + spacing
                x = 0
                maxHeight = 0
            }
            
            maxHeight = max(maxHeight, viewSize.height)
            x += viewSize.width + spacing
            
            if x > width {
                y += maxHeight + spacing
                height = y
            } else {
                height = y + maxHeight
            }
        }
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let _ = bounds.width
        
        var x = bounds.minX
        var y = bounds.minY
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            
            if x + viewSize.width > bounds.maxX {
                y += maxHeight + spacing
                x = bounds.minX
                maxHeight = 0
            }
            
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            
            maxHeight = max(maxHeight, viewSize.height)
            x += viewSize.width + spacing
        }
    }
}

// 添加知识图谱视图
private func knowledgeGraphView(for paper: Paper) -> some View {
    VStack {
        if paper.id != UUID() {
            PaperKnowledgeGraphView(paper: paper)
        } else {
            EmptyStateView(
                title: "没有选中论文",
                message: "请先选择一篇论文",
                systemImage: "doc.text.magnifyingglass",
                buttonTitle: "返回",
                action: { }
            )
        }
    }
}

#Preview {
    NavigationView {
        PaperDetailView(paper: Paper.example, pdfService: PDFService())
            .environmentObject(UserSettings())
            .environmentObject(DataStore())
    }
} 