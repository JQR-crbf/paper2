import SwiftUI

struct CodeSnippetView: View {
    let paper: Paper
    @EnvironmentObject var dataStore: DataStore
    @State private var snippets: [CodeSnippet] = []
    @State private var showingAddSnippet = false
    @State private var editingSnippet: CodeSnippet?
    @State private var searchText = ""
    
    // 当前编辑的代码片段内容
    @State private var snippetCode = ""
    @State private var snippetLanguage = "swift"
    @State private var snippetPage = 1
    
    // 支持的编程语言
    let languages = ["swift", "python", "java", "javascript", "c++", "c#", "go", "rust", "ruby", "php"]
    
    var body: some View {
        VStack {
            // 搜索栏
            SearchBar(text: $searchText, placeholder: "搜索代码片段...")
                .padding(.horizontal)
            
            if filteredSnippets.isEmpty {
                EmptyStateView(
                    title: "没有代码片段",
                    message: "点击下方按钮添加论文中的代码片段",
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    buttonTitle: "添加代码片段"
                ) {
                    prepareForNewSnippet()
                }
            } else {
                // 代码片段列表
                List {
                    ForEach(filteredSnippets) { snippet in
                        CodeSnippetRow(snippet: snippet)
                            .contextMenu {
                                Button(action: {
                                    editSnippet(snippet)
                                }) {
                                    Label("编辑", systemImage: "pencil")
                                }
                                
                                Button(action: {
                                    deleteSnippet(snippet)
                                }) {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            .onTapGesture {
                                editSnippet(snippet)
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            deleteSnippet(filteredSnippets[index])
                        }
                    }
                }
            }
            
            // 添加按钮
            Button(action: {
                prepareForNewSnippet()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加代码片段")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("代码片段管理")
        .sheet(isPresented: $showingAddSnippet) {
            CodeSnippetEditorView(
                code: $snippetCode,
                language: $snippetLanguage,
                page: $snippetPage,
                languages: languages,
                isEditing: editingSnippet != nil,
                onSave: saveSnippet,
                maxPage: paper.readingProgress?.totalPages ?? 100
            )
        }
        .onAppear {
            loadSnippets()
        }
    }
    
    // 过滤后的代码片段
    private var filteredSnippets: [CodeSnippet] {
        if searchText.isEmpty {
            return snippets
        } else {
            return snippets.filter {
                $0.code.localizedCaseInsensitiveContains(searchText) ||
                $0.language.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // 加载此论文的所有代码片段
    private func loadSnippets() {
        snippets = dataStore.codeSnippets.filter { $0.paperId == paper.id }
    }
    
    // 准备添加新代码片段
    private func prepareForNewSnippet() {
        editingSnippet = nil
        snippetCode = ""
        snippetLanguage = "swift"
        snippetPage = paper.readingProgress?.currentPage ?? 1
        showingAddSnippet = true
    }
    
    // 编辑现有代码片段
    private func editSnippet(_ snippet: CodeSnippet) {
        editingSnippet = snippet
        snippetCode = snippet.code
        snippetLanguage = snippet.language
        snippetPage = snippet.pageNumber
        showingAddSnippet = true
    }
    
    // 保存代码片段
    private func saveSnippet() {
        if let snippet = editingSnippet {
            // 更新现有代码片段
            var updatedSnippet = snippet
            updatedSnippet.code = snippetCode
            updatedSnippet.language = snippetLanguage
            updatedSnippet.pageNumber = snippetPage
            
            dataStore.updateCodeSnippet(updatedSnippet)
        } else {
            // 创建新代码片段
            let newSnippet = CodeSnippet(
                code: snippetCode,
                language: snippetLanguage,
                pageNumber: snippetPage,
                paperId: paper.id
            )
            
            dataStore.addCodeSnippet(newSnippet)
        }
        
        // 重新加载代码片段
        loadSnippets()
        showingAddSnippet = false
    }
    
    // 删除代码片段
    private func deleteSnippet(_ snippet: CodeSnippet) {
        dataStore.deleteCodeSnippet(snippet)
        loadSnippets()
    }
}

// 代码片段行组件
struct CodeSnippetRow: View {
    let snippet: CodeSnippet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snippet.language)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(languageColor(snippet.language))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                
                Spacer()
                
                Text("第\(snippet.pageNumber)页")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 代码预览
            Text(snippet.code)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(3)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
    
    // 根据编程语言返回不同颜色
    private func languageColor(_ language: String) -> Color {
        switch language.lowercased() {
        case "swift": return .orange
        case "python": return .blue
        case "java": return .red
        case "javascript": return .yellow
        case "c++", "c#": return .purple
        case "go": return .blue
        case "rust": return .orange
        case "ruby": return .red
        case "php": return .purple
        default: return .gray
        }
    }
}

// 代码片段编辑器
struct CodeSnippetEditorView: View {
    @Binding var code: String
    @Binding var language: String
    @Binding var page: Int
    let languages: [String]
    let isEditing: Bool
    let onSave: () -> Void
    let maxPage: Int
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("编程语言")) {
                    Picker("语言", selection: $language) {
                        ForEach(languages, id: \.self) { lang in
                            Text(lang.capitalized)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("页码")) {
                    Stepper(value: $page, in: 1...maxPage) {
                        Text("第\(page)页")
                    }
                }
                
                Section(header: Text("代码")) {
                    TextEditor(text: $code)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle(isEditing ? "编辑代码片段" : "添加代码片段")
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(code.isEmpty)
            )
        }
    }
}

// 预览
struct CodeSnippetView_Previews: PreviewProvider {
    static var previews: some View {
        let samplePaper = Paper(title: "示例论文", authors: ["作者1", "作者2"])
        
        return NavigationView {
            CodeSnippetView(paper: samplePaper)
                .environmentObject(DataStore())
        }
    }
} 