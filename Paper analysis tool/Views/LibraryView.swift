//
//  LibraryView.swift
//  Paper analysis tool
//
//  Created by 金倩如AI on 2023/4/1.
//

import SwiftUI

extension Sequence where Element: Identifiable {
    func unique(by keyPath: KeyPath<Element, Element.ID>) -> [Element] {
        var seen = Set<Element.ID>()
        return filter { element in
            let id = element[keyPath: keyPath]
            if seen.contains(id) {
                return false
            } else {
                seen.insert(id)
                return true
            }
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var userSettings: UserSettings
    
    @State private var searchText = ""
    @State private var showingAddPaperSheet = false
    @State private var showingEditPaperSheet = false
    @State private var editedPaper: Paper? = nil
    @State private var showingDeleteAlert = false
    @State private var paperToDelete: Paper?
    @State private var showingImportPicker = false
    @State private var showingSortOptions = false
    @State private var sortOption: SortOption = .dateAdded
    @State private var sortOrder: SortOrder = .descending
    @State private var selectedCategory: Category?
    @State private var selectedFilterTag: Tag?
    @State private var showingFilterOptions = false
    @State private var newTag = ""

    enum SortOption: String, CaseIterable, Identifiable {
        case title = "标题"
        case author = "作者"
        case dateAdded = "添加日期"
        case publicationDate = "发表日期"
        case journal = "期刊"
        
        var id: String { self.rawValue }
    }
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case ascending = "升序"
        case descending = "降序"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack {
            // 搜索栏
            SearchBar(text: $searchText, placeholder: "搜索论文...")
                .padding(.horizontal)
            
            // 过滤和排序选项
            HStack {
                Button(action: {
                    showingFilterOptions.toggle()
                }) {
                    Label("过滤", systemImage: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.blue)
                }
                .popover(isPresented: $showingFilterOptions) {
                    filterOptionsView
                }
                
                Spacer()
                
                Button(action: {
                    showingSortOptions.toggle()
                }) {
                    Label("排序", systemImage: "arrow.up.arrow.down.circle")
                        .foregroundColor(.blue)
                }
                .popover(isPresented: $showingSortOptions) {
                    sortOptionsView
                }
            }
            .padding(.horizontal)
            
            // 过滤标签显示
            if selectedCategory != nil || selectedFilterTag != nil {
                HStack {
                    if let category = selectedCategory {
                        HStack {
                            Text(category.name)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                            
                            Button(action: {
                                selectedCategory = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    if let tag = selectedFilterTag {
                        HStack {
                            Text(tag.name)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tag.color.color.opacity(0.2))
                                .cornerRadius(8)
                            
                            Button(action: {
                                selectedFilterTag = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button("清除全部") {
                        selectedCategory = nil
                        selectedFilterTag = nil
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
            
            // 论文列表
            List {
                ForEach(filteredAndSortedPapers) { paper in
                    PaperCardView(paper: paper)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 导航到论文详情
                        }
                        .contextMenu {
                            Button(action: {
                                editedPaper = paper
                                showingEditPaperSheet = true
                            }) {
                                Label("编辑", systemImage: "pencil")
                            }
                            
                            Button(action: {
                                dataStore.updatePaper(Paper(
                                    id: paper.id,
                                    title: paper.title,
                                    authors: paper.authors,
                                    publicationDate: paper.publicationDate,
                                    journal: paper.journal,
                                    abstract: paper.abstract,
                                    keywords: paper.keywords,
                                    doi: paper.doi,
                                    fileURL: paper.fileURL,
                                    dateAdded: paper.dateAdded,
                                    lastOpened: paper.lastOpened,
                                    tags: paper.tags,
                                    categories: paper.categories,
                                    isFavorite: !paper.isFavorite,
                                    readingProgress: paper.readingProgress,
                                    notes: paper.notes,
                                    readStatus: paper.readStatus,
                                    userRating: paper.userRating
                                ))
                            }) {
                                Label(paper.isFavorite ? "取消收藏" : "收藏", 
                                      systemImage: paper.isFavorite ? "star.slash" : "star")
                            }
                            
                            Button(role: .destructive, action: {
                                paperToDelete = paper
                                showingDeleteAlert = true
                            }) {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(PlainListStyle())
            
            // 添加论文按钮
            Button(action: {
                showingAddPaperSheet = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)
                    .shadow(radius: 2)
            }
            .padding()
        }
        .sheet(isPresented: $showingAddPaperSheet) {
            NavigationView {
                addPaperView
                    .navigationTitle("添加论文")
                    .navigationBarItems(
                        leading: Button("取消") {
                            showingAddPaperSheet = false
                        },
                        trailing: Button("完成") {
                            showingAddPaperSheet = false
                        }
                    )
            }
        }
        .sheet(isPresented: $showingEditPaperSheet) {
            if let paper = editedPaper {
                NavigationView {
                    editPaperView(paper: paper)
                        .navigationTitle("编辑论文")
                        .navigationBarItems(
                            leading: Button("取消") {
                                showingEditPaperSheet = false
                                editedPaper = nil
                            },
                            trailing: Button("保存") {
                                if let edited = editedPaper {
                                    dataStore.updatePaper(edited)
                                }
                                showingEditPaperSheet = false
                                editedPaper = nil
                            }
                        )
                }
            }
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let paper = paperToDelete {
                    dataStore.deletePaper(paper.id)
                    paperToDelete = nil
                }
            }
        } message: {
            if let paper = paperToDelete {
                Text("确定要删除论文 '\(paper.title)' 吗？此操作不能撤销。")
            } else {
                Text("确定要删除这篇论文吗？此操作不能撤销。")
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.pdf, .plainText, .rtf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // 处理导入的文件
                    importPaper(from: url)
                }
            case .failure(let error):
                print("文件导入失败: \(error)")
            }
        }
    }
    
    // 过滤和排序后的论文列表
    private var filteredAndSortedPapers: [Paper] {
        var papers = dataStore.papers
        
        // 应用类别过滤
        if let category = selectedCategory {
            papers = papers.filter { $0.categories.contains(where: { $0.id == category.id }) }
        }
        
        // 应用标签过滤
        if let tag = selectedFilterTag {
            papers = papers.filter { $0.tags.contains(where: { $0.id == tag.id }) }
        }
        
        // 应用搜索过滤
        if !searchText.isEmpty {
            papers = papers.filter { paper in
                paper.title.localizedCaseInsensitiveContains(searchText) ||
                paper.authors.joined(separator: ", ").localizedCaseInsensitiveContains(searchText) ||
                paper.abstract.localizedCaseInsensitiveContains(searchText) ||
                paper.keywords.joined(separator: ", ").localizedCaseInsensitiveContains(searchText) ||
                paper.tags.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) })
            }
        }
        
        // 应用排序
        return papers.sorted { first, second in
            let result: Bool
            
            switch sortOption {
            case .title:
                result = first.title < second.title
            case .author:
                let firstAuthor = first.authors.first ?? ""
                let secondAuthor = second.authors.first ?? ""
                result = firstAuthor < secondAuthor
            case .dateAdded:
                result = first.dateAdded < second.dateAdded
            case .publicationDate:
                guard let firstDate = first.publicationDate, let secondDate = second.publicationDate else {
                    return false
                }
                result = firstDate < secondDate
            case .journal:
                result = (first.journal ?? "") < (second.journal ?? "")
            }
            
            return sortOrder == .ascending ? result : !result
        }
    }
    
    // 排序选项视图
    private var sortOptionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("排序方式")
                .font(.headline)
                .padding(.bottom, 5)
            
            ForEach(SortOption.allCases) { option in
                Button(action: {
                    if sortOption == option {
                        // 如果点击当前排序选项，则切换升/降序
                        sortOrder = sortOrder == .ascending ? .descending : .ascending
                    } else {
                        sortOption = option
                    }
                }) {
                    HStack {
                        Text(option.rawValue)
                        Spacer()
                        if sortOption == option {
                            Image(systemName: sortOrder == .ascending ? "arrow.up" : "arrow.down")
                        }
                    }
                    .foregroundColor(sortOption == option ? .blue : .primary)
                    .padding(.vertical, 5)
                }
            }
            
            Divider()
            
            Text("排序顺序")
                .font(.headline)
                .padding(.vertical, 5)
            
            ForEach(SortOrder.allCases) { order in
                Button(action: {
                    sortOrder = order
                }) {
                    HStack {
                        Text(order.rawValue)
                        Spacer()
                        if sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                    .foregroundColor(sortOrder == order ? .blue : .primary)
                    .padding(.vertical, 5)
                }
            }
        }
        .padding()
        .frame(width: 250)
    }
    
    // 过滤选项视图
    private var filterOptionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("按类别筛选")
                .font(.headline)
                .padding(.bottom, 5)
            
            let categories = dataStore.papers.flatMap { $0.categories }.unique(by: \.id)
            ForEach(categories, id: \.id) { category in
                Button(action: {
                    selectedCategory = selectedCategory?.id == category.id ? nil : category
                    showingFilterOptions = false
                }) {
                    HStack {
                        Text(category.name)
                        Spacer()
                        if selectedCategory?.id == category.id {
                            Image(systemName: "checkmark")
                        }
                    }
                    .foregroundColor(selectedCategory?.id == category.id ? .blue : .primary)
                    .padding(.vertical, 5)
                }
            }
            
            if categories.isEmpty {
                Text("无类别")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 5)
            }
            
            Divider()
            
            Text("按标签筛选")
                .font(.headline)
                .padding(.vertical, 5)
            
            ForEach(dataStore.tags, id: \.id) { tag in
                Button(action: {
                    selectedFilterTag = selectedFilterTag?.id == tag.id ? nil : tag
                    showingFilterOptions = false
                }) {
                    HStack {
                        Text(tag.name)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(tag.color.color.opacity(0.2))
                            .cornerRadius(5)
                        Spacer()
                        if selectedFilterTag?.id == tag.id {
                            Image(systemName: "checkmark")
                        }
                    }
                    .foregroundColor(selectedFilterTag?.id == tag.id ? .blue : .primary)
                    .padding(.vertical, 5)
                }
            }
            
            if dataStore.tags.isEmpty {
                Text("无标签")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 5)
            }
        }
        .padding()
        .frame(width: 250)
    }
    
    // 添加论文视图
    private var addPaperView: some View {
        VStack {
            List {
                Section {
                    Button(action: {
                        // 显示文件导入对话框
                        showingImportPicker = true
                        showingAddPaperSheet = false
                    }) {
                        Label("导入PDF文件", systemImage: "doc.fill")
                    }
                    
                    Button(action: {
                        // 创建新的空论文并进入编辑模式
                        let newPaper = Paper.empty
                        dataStore.addPaper(newPaper)
                        editedPaper = newPaper
                        showingAddPaperSheet = false
                        showingEditPaperSheet = true
                    }) {
                        Label("手动创建", systemImage: "pencil")
                    }
                } header: {
                    Text("添加方式")
                }
            }
        }
    }
    
    // 编辑论文视图
    private func editPaperView(paper: Paper) -> some View {
        Form {
            Section {
                TextField("标题", text: Binding(
                    get: { self.editedPaper?.title ?? paper.title },
                    set: { self.editedPaper?.title = $0 }
                ))
                
                authorsSection
                
                TextField("期刊/会议", text: Binding(
                    get: { self.editedPaper?.journal ?? paper.journal ?? "" },
                    set: { self.editedPaper?.journal = $0 }
                ))
                
                DatePicker("发表日期", selection: Binding(
                    get: { self.editedPaper?.publicationDate ?? paper.publicationDate ?? Date() },
                    set: { self.editedPaper?.publicationDate = $0 }
                ), displayedComponents: .date)
                
                TextField("DOI", text: Binding(
                    get: { self.editedPaper?.doi ?? paper.doi ?? "" },
                    set: { self.editedPaper?.doi = $0 }
                ))
            } header: {
                Text("论文信息")
            }
            
            Section {
                TextEditor(text: Binding(
                    get: { self.editedPaper?.abstract ?? paper.abstract },
                    set: { self.editedPaper?.abstract = $0 }
                ))
                .frame(minHeight: 100)
            } header: {
                Text("摘要")
            }
            
            keywordsSection
            
            tagsSection
            
            readingStatusSection
            
            ratingSection
        }
    }
    
    // 作者部分
    private var authorsSection: some View {
        Section {
            if let paper = editedPaper {
                ForEach(paper.authors.indices, id: \.self) { index in
                    HStack {
                        TextField("作者 \(index + 1)", text: Binding(
                            get: { paper.authors[index] },
                            set: { newValue in
                                var updatedPaper = paper
                                updatedPaper.authors[index] = newValue
                                editedPaper = updatedPaper
                            }
                        ))
                        
                        Button(action: {
                            if paper.authors.count > 1 {
                                var updatedPaper = paper
                                updatedPaper.authors.remove(at: index)
                                editedPaper = updatedPaper
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .disabled(paper.authors.count <= 1)
                    }
                }
                
                Button(action: {
                    var updatedPaper = paper
                    updatedPaper.authors.append("")
                    editedPaper = updatedPaper
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("添加作者")
                    }
                }
            }
        } header: {
            Text("作者")
        }
    }
    
    // 关键词部分
    private var keywordsSection: some View {
        Section {
            if let paper = editedPaper {
                ForEach(paper.keywords.indices, id: \.self) { index in
                    HStack {
                        TextField("关键词 \(index + 1)", text: Binding(
                            get: { paper.keywords[index] },
                            set: { newValue in
                                var updatedPaper = paper
                                updatedPaper.keywords[index] = newValue
                                editedPaper = updatedPaper
                            }
                        ))
                        
                        Button(action: {
                            if paper.keywords.count > 1 {
                                var updatedPaper = paper
                                updatedPaper.keywords.remove(at: index)
                                editedPaper = updatedPaper
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .disabled(paper.keywords.count <= 1)
                    }
                }
                
                Button(action: {
                    var updatedPaper = paper
                    updatedPaper.keywords.append("")
                    editedPaper = updatedPaper
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("添加关键词")
                    }
                }
            }
        } header: {
            Text("关键词")
        }
    }
    
    // 标签部分
    private var tagsSection: some View {
        Section {
            // 已添加的标签
            if let paper = editedPaper {
                ForEach(paper.tags) { tag in
                    HStack {
                        Text(tag.name)
                        Spacer()
                        Button(action: {
                            var updatedPaper = paper
                            updatedPaper.tags.removeAll { $0.id == tag.id }
                            editedPaper = updatedPaper
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // 添加标签
                HStack {
                    TextField("新标签", text: $newTag)
                    
                    Button(action: {
                        if !newTag.isEmpty && !paper.tags.contains(where: { $0.name == newTag }) {
                            let newTagObject = Tag(name: newTag, color: .blue)
                            var updatedPaper = paper
                            updatedPaper.tags.append(newTagObject)
                            editedPaper = updatedPaper
                            newTag = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .disabled(newTag.isEmpty)
                }
                
                // 已有标签选择
                let allTags = dataStore.papers.flatMap { $0.tags }.unique(by: \.id)
                if !allTags.isEmpty {
                    Picker("选择已有标签", selection: $newTag) {
                        Text("选择标签").tag("")
                        ForEach(allTags.filter { tag in
                            !paper.tags.contains(where: { $0.id == tag.id })
                        }) { tag in
                            Text(tag.name).tag(tag.name)
                        }
                    }
                    .onChange(of: newTag) { value in
                        if !value.isEmpty {
                            if let selectedTag = allTags.first(where: { $0.name == value }) {
                                if !paper.tags.contains(where: { $0.id == selectedTag.id }) {
                                    var updatedPaper = paper
                                    updatedPaper.tags.append(selectedTag)
                                    editedPaper = updatedPaper
                                }
                            }
                            newTag = ""
                        }
                    }
                }
            }
        } header: {
            Text("标签")
        }
    }
    
    // 阅读状态部分
    private var readingStatusSection: some View {
        Section {
            if let paper = editedPaper {
                Picker("阅读状态", selection: Binding(
                    get: { paper.readStatus },
                    set: { newValue in
                        var updatedPaper = paper
                        updatedPaper.readStatus = newValue
                        editedPaper = updatedPaper
                    }
                )) {
                    ForEach(Paper.ReadStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        } header: {
            Text("阅读状态")
        }
    }
    
    // 评分部分
    private var ratingSection: some View {
        Section {
            if let paper = editedPaper {
                HStack {
                    ForEach(1...5, id: \.self) { rating in
                        Image(systemName: (paper.userRating ?? 0) >= rating ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .onTapGesture {
                                var updatedPaper = paper
                                updatedPaper.userRating = rating
                                editedPaper = updatedPaper
                            }
                    }
                    
                    if paper.userRating != nil {
                        Button(action: {
                            var updatedPaper = paper
                            updatedPaper.userRating = nil
                            editedPaper = updatedPaper
                        }) {
                            Text("清除")
                                .foregroundColor(.blue)
                                .padding(.leading)
                        }
                    }
                }
            }
        } header: {
            Text("评分")
        }
    }
    
    // 导入论文的方法
    private func importPaper(from url: URL) {
        // 实现论文导入逻辑
    }
}

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .padding(.vertical, 8)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// 预览提供者
struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LibraryView()
                .environmentObject(DataStore())
                .environmentObject(UserSettings())
        }
    }
}