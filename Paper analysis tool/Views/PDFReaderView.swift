import SwiftUI
import PDFKit
import Combine

struct PDFReaderView: View {
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var pdfService = PDFService()
    
    let paper: Paper
    
    @State private var showingAnnotationOptions = false
    @State private var showingTableOfContents = false
    @State private var currentPage = 0
    @State private var totalPages = 0
    @State private var zoomScale: CGFloat = 1.0
    @State private var showingNoteEditor = false
    @State private var selectedText = ""
    @State private var currentHighlightColor: HighlightColor = .yellow
    @State private var newNote = ""
    @State private var currentSearchResult: PDFSelection? = nil
    @State private var currentHighlights: [TextHighlight] = []
    @State private var showingCodeSnippets = false
    @State private var showingKeywordsAnalysis = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // 顶部工具栏
                    topToolbar
                    
                    // 主视图区域
                    HStack(spacing: 0) {
                        // 侧边栏（当显示目录时）
                        if showingTableOfContents {
                            tableOfContentsView
                                .frame(width: 250)
                                .background(Color(.systemBackground))
                                .shadow(radius: 2)
                        }
                        
                        // PDF显示区域
                        pdfView
                            .overlay(
                                bottomControls
                                    .padding(.bottom, 20),
                                alignment: .bottom
                            )
                    }
                }
                
                // 注释选项悬浮菜单
                if showingAnnotationOptions {
                    annotationOptionsView
                }
                
                // 笔记编辑器
                if showingNoteEditor {
                    noteEditorView
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadPDF()
                // 加载已有的高亮
                currentHighlights = paper.highlights ?? []
            }
            .onChange(of: selectedText) { _, newValue in
                if !newValue.isEmpty {
                    showingAnnotationOptions = true
                }
            }
            .sheet(isPresented: $showingCodeSnippets) {
                NavigationView {
                    CodeSnippetView(paper: paper)
                        .environmentObject(dataStore)
                        .navigationTitle("代码片段")
                        .navigationBarItems(trailing: Button("完成") {
                            showingCodeSnippets = false
                        })
                }
            }
            .sheet(isPresented: $showingKeywordsAnalysis) {
                NavigationView {
                    KeywordsAnalysisView(paper: paper, pdfService: pdfService)
                        .environmentObject(dataStore)
                        .navigationTitle("关键词分析")
                        .navigationBarItems(trailing: Button("完成") {
                            showingKeywordsAnalysis = false
                        })
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // 顶部工具栏
    private var topToolbar: some View {
        HStack {
            Button(action: {
                // 返回上一页
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22))
            }
            .padding(.horizontal)
            
            Button(action: {
                showingTableOfContents.toggle()
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 22))
            }
            .padding(.horizontal)
            
            Spacer()
            
            Text(paper.title)
                .font(.headline)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: {
                // 搜索功能
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22))
            }
            .padding(.horizontal)
            
            Button(action: {
                showingAnnotationOptions.toggle()
            }) {
                Image(systemName: "highlighter")
                    .font(.system(size: 22))
            }
            .padding(.horizontal)
            
            Button(action: {
                showingCodeSnippets = true
            }) {
                Image(systemName: "text.code")
                    .font(.system(size: 22))
            }
            .padding(.horizontal)
            
            Button(action: {
                showingKeywordsAnalysis = true
            }) {
                Image(systemName: "tag")
                    .font(.system(size: 22))
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }
    
    // PDF视图
    private var pdfView: some View {
        PDFKitView(
            pdfService: pdfService,
            currentPage: $currentPage,
            totalPages: $totalPages,
            zoomScale: $zoomScale,
            selectedText: $selectedText,
            highlights: currentHighlights
        )
    }
    
    // 底部控制区
    private var bottomControls: some View {
        HStack {
            Button(action: {
                previousPage()
            }) {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text("\(currentPage + 1) / \(totalPages)")
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(.systemBackground).opacity(0.8))
                .cornerRadius(20)
            
            Spacer()
            
            Button(action: {
                nextPage()
            }) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 30)
    }
    
    // 目录视图
    private var tableOfContentsView: some View {
        VStack(alignment: .leading) {
            Text("目录")
                .font(.headline)
                .padding()
            
            List {
                let sections = pdfService.identifySections()
                if !sections.isEmpty {
                    ForEach(sections) { section in
                        Button(action: {
                            goToPage(section.pageNumber - 1)
                            showingTableOfContents = false
                        }) {
                            HStack {
                                Text(section.title)
                                    .font(.system(size: 14))
                                
                                Spacer()
                                
                                Text("第\(section.pageNumber)页")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else {
                    Text("未找到章节")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            
            Spacer()
            
            Button(action: {
                showingTableOfContents = false
            }) {
                Text("关闭")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            .padding(.bottom)
        }
    }
    
    // 注释选项视图
    private var annotationOptionsView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 15) {
                Text("高亮颜色：")
                    .font(.subheadline)
                
                ForEach(HighlightColor.allCases, id: \.self) { color in
                    Circle()
                        .fill(color.color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: currentHighlightColor == color ? 2 : 0)
                        )
                        .onTapGesture {
                            currentHighlightColor = color
                        }
                }
            }
            
            HStack(spacing: 15) {
                Button(action: {
                    if !selectedText.isEmpty {
                        addHighlight(color: currentHighlightColor)
                        showingAnnotationOptions = false
                    }
                }) {
                    Text("添加高亮")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(selectedText.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(selectedText.isEmpty)
                
                Button(action: {
                    if !selectedText.isEmpty {
                        showingNoteEditor = true
                        showingAnnotationOptions = false
                    }
                }) {
                    Text("添加笔记")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(selectedText.isEmpty ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(selectedText.isEmpty)
            }
            
            Button(action: {
                showingAnnotationOptions = false
            }) {
                Text("取消")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .frame(width: 300)
        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
    }
    
    // 笔记编辑器视图
    private var noteEditorView: some View {
        VStack(spacing: 15) {
            Text("添加笔记")
                .font(.headline)
            
            Text("已选择文本: \"\(selectedText)\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.horizontal)
            
            TextEditor(text: $newNote)
                .frame(height: 150)
                .border(Color.gray.opacity(0.2))
                .padding(.horizontal)
            
            HStack {
                Button(action: {
                    showingNoteEditor = false
                    newNote = ""
                }) {
                    Text("取消")
                        .frame(width: 100)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: {
                    addNote()
                    showingNoteEditor = false
                    newNote = ""
                }) {
                    Text("保存")
                        .frame(width: 100)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .frame(width: 350)
        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
    }
    
    // 加载PDF
    private func loadPDF() {
        if let fileURL = paper.fileURL {
            let success = pdfService.loadDocument(from: fileURL)
            if success {
                totalPages = pdfService.pageCount
                
                // 更新论文的阅读进度
                var updatedPaper = paper
                if updatedPaper.readingProgress == nil {
                    updatedPaper.readingProgress = ReadingProgress()
                }
                updatedPaper.lastOpened = Date()
                dataStore.updatePaper(updatedPaper)
            }
        }
    }
    
    // 页面导航方法
    private func nextPage() {
        if currentPage < totalPages - 1 {
            currentPage += 1
            updateReadingProgress()
        }
    }
    
    private func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
            updateReadingProgress()
        }
    }
    
    private func goToPage(_ page: Int) {
        if page >= 0 && page < totalPages {
            currentPage = page
            updateReadingProgress()
        }
    }
    
    // 更新阅读进度
    private func updateReadingProgress() {
        var updatedPaper = paper
        if updatedPaper.readingProgress == nil {
            updatedPaper.readingProgress = ReadingProgress()
        }
        updatedPaper.readingProgress?.currentPage = currentPage
        updatedPaper.readingProgress?.totalPages = totalPages
        updatedPaper.readingProgress?.lastReadTime = Date()
        dataStore.updatePaper(updatedPaper)
    }
    
    // 添加高亮
    private func addHighlight(color: HighlightColor) {
        guard !selectedText.isEmpty, currentPage < totalPages else { return }
        
        var updatedPaper = paper
        
        // 获取当前页面和选区
        if let pdfPage = pdfService.page(at: currentPage),
           let selection = pdfService.findText(selectedText, on: currentPage) {
            
            // 获取选区的范围
            var range = NSRange(location: 0, length: 0)
            if selection.string!.isEmpty {
                // 空选区，使用默认值
            } else if let selectionByLine = selection.selectionsByLine().first {
                let pageContent = pdfPage.string ?? ""
                let searchText = selectionByLine.string ?? ""
                if let textRange = pageContent.range(of: searchText) {
                    let location = pageContent.distance(from: pageContent.startIndex, to: textRange.lowerBound)
                    let length = searchText.count
                    range = NSRange(location: location, length: length)
                }
            }
            
            // 创建高亮位置信息
            let position = HighlightPosition(
                pageIndex: currentPage,
                startIndex: range.location,
                length: range.length
            )
            
            let highlight = TextHighlight(
                text: selectedText,
                color: color,
                pageNumber: currentPage + 1,
                date: Date(),
                position: position
            )
            
            if updatedPaper.highlights == nil {
                updatedPaper.highlights = []
            }
            updatedPaper.highlights?.append(highlight)
            dataStore.updatePaper(updatedPaper)
            
            // 更新当前视图的高亮列表
            currentHighlights = updatedPaper.highlights ?? []
            
            // 清除选择
            selectedText = ""
        }
    }
    
    // 添加笔记
    private func addNote() {
        guard !selectedText.isEmpty && !newNote.isEmpty else { return }
        
        var updatedPaper = paper
        let note = Note(
            id: UUID(),
            content: newNote,
            timestamp: Date(),
            pageNumber: currentPage + 1,
            tags: [],
            highlightColor: currentHighlightColor,
            relatedText: selectedText,
            paperId: paper.id
        )
        
        if updatedPaper.notes == nil {
            updatedPaper.notes = []
        }
        updatedPaper.notes?.append(note)
        dataStore.updatePaper(updatedPaper)
    }
}

// PDFKit封装视图
struct PDFKitView: UIViewRepresentable {
    let pdfService: PDFService
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var zoomScale: CGFloat
    @Binding var selectedText: String
    var highlights: [TextHighlight] = []
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = pdfService.document
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true)
        pdfView.delegate = context.coordinator
        
        // 添加手势识别
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        pdfView.addGestureRecognizer(tapGesture)
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // 更新当前页面
        if let page = pdfService.page(at: currentPage) {
            pdfView.go(to: page)
        }
        
        // 更新缩放级别
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit * zoomScale
        
        // 显示高亮
        applyHighlights(to: pdfView)
    }
    
    private func applyHighlights(to pdfView: PDFView) {
        // 清除现有高亮
        pdfView.clearHighlights()
        
        // 对当前页面应用高亮
        let currentPageHighlights = highlights.filter { $0.pageNumber - 1 == currentPage }
        
        for highlight in currentPageHighlights {
            if let position = highlight.position,
               let page = pdfView.document?.page(at: position.pageIndex) {
                
                // 创建选择区域
                let selection = PDFSelection(document: pdfView.document!)
                
                // 使用NSRange创建区域
                let range = NSRange(location: position.startIndex, length: position.length)
                if let pageSelection = page.selection(for: range) {
                    selection.add(pageSelection)
                }
                
                // 设置高亮颜色
                let uiColor = UIColor(highlight.color.color)
                selection.color = uiColor.withAlphaComponent(0.3)
                
                // 添加高亮
                pdfView.highlightSelection(selection, withColor: selection.color)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitView
        
        init(_ parent: PDFKitView) {
            self.parent = parent
        }
        
        func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
            // 处理PDF中的链接点击
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else { return }
            
            // 清除当前选择
            if self.parent.selectedText.isEmpty {
                pdfView.clearSelection()
            }
        }
        
        func pdfViewDidChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView, 
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            
            // 更新当前页码
            let pageIndex = document.index(for: currentPage)
            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex
            }
            
            // 获取选中的文本
            if let selection = pdfView.currentSelection,
               let selectedText = selection.string {
                DispatchQueue.main.async {
                    self.parent.selectedText = selectedText
                }
            }
        }
    }
}

// 扩展PDFView以支持高亮管理
extension PDFView {
    // 清除所有高亮
    func clearHighlights() {
        clearSelection()
        removeAnnotations()
    }
    
    // 高亮选择区域
    func highlightSelection(_ selection: PDFSelection, withColor color: UIColor?) {
        selection.color = color
        if let document = self.document {
            for i in 0..<document.pageCount {
                if let page = document.page(at: i) {
                    // 检查选择区域是否包含当前页面
                    for selection in selection.selectionsByLine() {
                        if selection.pages.contains(page) {
                            // 创建高亮注释
                            let bounds = selection.bounds(for: page)
                            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                            annotation.color = color ?? UIColor.yellow
                            page.addAnnotation(annotation)
                        }
                    }
                }
            }
        }
    }
    
    // 删除注释
    func removeAnnotations() {
        guard let document = self.document else { return }
        
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            
            let annotations = page.annotations
            for annotation in annotations {
                page.removeAnnotation(annotation)
            }
        }
    }
}

// 预览
struct PDFReaderView_Previews: PreviewProvider {
    static var previews: some View {
        let dummyPaper = Paper(
            title: "示例论文",
            authors: ["作者1", "作者2"],
            abstract: "这是一篇示例论文的摘要..."
        )
        
        return PDFReaderView(paper: dummyPaper)
            .environmentObject(DataStore())
    }
} 