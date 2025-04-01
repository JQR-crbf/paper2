
import Foundation
import UniformTypeIdentifiers
import Combine

class WordService: ObservableObject {
    @Published var isLoading = false
    @Published var documentContent: String = ""
    private var documentURL: URL?
    
    // 加载Word文档
    func loadDocument(from url: URL) -> Bool {
        self.documentURL = url
        isLoading = true
        
        // 使用NSDocumentTypeDocumentAttribute处理Word文档
        if url.pathExtension.lowercased() == "docx" || url.pathExtension.lowercased() == "doc" {
            do {
                // 读取文档内容
                let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ]
                
                let attributedString = try NSAttributedString(url: url, options: options, documentAttributes: nil)
                documentContent = attributedString.string
                isLoading = false
                return true
            } catch {
                print("读取Word文档失败: \(error)")
                isLoading = false
                return false
            }
        }
        isLoading = false
        return false
    }
    
    // 提取标题
    func extractTitle() -> String {
        // 尝试从文档内容中提取标题
        // 通常标题在文档的开头，并且可能使用特定的格式
        let lines = documentContent.components(separatedBy: .newlines)
        if let firstLine = lines.first {
            return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
    
    // 提取作者列表
    func extractAuthors() -> [String] {
        // 尝试从文档内容中提取作者信息
        // 通常作者信息在标题之后，可能包含"Author"、"Authors"等标记
        let lines = documentContent.components(separatedBy: .newlines)
        for line in lines {
            if line.lowercased().contains("author") {
                let authorsText = line.replacingOccurrences(of: "Author(s):", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "Authors:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                return authorsText.components(separatedBy: [",", "&"])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }
        return []
    }
    
    // 生成摘要
    func generateAbstract() -> String {
        // 尝试从文档内容中提取摘要
        // 通常摘要部分以"Abstract"开头
        let lines = documentContent.components(separatedBy: .newlines)
        var abstractText = ""
        var isAbstract = false
        
        for line in lines {
            if line.lowercased().contains("abstract") {
                isAbstract = true
                continue
            }
            
            if isAbstract {
                if line.lowercased().contains("introduction") {
                    break
                }
                abstractText += line + "\n"
            }
        }
        
        return abstractText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 提取关键词
    func extractKeywords() -> [String] {
        // 尝试从文档内容中提取关键词
        // 通常关键词部分以"Keywords"开头
        let lines = documentContent.components(separatedBy: .newlines)
        for line in lines {
            if line.lowercased().contains("keywords") {
                let keywordsText = line.replacingOccurrences(of: "Keywords:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                return keywordsText.components(separatedBy: [",", ";"])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && $0.count < 50 }
            }
        }
        return []
    }
    
    // 获取文档内容
    func getContent() -> String {
        return documentContent
    }
} 