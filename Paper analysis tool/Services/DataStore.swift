//
//  DataStore.swift
//  Paper analysis tool
//
//  Created by 金倩如AI on 2023/4/1.
//

import Foundation
import Combine

class DataStore: ObservableObject {
    @Published var papers: [Paper] = []
    @Published var notes: [Note] = []
    @Published var tags: [Tag] = []
    @Published var codeSnippets: [CodeSnippet] = []
    @Published var selectedPaper: Paper?
    
    private let papersKey = "savedPapers"
    private let notesKey = "savedNotes"
    private let tagsKey = "savedTags"
    private let codeSnippetsKey = "savedCodeSnippets"
    
    init() {
        loadData()
    }
    
    // MARK: - 论文管理
    
    func addPaper(_ paper: Paper) {
        papers.append(paper)
        
        // 添加新标签
        let newTags = paper.tags.filter { tag in
            !tags.contains(where: { $0.id == tag.id })
        }
        
        if !newTags.isEmpty {
            tags.append(contentsOf: newTags)
            saveTags()
        }
        
        savePapers()
    }
    
    func updatePaper(_ paper: Paper) {
        if let index = papers.firstIndex(where: { $0.id == paper.id }) {
            papers[index] = paper
            savePapers()
            
            // 更新标签
            updateTagsList()
        }
    }
    
    func deletePaper(_ paperId: UUID) {
        // 删除相关笔记
        notes.removeAll { $0.paperId == paperId }
        saveNotes()
        
        // 删除论文
        papers.removeAll { $0.id == paperId }
        savePapers()
        
        // 更新标签
        updateTagsList()
    }
    
    func getPaper(by id: UUID) -> Paper? {
        return papers.first { $0.id == id }
    }
    
    // MARK: - 笔记管理
    
    func addNote(_ note: Note) {
        notes.append(note)
        saveNotes()
        
        // 更新论文的笔记引用
        if var paper = getPaper(by: note.paperId) {
            if paper.notes == nil {
                paper.notes = []
            }
            paper.notes?.append(note)
            updatePaper(paper)
        }
    }
    
    func updateNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            saveNotes()
            
            // 同时更新论文中的笔记
            if var paper = getPaper(by: note.paperId) {
                if let paperNotes = paper.notes,
                   let noteIndex = paperNotes.firstIndex(where: { $0.id == note.id }) {
                    paper.notes?[noteIndex] = note
                    updatePaper(paper)
                }
            }
        }
    }
    
    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        saveNotes()
        
        // 更新论文的笔记引用
        if var paper = getPaper(by: note.paperId) {
            if paper.notes != nil {
                paper.notes?.removeAll(where: { $0.id == note.id })
            }
            updatePaper(paper)
        }
    }
    
    func notesForPaper(_ paperId: UUID) -> [Note] {
        return notes.filter { $0.paperId == paperId }
    }
    
    // MARK: - 标签管理
    
    func addTag(_ tag: Tag) {
        if !tags.contains(where: { $0.id == tag.id }) {
            tags.append(tag)
            saveTags()
        }
    }
    
    func updateTag(_ tag: Tag) {
        if let index = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[index] = tag
            saveTags()
            
            // 更新所有使用此标签的论文
            for var paper in papers {
                if let tagIndex = paper.tags.firstIndex(where: { $0.id == tag.id }) {
                    paper.tags[tagIndex] = tag
                    updatePaper(paper)
                }
            }
        }
    }
    
    func deleteTag(_ tag: Tag) {
        // 从标签列表中删除
        tags.removeAll { $0.id == tag.id }
        saveTags()
        
        // 从所有论文中删除此标签
        for var paper in papers {
            paper.tags.removeAll { $0.id == tag.id }
            updatePaper(paper)
        }
    }
    
    func deleteTags(_ tagsToDelete: [Tag]) {
        // 批量删除标签
        for tag in tagsToDelete {
            deleteTag(tag)
        }
    }
    
    func findTag(by id: UUID) -> Tag? {
        return tags.first { $0.id == id }
    }
    
    func findTags(by ids: [UUID]) -> [Tag] {
        return tags.filter { ids.contains($0.id) }
    }
    
    private func updateTagsList() {
        // 收集所有论文中的所有标签
        var allTags = Set<Tag>()
        for paper in papers {
            for tag in paper.tags {
                allTags.insert(tag)
            }
        }
        
        // 更新或创建标签
        var updatedTags: [Tag] = []
        
        for tag in allTags {
            // 计算使用此标签的论文数量
            let count = papers.filter { $0.tags.contains(where: { $0.id == tag.id }) }.count
            
            var updatedTag = tag
            updatedTag.count = count
            updatedTags.append(updatedTag)
        }
        
        // 更新标签列表
        tags = updatedTags.sorted { $0.name < $1.name }
        saveTags()
    }
    
    // MARK: - 代码片段管理
    
    func addCodeSnippet(_ snippet: CodeSnippet) {
        codeSnippets.append(snippet)
        saveCodeSnippets()
    }
    
    func updateCodeSnippet(_ snippet: CodeSnippet) {
        if let index = codeSnippets.firstIndex(where: { $0.id == snippet.id }) {
            codeSnippets[index] = snippet
            saveCodeSnippets()
        }
    }
    
    func deleteCodeSnippet(_ snippet: CodeSnippet) {
        codeSnippets.removeAll { $0.id == snippet.id }
        saveCodeSnippets()
    }
    
    func codeSnippetsForPaper(pageNumber: Int) -> [CodeSnippet] {
        return codeSnippets.filter { $0.pageNumber == pageNumber }
    }
    
    // MARK: - 数据持久化
    
    private func loadData() {
        loadPapers()
        loadNotes()
        loadTags()
        loadCodeSnippets()
    }
    
    func resetAllData() {
        papers = []
        notes = []
        tags = []
        codeSnippets = []
        
        savePapers()
        saveNotes()
        saveTags()
        saveCodeSnippets()
    }
    
    // MARK: - 论文数据持久化
    
    private func savePapers() {
        do {
            let data = try JSONEncoder().encode(papers)
            UserDefaults.standard.set(data, forKey: papersKey)
        } catch {
            print("保存论文数据失败: \(error.localizedDescription)")
        }
    }
    
    private func loadPapers() {
        guard let data = UserDefaults.standard.data(forKey: papersKey) else { return }
        
        do {
            let decodedPapers = try JSONDecoder().decode([Paper].self, from: data)
            self.papers = decodedPapers
        } catch {
            print("加载论文数据失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 笔记数据持久化
    
    private func saveNotes() {
        do {
            let data = try JSONEncoder().encode(notes)
            UserDefaults.standard.set(data, forKey: notesKey)
        } catch {
            print("保存笔记数据失败: \(error.localizedDescription)")
        }
    }
    
    private func loadNotes() {
        guard let data = UserDefaults.standard.data(forKey: notesKey) else { return }
        
        do {
            let decodedNotes = try JSONDecoder().decode([Note].self, from: data)
            self.notes = decodedNotes
        } catch {
            print("加载笔记数据失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 标签数据持久化
    
    private func saveTags() {
        do {
            let data = try JSONEncoder().encode(tags)
            UserDefaults.standard.set(data, forKey: tagsKey)
        } catch {
            print("保存标签数据失败: \(error.localizedDescription)")
        }
    }
    
    private func loadTags() {
        guard let data = UserDefaults.standard.data(forKey: tagsKey) else { return }
        
        do {
            let decodedTags = try JSONDecoder().decode([Tag].self, from: data)
            self.tags = decodedTags
        } catch {
            print("加载标签数据失败: \(error.localizedDescription)")
            // 尝试从旧版本的字符串数组加载
            if let oldTags = UserDefaults.standard.stringArray(forKey: tagsKey) {
                self.tags = oldTags.map { Tag(name: $0, color: .blue) }
                // 保存为新格式
                saveTags()
            }
        }
    }
    
    // MARK: - 代码片段数据持久化
    
    private func saveCodeSnippets() {
        do {
            let data = try JSONEncoder().encode(codeSnippets)
            UserDefaults.standard.set(data, forKey: codeSnippetsKey)
        } catch {
            print("保存代码片段数据失败: \(error.localizedDescription)")
        }
    }
    
    private func loadCodeSnippets() {
        guard let data = UserDefaults.standard.data(forKey: codeSnippetsKey) else { return }
        
        do {
            let decodedSnippets = try JSONDecoder().decode([CodeSnippet].self, from: data)
            self.codeSnippets = decodedSnippets
        } catch {
            print("加载代码片段数据失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 预览数据
    
    static var preview: DataStore {
        let store = DataStore()
        store.papers = [
            Paper(
                title: "人工智能在医学影像处理中的应用",
                authors: ["张三", "李四"],
                publicationDate: Date(),
                journal: "医学信息学杂志",
                abstract: "本文探讨了深度学习和计算机视觉技术在医学影像处理中的应用，包括MRI、CT和X光图像的自动分割和诊断。研究表明，AI技术可以显著提高医学影像的分析效率和准确性。",
                keywords: ["深度学习", "医学影像", "人工智能", "计算机视觉"],
                doi: "10.1234/med.2023.001",
                fileURL: URL(fileURLWithPath: "/example/path/paper1.pdf"),
                dateAdded: Date(),
                lastOpened: Date(),
                tags: [
                    Tag(name: "医学", color: .purple),
                    Tag(name: "AI", color: .blue)
                ],
                categories: [],
                isFavorite: true,
                readingProgress: ReadingProgress(currentPage: 7, totalPages: 10),
                notes: []
            ),
            Paper(
                title: "量子计算的理论基础与实现挑战",
                authors: ["王五", "赵六"],
                publicationDate: Date().addingTimeInterval(-7776000),
                journal: "量子计算研究",
                abstract: "量子计算利用量子力学原理，如量子叠加和量子纠缠，实现经典计算机难以完成的计算任务。本文回顾了量子计算的理论基础，并分析了实现通用量子计算机面临的主要技术挑战。",
                keywords: ["量子计算", "量子纠缠", "量子优势", "量子错误校正"],
                doi: "10.5678/quantum.2022.002",
                fileURL: URL(fileURLWithPath: "/example/path/paper2.pdf"),
                dateAdded: Date().addingTimeInterval(-15552000),
                lastOpened: Date().addingTimeInterval(-2592000),
                tags: [
                    Tag(name: "量子", color: .yellow),
                    Tag(name: "计算理论", color: .blue)
                ],
                categories: [],
                isFavorite: false,
                readingProgress: ReadingProgress(currentPage: 3, totalPages: 10),
                notes: []
            )
        ]
        
        store.tags = [
            Tag(name: "AI", color: .blue, count: 1),
            Tag(name: "NLP", color: .green, count: 0),
            Tag(name: "重要", color: .red, count: 0),
            Tag(name: "医学", color: .purple, count: 1),
            Tag(name: "量子", color: .yellow, count: 1),
            Tag(name: "计算理论", color: .blue, count: 1)
        ]
        
        return store
    }
    
    // MARK: - 搜索和过滤
    
    func searchPapers(searchQuery: String) -> [Paper] {
        guard !searchQuery.isEmpty else { return papers }
        
        let lowercasedQuery = searchQuery.lowercased()
        
        return papers.filter { paper in
            paper.title.lowercased().contains(lowercasedQuery) ||
            paper.authors.joined(separator: " ").lowercased().contains(lowercasedQuery) ||
            paper.abstract.lowercased().contains(lowercasedQuery) ||
            paper.keywords.joined(separator: " ").lowercased().contains(lowercasedQuery) ||
            paper.tags.contains(where: { $0.name.lowercased().contains(lowercasedQuery) })
        }
    }
    
    func filterPapersByTag(_ tagName: String) -> [Paper] {
        return papers.filter { $0.tags.contains(where: { $0.name == tagName }) }
    }
    
    func filterPapers(by readStatus: Paper.ReadStatus?) -> [Paper] {
        guard let readStatus = readStatus else { return papers }
        
        return papers.filter { $0.readStatus == readStatus }
    }
    
    var favoritePapers: [Paper] {
        return papers.filter { $0.isFavorite }
    }
    
    var recentPapers: [Paper] {
        return papers.sorted { 
            $0.dateAdded > $1.dateAdded
        }
    }
}

enum PaperSearchCategory: String, CaseIterable {
    case title = "标题"
    case author = "作者"
    case abstract = "摘要"
    case keyword = "关键词"
    case tag = "标签"
    case journal = "期刊"
    case note = "笔记"
} 