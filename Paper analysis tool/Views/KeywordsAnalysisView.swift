import SwiftUI
import PDFKit
import Combine

struct KeywordItem: Identifiable {
    var id = UUID()
    var name: String
    var englishName: String
    var frequency: Int
    var occurrences: [KeywordOccurrence]
}

struct KeywordOccurrence: Identifiable {
    var id = UUID()
    var pageNumber: Int
    var context: String
}

class KeywordsAnalysisViewModel: ObservableObject {
    @Published var keywords: [KeywordItem] = []
    @Published var selectedKeyword: KeywordItem?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var sortMethod: SortMethod = .frequency
    
    enum SortMethod: String, CaseIterable {
        case frequency = "频率"
        case alphabetical = "字母"
        case relevance = "相关性"
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadKeywords(for paper: Paper, pdfService: PDFService) {
        isLoading = true
        errorMessage = nil
        
        // 检查paper.keywords是否已有关键词，如果有则使用它们
        if !paper.keywords.isEmpty {
            // 将paper关键词转换为KeywordItem对象
            let initialKeywords = paper.keywords.map { keyword in
                KeywordItem(
                    name: keyword,
                    englishName: "",  // 这里可以为空，或者通过翻译服务获取
                    frequency: 0,
                    occurrences: []
                )
            }
            
            // 然后在PDF中查找这些关键词的出现次数和上下文
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self, let document = pdfService.document else {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.errorMessage = "无法加载PDF文档"
                    }
                    return
                }
                
                var enrichedKeywords = [KeywordItem]()
                
                for keyword in initialKeywords {
                    let selections = pdfService.search(for: keyword.name)
                    
                    var occurrences = [KeywordOccurrence]()
                    for selection in selections {
                        if let page = selection.pages.first {
                            let pageIndex = document.index(for: page) ?? 0
                            // 提取关键词出现的上下文
                            let context = selection.string ?? ""
                            let occurrence = KeywordOccurrence(
                                pageNumber: pageIndex + 1,
                                context: context
                            )
                            occurrences.append(occurrence)
                        }
                    }
                    
                    let enrichedKeyword = KeywordItem(
                        name: keyword.name,
                        englishName: keyword.englishName,
                        frequency: occurrences.count,
                        occurrences: occurrences
                    )
                    enrichedKeywords.append(enrichedKeyword)
                }
                
                // 根据出现频率排序
                enrichedKeywords.sort { $0.frequency > $1.frequency }
                
                DispatchQueue.main.async {
                    self.keywords = enrichedKeywords
                    if !enrichedKeywords.isEmpty {
                        self.selectedKeyword = enrichedKeywords[0]
                    }
                    self.isLoading = false
                }
            }
        } else {
            // 如果paper没有预定义的关键词，尝试使用AI服务提取
            // 这里可以调用AIAnalysisService
            // 简化处理，使用一些默认关键词
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.keywords = self.generateSampleKeywords()
                if !self.keywords.isEmpty {
                    self.selectedKeyword = self.keywords[0]
                }
                self.isLoading = false
            }
        }
    }
    
    // 生成示例关键词数据
    private func generateSampleKeywords() -> [KeywordItem] {
        return [
            KeywordItem(
                name: "图神经网络",
                englishName: "Graph Neural Network",
                frequency: 42,
                occurrences: [
                    KeywordOccurrence(pageNumber: 3, context: "图神经网络（Graph Neural Networks, GNNs）是一类专门用于处理图结构数据的深度学习模型..."),
                    KeywordOccurrence(pageNumber: 5, context: "与传统的神经网络相比，图神经网络能够更好地捕获节点间的关系...")
                ]
            ),
            KeywordItem(
                name: "推荐系统",
                englishName: "Recommendation System",
                frequency: 38,
                occurrences: [
                    KeywordOccurrence(pageNumber: 1, context: "推荐系统在电子商务和内容平台中扮演着至关重要的角色...")
                ]
            ),
            KeywordItem(
                name: "协同过滤",
                englishName: "Collaborative Filtering",
                frequency: 26,
                occurrences: [
                    KeywordOccurrence(pageNumber: 2, context: "协同过滤是推荐系统中的一种经典方法，通过分析用户行为模式...")
                ]
            ),
            KeywordItem(
                name: "注意力机制",
                englishName: "Attention Mechanism",
                frequency: 18,
                occurrences: [
                    KeywordOccurrence(pageNumber: 7, context: "注意力机制使模型能够动态地关注输入中的重要部分...")
                ]
            )
        ]
    }
    
    // 根据搜索文本和排序方法筛选和排序关键词
    var filteredAndSortedKeywords: [KeywordItem] {
        var result = keywords
        
        // 应用搜索过滤
        if !searchText.isEmpty {
            result = result.filter { keyword in
                keyword.name.localizedCaseInsensitiveContains(searchText) ||
                keyword.englishName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 应用排序
        switch sortMethod {
        case .frequency:
            result.sort { $0.frequency > $1.frequency }
        case .alphabetical:
            result.sort { $0.name < $1.name }
        case .relevance:
            // 这里可以实现更复杂的相关性排序逻辑
            // 简单起见，暂时还是按频率排序
            result.sort { $0.frequency > $1.frequency }
        }
        
        return result
    }
}

struct KeywordsAnalysisView: View {
    let paper: Paper
    let pdfService: PDFService
    
    @StateObject private var viewModel = KeywordsAnalysisViewModel()
    @State private var showingFullPDF = false
    
    var body: some View {
        VStack(spacing: 0) {
            // PDF预览区域(缩小版)
            VStack {
                HStack {
                    Text(paper.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: {
                        showingFullPDF.toggle()
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                // 论文内容示意，显示选中关键词的上下文
                if let selectedKeyword = viewModel.selectedKeyword,
                   let firstOccurrence = selectedKeyword.occurrences.first {
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("在第\(firstOccurrence.pageNumber)页找到")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            highlightKeyword(in: firstOccurrence.context, keyword: selectedKeyword.name)
                                .font(.footnote)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .frame(height: UIScreen.main.bounds.height * 0.3)
            .background(Color(.systemGroupedBackground))
            
            // 关键词展示区域
            VStack(spacing: 0) {
                // 关键词列表和详情的容器
                HStack(spacing: 0) {
                    // 左侧关键词列表
                    VStack(spacing: 0) {
                        // 搜索栏
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("搜索关键词", text: $viewModel.searchText)
                                .font(.subheadline)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .padding(8)
                        
                        // 排序选项
                        HStack {
                            Text("排序方式:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("排序", selection: $viewModel.sortMethod) {
                                ForEach(KeywordsAnalysisViewModel.SortMethod.allCases, id: \.self) { method in
                                    Text(method.rawValue).tag(method)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .font(.caption)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(Color(.systemGroupedBackground))
                        
                        // 关键词列表
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.filteredAndSortedKeywords) { keyword in
                                    KeywordRow(
                                        keyword: keyword,
                                        isSelected: viewModel.selectedKeyword?.id == keyword.id,
                                        action: {
                                            viewModel.selectedKeyword = keyword
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.4)
                    .background(Color(.systemBackground))
                    
                    // 右侧关键词详情
                    VStack {
                        if let selectedKeyword = viewModel.selectedKeyword {
                            KeywordDetailView(keyword: selectedKeyword)
                        } else {
                            Text("请选择一个关键词")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                }
            }
            .frame(maxHeight: .infinity)
        }
        .onAppear {
            viewModel.loadKeywords(for: paper, pdfService: pdfService)
        }
        .fullScreenCover(isPresented: $showingFullPDF) {
            PDFReaderView(paper: paper)
        }
    }
    
    private func highlightKeyword(in text: String, keyword: String) -> Text {
        guard !keyword.isEmpty else { return Text(text) }
        
        let parts = text.components(separatedBy: keyword)
        
        if parts.count <= 1 {
            return Text(text)
        }
        
        var result = Text("")
        
        for (index, part) in parts.enumerated() {
            result = result + Text(part)
            
            if index < parts.count - 1 {
                result = result + Text(keyword)
                    .foregroundColor(.blue)
                    .bold()
            }
        }
        
        return result
    }
}

struct KeywordRow: View {
    let keyword: KeywordItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(keyword.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .bold : .regular)
                        .foregroundColor(isSelected ? .blue : .primary)
                    
                    Text(keyword.englishName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(keyword.frequency)次")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            Divider()
                .padding(.leading),
            alignment: .bottom
        )
    }
}

struct KeywordDetailView: View {
    let keyword: KeywordItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(keyword.name)
                    .font(.headline)
                
                Spacer()
                
                Text("出现\(keyword.frequency)次")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Text(keyword.englishName)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Divider()
            
            Text("在文章中的出现位置")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(keyword.occurrences) { occurrence in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("第\(occurrence.pageNumber)页")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                            
                            Text(occurrence.context)
                                .font(.footnote)
                                .lineLimit(4)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
        }
    }
}

struct KeywordsAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        KeywordsAnalysisView(
            paper: Paper.example,
            pdfService: PDFService()
        )
    }
} 