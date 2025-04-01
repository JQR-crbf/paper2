//
//  PDFService.swift
//  Paper analysis tool
//
//  Created by 金倩如AI on 2023/4/1.
//

import Foundation
import PDFKit
import Combine
import SwiftUI
import NaturalLanguage

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// 导入 CodeSnippet 类型
// @_exported import struct Paper_analysis_tool.CodeSnippet

class PDFService: ObservableObject {
    @Published var document: PDFDocument?
    @Published var pageCount: Int = 0
    @Published var currentPage: Int = 0
    @Published var extractedText: String = ""
    
    // 当前文档的路径
    private var currentDocumentURL: URL?
    
    // 加载PDF文档
    func loadDocument(from url: URL) -> Bool {
        guard let document = PDFDocument(url: url) else {
            return false
        }
        
        self.document = document
        self.pageCount = document.pageCount
        extractFullText()
        self.currentDocumentURL = url
        return true
    }
    
    // 加载PDF文档从数据
    func loadDocument(from data: Data) -> Bool {
        guard let document = PDFDocument(data: data) else {
            print("无法从数据加载PDF文档")
            return false
        }
        
        self.document = document
        self.pageCount = document.pageCount
        self.currentDocumentURL = nil
        extractFullText()
        return true
    }
    
    // 获取指定页面
    func page(at index: Int) -> PDFPage? {
        guard let document = document, index >= 0, index < pageCount else {
            return nil
        }
        return document.page(at: index)
    }
    
    // 获取PDF文档的元数据
    func getMetadata() -> [String: String] {
        guard let document = document else {
            return [:]
        }
        
        var metadata: [String: String] = [:]
        
        // 获取标准属性
        let properties: [PDFDocumentAttribute: String] = [
            .titleAttribute: "title",
            .authorAttribute: "author",
            .subjectAttribute: "subject",
            .creatorAttribute: "creator",
            .producerAttribute: "producer",
            .creationDateAttribute: "creationDate",
            .modificationDateAttribute: "modificationDate",
            .keywordsAttribute: "keywords"
        ]
        
        for (attribute, key) in properties {
            if let value = document.documentAttributes?[attribute] as? String {
                metadata[key] = value
            } else if let date = document.documentAttributes?[attribute] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                metadata[key] = formatter.string(from: date)
            }
        }
        
        // 添加页数
        metadata["pageCount"] = "\(document.pageCount)"
        
        return metadata
    }
    
    // 提取全文
    private func extractFullText() {
        guard let document = document else {
            extractedText = ""
            return
        }
        
        var fullText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i),
               let pageText = page.string {
                fullText += pageText + "\n\n"
            }
        }
        
        extractedText = fullText
    }
    
    // 提取特定页面的文本
    func extractText(from pageIndex: Int) -> String {
        guard let page = page(at: pageIndex) else {
            return ""
        }
        
        return page.string ?? ""
    }
    
    // 从URL提取PDF文本
    func extractText(from url: URL) -> AnyPublisher<String, Error> {
        // 先尝试加载文档
        if loadDocument(from: url) {
            return Just(extractedText)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: PDFServiceError.documentLoadFailed)
                .eraseToAnyPublisher()
        }
    }
    
    // 计算页面的文本范围
    func rangesOfContent(for pageIndex: Int) -> [NSRange]? {
        guard let page = page(at: pageIndex),
              let pageContent = page.string else {
            return nil
        }
        
        let paragraphs = pageContent.components(separatedBy: "\n\n")
        var ranges: [NSRange] = []
        var currentPosition = 0
        
        for paragraph in paragraphs where !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let range = NSRange(location: currentPosition, length: paragraph.count)
            ranges.append(range)
            currentPosition += paragraph.count + 2 // 加上分隔符长度
        }
        
        return ranges
    }
    
    // 识别论文章节
    func identifySections() -> [PaperSection] {
        guard let document = document else {
            return []
        }
        
        var sections: [PaperSection] = []
        let patterns = [
            "^\\s*\\d+\\.\\s*([A-Z][^\\n]+)$",  // 1. Title
            "^\\s*[A-Z][^\\n]{2,40}$",          // TITLE
            "^\\s*[IVX]+\\.\\s*([A-Z][^\\n]+)$" // I. Title
        ]
        
        for i in 0..<document.pageCount {
            if let page = document.page(at: i),
               let content = page.string {
                
                // 按行分割
                let lines = content.components(separatedBy: .newlines)
                
                for line in lines {
                    for pattern in patterns {
                        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                           let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) {
                            
                            let title: String
                            if match.numberOfRanges > 1 {
                                // 提取括号中的标题
                                let range = match.range(at: 1)
                                title = (line as NSString).substring(with: range)
                            } else {
                                // 使用整行作为标题
                                title = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            
                            // 提取章节内容
                            var sectionContent = ""
                            if i < document.pageCount - 1 {
                                sectionContent = extractText(from: i)
                            }
                            
                            // 创建章节对象
                            let section = PaperSection(
                                title: title,
                                level: 1,
                                pageNumber: i + 1,
                                content: sectionContent
                            )
                            
                            sections.append(section)
                            break
                        }
                    }
                }
            }
        }
        
        return sections
    }
    
    // 生成论文摘要
    func generateAbstract() -> String {
        guard let document = document, pageCount > 0 else {
            return ""
        }
        
        // 尝试查找摘要部分
        for i in 0..<min(5, pageCount) {
            if let page = document.page(at: i),
               let content = page.string {
                
                // 寻找"Abstract"标记
                if let range = content.range(of: "Abstract", options: .caseInsensitive) {
                    let abstractStart = content.index(range.upperBound, offsetBy: 1)
                    let remainingContent = content[abstractStart...]
                    
                    // 查找摘要结束位置
                    if let endRange = remainingContent.range(of: "Introduction", options: .caseInsensitive) {
                        return String(remainingContent[..<endRange.lowerBound])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        // 如果没有明确的结束标记，取接下来的段落
                        let endIndex = min(500, remainingContent.count)
                        let abstractText = remainingContent.prefix(endIndex)
                        return String(abstractText).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        
        // 如果没找到明确的摘要部分，提取首页前部分文本
        if let firstPage = document.page(at: 0),
           let content = firstPage.string {
            let endIndex = min(500, content.count)
            return String(content.prefix(endIndex))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return ""
    }
    
    // 提取作者列表
    func extractAuthors() -> [String] {
        guard let document = document, pageCount > 0 else {
            return []
        }
        
        if let firstPage = document.page(at: 0),
           let content = firstPage.string {
            
            // 常见作者列表正则模式
            let patterns = [
                "(?:\\b(?:Authors?|By)\\s*:?\\s*)([^\\n]{5,100})",
                "(?:\\b(?:[A-Z][a-z]+ [A-Z][a-z]+)(?:,|\\s+and\\s+|\\s*&\\s*|\\s*;\\s*))+"
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.count)) {
                    
                    let authorText: String
                    if match.numberOfRanges > 1 {
                        let range = match.range(at: 1)
                        authorText = (content as NSString).substring(with: range)
                    } else {
                        let range = match.range(at: 0)
                        authorText = (content as NSString).substring(with: range)
                    }
                    
                    // 拆分作者列表
                    let authors = authorText
                        .replacingOccurrences(of: " and ", with: ", ")
                        .replacingOccurrences(of: " & ", with: ", ")
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    
                    if !authors.isEmpty {
                        return authors
                    }
                }
            }
        }
        
        return []
    }
    
    // 提取论文标题
    func extractTitle() -> String {
        guard let document = document, pageCount > 0 else {
            return ""
        }
        
        if let firstPage = document.page(at: 0),
           let content = firstPage.string {
            
            // 获取首页的前200个字符
            let topContent = String(content.prefix(200))
            let lines = topContent.components(separatedBy: .newlines)
            
            // 查找可能的标题行
            for line in lines where line.count > 5 && line.count < 200 {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 标题通常是第一个非空的、较短的行
                if !trimmedLine.isEmpty {
                    // 排除一些明显不是标题的行
                    let lowerLine = trimmedLine.lowercased()
                    if !lowerLine.contains("abstract") && 
                       !lowerLine.contains("keywords") && 
                       !lowerLine.contains("copyright") {
                        return trimmedLine
                    }
                }
            }
        }
        
        return ""
    }
    
    // 提取关键词
    func extractKeywords() -> [String] {
        guard let document = document, pageCount > 0 else {
            return []
        }
        
        for i in 0..<min(3, pageCount) {
            if let page = document.page(at: i),
               let content = page.string {
                
                // 关键词部分的常见标记
                let keywordPatterns = ["Keywords:", "Keywords", "Key words:", "Key words"]
                
                for pattern in keywordPatterns {
                    if let range = content.range(of: pattern, options: .caseInsensitive) {
                        let start = content.index(range.upperBound, offsetBy: 0)
                        let remainingContent = content[start...]
                        
                        // 查找关键词部分的结尾
                        let endPatterns = ["Introduction", "1.", "Abstract"]
                        var endPosition = remainingContent.endIndex
                        
                        for endPattern in endPatterns {
                            if let endRange = remainingContent.range(of: endPattern, options: .caseInsensitive) {
                                let possibleEnd = remainingContent.index(endRange.lowerBound, offsetBy: 0)
                                if possibleEnd < endPosition {
                                    endPosition = possibleEnd
                                }
                            }
                        }
                        
                        // 提取关键词文本
                        let keywordsText = remainingContent[..<endPosition]
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // 分割关键词
                        return keywordsText
                            .components(separatedBy: [",", ";"])
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty && $0.count < 50 }
                    }
                }
            }
        }
        
        return []
    }
    
    // 从PDF提取元数据
    func extractMetadata() -> [String: String] {
        guard let document = document else {
            return [:]
        }
        
        var metadata: [String: String] = [:]
        
        if let info = document.documentAttributes {
            for (key, value) in info {
                metadata[key as! String] = "\(value)"
            }
        }
        
        return metadata
    }
    
    // 提取文档的主题和关键词
    func extractKeywords(completion: @escaping ([String]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion([])
                return
            }
            
            let text = self.extractedText
            
            // 使用自然语言处理框架提取关键词
            let tagger = NLTagger(tagSchemes: [.nameType, .lemma])
            tagger.string = text
            
            var keywords = Set<String>()
            let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
            
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma, options: options) { tag, tokenRange in
                if let lemma = tag?.rawValue {
                    let word = String(text[tokenRange]).lowercased()
                    if word.count > 3 && !self.isStopWord(word) {
                        keywords.insert(lemma)
                    }
                }
                return true
            }
            
            // 简单的词频统计
            var wordCounts: [String: Int] = [:]
            
            for keyword in keywords {
                let pattern = "\\b\(keyword)\\b"
                do {
                    let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                    let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                    wordCounts[keyword] = matches.count
                } catch {
                    print("正则表达式错误: \(error)")
                }
            }
            
            // 按频率排序并返回前30个关键词
            let sortedKeywords = wordCounts.sorted { $0.value > $1.value }.prefix(30).map { $0.key }
            
            DispatchQueue.main.async {
                completion(Array(sortedKeywords))
            }
        }
    }
    
    // 检测是否是停用词
    private func isStopWord(_ word: String) -> Bool {
        let stopWords = ["the", "and", "this", "that", "with", "from", "for", "was", "were", "have", "has", "had", "been", "these", "those", "their", "which", "when", "what", "where", "who", "whom", "whose", "how", "why"]
        return stopWords.contains(word.lowercased())
    }
    
    // 搜索PDF文档
    func search(for text: String) -> [PDFSelection] {
        guard let document = document, !text.isEmpty else {
            return []
        }
        
        let selections = document.findString(text, withOptions: .caseInsensitive)
        return selections ?? []
    }
    
    // 创建高亮
    func createHighlight(for selection: PDFSelection, color: Color) {
        // 获取选择关联的页面
        if let page = selection.pages.first {
            // 创建高亮注释
            let bounds = selection.bounds(for: page)
            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            
            // 设置高亮颜色
            #if canImport(UIKit)
            annotation.color = UIColor.yellow
            #elseif canImport(AppKit)
            annotation.color = NSColor.yellow
            #endif
            
            page.addAnnotation(annotation)
        }
    }
    
    // 从文本中识别代码片段
    func identifyCodeSnippets() -> [CodeSnippet] {
        guard let document = document else {
            return []
        }
        
        var codeSnippets: [CodeSnippet] = []
        
        // 常见的代码块指示符
        let codePatterns = [
            "```[a-zA-Z]*\\n([\\s\\S]*?)```",                // Markdown code block
            "\\\\begin\\{code\\}([\\s\\S]*?)\\\\end\\{code\\}",  // LaTeX code block
            "\\\\begin\\{lstlisting\\}([\\s\\S]*?)\\\\end\\{lstlisting\\}" // LaTeX listing
        ]
        
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i), let text = page.string else {
                continue
            }
            
            for pattern in codePatterns {
                do {
                    let regex = try NSRegularExpression(pattern: pattern)
                    let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                    
                    for match in matches {
                        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) {
                            let codeText = String(text[range])
                            
                            // 尝试通过语法分析猜测语言
                            let language = guessLanguage(from: codeText)
                            
                            let snippet = CodeSnippet(
                                code: codeText,
                                language: language,
                                pageNumber: i + 1,
                                paperId: UUID() // 使用临时ID，实际使用时应该传入论文ID
                            )
                            codeSnippets.append(snippet)
                        }
                    }
                } catch {
                    print("正则表达式错误: \(error)")
                }
            }
            
            // 也尝试识别缩进大于普通文本的代码块
            let lines = text.components(separatedBy: .newlines)
            var codeBlockLines: [String] = []
            var inCodeBlock = false
            var codeBlockStartPage = i + 1
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let leadingSpace = line.prefix(while: { $0 == " " }).count
                
                if !inCodeBlock && leadingSpace >= 4 && !trimmedLine.isEmpty {
                    // 可能是代码开始
                    inCodeBlock = true
                    codeBlockStartPage = i + 1
                    codeBlockLines.append(line)
                } else if inCodeBlock && (leadingSpace >= 4 || trimmedLine.isEmpty) {
                    // 继续代码块
                    codeBlockLines.append(line)
                } else if inCodeBlock {
                    // 代码块结束
                    inCodeBlock = false
                    
                    if codeBlockLines.count >= 3 {
                        let codeText = codeBlockLines.joined(separator: "\n")
                        let language = guessLanguage(from: codeText)
                        
                        let snippet = CodeSnippet(
                            code: codeText,
                            language: language,
                            pageNumber: codeBlockStartPage,
                            paperId: UUID() // 使用临时ID，实际使用时应该传入论文ID
                        )
                        codeSnippets.append(snippet)
                    }
                    
                    codeBlockLines = []
                }
            }
            
            // 处理页面末尾的代码块
            if inCodeBlock && codeBlockLines.count >= 3 {
                let codeText = codeBlockLines.joined(separator: "\n")
                let language = guessLanguage(from: codeText)
                
                let snippet = CodeSnippet(
                    code: codeText,
                    language: language,
                    pageNumber: codeBlockStartPage,
                    paperId: UUID() // 使用临时ID，实际使用时应该传入论文ID
                )
                codeSnippets.append(snippet)
            }
        }
        
        return codeSnippets
    }
    
    // 根据代码内容猜测编程语言
    private func guessLanguage(from code: String) -> String {
        // 简单的语言检测逻辑
        if code.contains("import numpy") || code.contains("import pandas") || code.contains("def ") {
            return "python"
        } else if code.contains("public class") || code.contains("private void") || code.contains("System.out") {
            return "java"
        } else if code.contains("func ") && code.contains("var ") && code.contains("let ") {
            return "swift"
        } else if code.contains("<html") || code.contains("<div") || code.contains("<body") {
            return "html"
        } else if code.contains("cout <<") || code.contains("#include") || code.contains("int main") {
            return "cpp"
        } else if code.contains("function ") || code.contains("var ") || code.contains("const ") && code.contains("{") {
            return "javascript"
        } else {
            return "text"
        }
    }
    
    // 查找特定页面上的文本
    func findText(_ text: String, on pageIndex: Int) -> PDFSelection? {
        guard let document = document, 
              let page = document.page(at: pageIndex),
              !text.isEmpty else {
            return nil
        }
        
        // 创建选择对象
        let selection = PDFSelection(document: document)
        
        // 获取页面内容
        guard let pageContent = page.string else {
            return nil
        }
        
        // 查找文本位置
        if let range = pageContent.range(of: text) {
            let location = pageContent.distance(from: pageContent.startIndex, to: range.lowerBound)
            let length = text.count
            
            // 创建NSRange
            let nsRange = NSRange(location: location, length: length)
            
            // 添加到选择
            if let pageSelection = page.selection(for: nsRange) {
                selection.add(pageSelection)
            }
            return selection
        }
        
        return nil
    }
    
    // 从PDF文档提取页面图像
    // ... existing code ...
}

// 错误类型
enum PDFServiceError: Error {
    case documentLoadFailed
    case textExtractionFailed
    case pageNotFound
    
    var localizedDescription: String {
        switch self {
        case .documentLoadFailed:
            return "无法加载PDF文档"
        case .textExtractionFailed:
            return "文本提取失败"
        case .pageNotFound:
            return "找不到指定页面"
        }
    }
}