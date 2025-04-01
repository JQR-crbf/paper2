import Foundation
import Combine
import PDFKit
import SwiftUI

class CodeSnippetService: ObservableObject {
    // 发布属性
    @Published var detectedSnippets: [ServiceCodeSnippet] = []
    @Published var isAnalyzing: Bool = false
    @Published var error: Error?
    
    // 依赖的服务
    private let pdfService: PDFService
    private let aiService: AIAnalysisService
    private var cancellables = Set<AnyCancellable>()
    
    // 静态代码识别正则表达式
    private let codeBlockPatterns: [String: String] = [
        "python": "```python\\s*\\n([\\s\\S]*?)\\n```",
        "java": "```java\\s*\\n([\\s\\S]*?)\\n```",
        "cpp": "```cpp\\s*\\n([\\s\\S]*?)\\n```",
        "javascript": "```javascript\\s*\\n([\\s\\S]*?)\\n```",
        "swift": "```swift\\s*\\n([\\s\\S]*?)\\n```",
        "generic": "```([\\s\\S]*?)```"
    ]
    
    // 代码语言特征
    private let languageFeatures: [String: [String]] = [
        "python": ["def ", "import ", "class ", "if __name__ == \"__main__\":", "print("],
        "java": ["public class", "private ", "protected ", "void ", "System.out."],
        "cpp": ["#include", "std::", "int main(", "cout <<", "nullptr"],
        "javascript": ["function ", "const ", "let ", "document.", "console.log"],
        "swift": ["import ", "func ", "var ", "let ", "class ", "struct "]
    ]
    
    init(pdfService: PDFService, aiService: AIAnalysisService) {
        self.pdfService = pdfService
        self.aiService = aiService
    }
    
    // MARK: - 公共方法
    
    // 从PDF中提取代码片段
    func extractCodeSnippets(from pdfURL: URL) -> AnyPublisher<[ServiceCodeSnippet], Error> {
        isAnalyzing = true
        
        // 首先加载PDF文档并提取文本
        let loadSuccess = pdfService.loadDocument(from: pdfURL)
        guard loadSuccess else {
            return Fail(error: CodeSnippetError.extractionFailed).eraseToAnyPublisher()
        }
        
        // 获取提取的文本
        let pdfText = pdfService.extractedText
        
        return Future<[ServiceCodeSnippet], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(CodeSnippetError.serviceUnavailable))
                return
            }
            
            // 调用detectCodeBlocks检测代码片段
            self.detectCodeBlocks(in: pdfText, from: pdfURL)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            self.error = error
                            self.isAnalyzing = false
                            promise(.failure(error))
                        }
                    },
                    receiveValue: { snippets in
                        self.detectedSnippets = snippets
                        self.isAnalyzing = false
                        promise(.success(snippets))
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    // 使用AI分析代码片段
    func analyzeSnippet(_ snippet: ServiceCodeSnippet) -> AnyPublisher<String, Error> {
        // 创建临时的CodeSnippet对象用于AI分析
        let codeSnippet = CodeSnippet(
            code: snippet.code,
            language: snippet.language,
            pageNumber: snippet.pageNumber ?? 0,
            paperId: UUID() // 使用临时UUID作为paperId
        )
        
        return aiService.analyzeCodeSnippet(codeSnippet)
            .map { analysisResult -> String in
                // 将CodeAnalysisResult转换为字符串
                let functionality = "功能: \(analysisResult.functionality)"
                let algorithm = "算法: \(analysisResult.algorithm)"
                let suggestions = "建议: \n" + analysisResult.suggestions.map { "- \($0)" }.joined(separator: "\n")
                let bestPractices = "最佳实践: \n" + analysisResult.bestPractices.map { "- \($0)" }.joined(separator: "\n")
                
                return [functionality, algorithm, suggestions, bestPractices].joined(separator: "\n\n")
            }
            .eraseToAnyPublisher()
    }
    
    // 将代码片段转换为图片
    func generateImage(for snippet: ServiceCodeSnippet, theme: CodeTheme = .default) -> UIImage? {
        // 实际应用中应该使用语法高亮库
        // 这里使用简化的渲染方法
        let attributedString = attributedCode(for: snippet, theme: theme)
        
        let renderer = UIGraphicsImageRenderer(bounds: CGRect(x: 0, y: 0, width: 800, height: 600))
        return renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(renderer.format.bounds)
            
            attributedString.draw(in: CGRect(x: 20, y: 20, width: 760, height: 560))
        }
    }
    
    // 导出代码片段
    func exportSnippet(_ snippet: ServiceCodeSnippet, to url: URL) throws {
        let data = Data(snippet.code.utf8)
        try data.write(to: url)
    }
    
    // MARK: - 私有辅助方法
    
    // 检测代码块
    private func detectCodeBlocks(in text: String, from pdfURL: URL) -> AnyPublisher<[ServiceCodeSnippet], Error> {
        return Future<[ServiceCodeSnippet], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(CodeSnippetError.serviceUnavailable))
                return
            }
            
            var snippets: [ServiceCodeSnippet] = []
            
            // 1. 使用正则表达式匹配Markdown风格的代码块
            for (language, pattern) in self.codeBlockPatterns {
                do {
                    let regex = try NSRegularExpression(pattern: pattern, options: [])
                    let nsString = text as NSString
                    let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                    
                    for match in matches {
                        if match.numberOfRanges >= 2 {
                            let codeRange = match.range(at: 1)
                            if codeRange.location != NSNotFound {
                                let code = nsString.substring(with: codeRange)
                                let lang = language == "generic" ? self.detectLanguage(from: code) : language
                                
                                let snippet = ServiceCodeSnippet(
                                    id: UUID(),
                                    code: code,
                                    language: lang,
                                    sourceURL: pdfURL,
                                    pageNumber: nil,
                                    lineStart: nil,
                                    lineEnd: nil
                                )
                                snippets.append(snippet)
                            }
                        }
                    }
                } catch {
                    promise(.failure(error))
                    return
                }
            }
            
            // 2. 如果没有找到Markdown风格的代码块，尝试启发式检测
            if snippets.isEmpty {
                // 按行分割文本
                let lines = text.components(separatedBy: .newlines)
                var currentBlock: [String] = []
                var inCodeBlock = false
                var lineStart: Int?
                
                for (i, line) in lines.enumerated() {
                    // 简单的启发式检测：如果一行有4个或更多空格缩进，且包含常见代码特征
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    let isCodeLike = self.looksLikeCode(line: trimmedLine)
                    
                    if isCodeLike && !inCodeBlock {
                        inCodeBlock = true
                        currentBlock = [line]
                        lineStart = i
                    } else if isCodeLike && inCodeBlock {
                        currentBlock.append(line)
                    } else if !isCodeLike && inCodeBlock {
                        // 代码块结束
                        if currentBlock.count >= 3 { // 只考虑至少3行的代码块
                            let code = currentBlock.joined(separator: "\n")
                            let language = self.detectLanguage(from: code)
                            
                            let snippet = ServiceCodeSnippet(
                                id: UUID(),
                                code: code,
                                language: language,
                                sourceURL: pdfURL,
                                pageNumber: nil, // 需要进一步处理
                                lineStart: lineStart,
                                lineEnd: i - 1
                            )
                            snippets.append(snippet)
                        }
                        
                        inCodeBlock = false
                        currentBlock = []
                        lineStart = nil
                    }
                }
                
                // 处理最后一个未闭合的代码块
                if inCodeBlock && currentBlock.count >= 3 {
                    let code = currentBlock.joined(separator: "\n")
                    let language = self.detectLanguage(from: code)
                    
                    let snippet = ServiceCodeSnippet(
                        id: UUID(),
                        code: code,
                        language: language,
                        sourceURL: pdfURL,
                        pageNumber: nil,
                        lineStart: lineStart,
                        lineEnd: lines.count - 1
                    )
                    snippets.append(snippet)
                }
            }
            
            promise(.success(snippets))
        }.eraseToAnyPublisher()
    }
    
    // 判断一行文本是否可能是代码
    private func looksLikeCode(line: String) -> Bool {
        // 基本特征检测
        if line.isEmpty {
            return false
        }
        
        // 检查常见代码特征
        let codeIndicators = ["=", "==", "!=", ">=", "<=", "(", ")", "{", "}", "[", "]", ";", "->", "=>", "import ", "class ", "function ", "def ", "var ", "let ", "const ", "if ", "for ", "while ", "return "]
        
        for indicator in codeIndicators {
            if line.contains(indicator) {
                return true
            }
        }
        
        // 检查缩进和格式
        if line.hasPrefix("    ") || line.hasPrefix("\t") {
            return true
        }
        
        // 检查注释
        if line.hasPrefix("//") || line.hasPrefix("#") || line.hasPrefix("/*") || line.contains("*/") {
            return true
        }
        
        return false
    }
    
    // 检测代码语言
    private func detectLanguage(from code: String) -> String {
        var scores: [String: Int] = [:]
        
        // 初始化所有语言的分数
        for language in languageFeatures.keys {
            scores[language] = 0
        }
        
        // 计算每种语言的特征匹配得分
        for (language, features) in languageFeatures {
            for feature in features {
                if code.contains(feature) {
                    scores[language, default: 0] += 1
                }
            }
        }
        
        // 返回得分最高的语言
        if let (bestLanguage, score) = scores.max(by: { $0.value < $1.value }), score > 0 {
            return bestLanguage
        }
        
        // 默认返回
        return "unknown"
    }
    
    // 估计代码复杂度
    private func estimateComplexity(of snippet: ServiceCodeSnippet) -> Int {
        let code = snippet.code
        let lines = code.components(separatedBy: .newlines)
        
        // 简单的复杂度估算
        var complexity = 1
        
        // 1. 代码长度
        complexity += min(5, lines.count / 10)
        
        // 2. 循环和条件语句
        let controlStatements = ["if", "for", "while", "switch", "case"]
        for statement in controlStatements {
            let pattern = "\\b\(statement)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: code, options: [], range: NSRange(location: 0, length: (code as NSString).length))
                complexity += min(3, matches.count)
            }
        }
        
        // 3. 嵌套深度（简化估算）
        var maxDepth = 0
        var currentDepth = 0
        for character in code {
            if character == "{" || character == "(" || character == "[" {
                currentDepth += 1
                maxDepth = max(maxDepth, currentDepth)
            } else if character == "}" || character == ")" || character == "]" {
                currentDepth = max(0, currentDepth - 1)
            }
        }
        complexity += min(3, maxDepth / 2)
        
        return min(10, complexity) // 最大复杂度为10
    }
    
    // 生成带语法高亮的代码
    private func attributedCode(for snippet: ServiceCodeSnippet, theme: CodeTheme) -> NSAttributedString {
        let string = NSMutableAttributedString(string: snippet.code)
        
        let codeFont = UIFont.monospacedSystemFont(ofSize: theme.fontSize, weight: .regular)
        string.addAttribute(.font, value: codeFont, range: NSRange(location: 0, length: string.length))
        
        // 这里简化了语法高亮，实际应用中应该使用专门的语法高亮库
        // 例如为关键字添加颜色
        let keywords: [String]
        switch snippet.language {
        case "python":
            keywords = ["def", "class", "import", "from", "if", "else", "elif", "for", "while", "return", "True", "False", "None"]
        case "swift":
            keywords = ["func", "class", "struct", "enum", "var", "let", "if", "else", "guard", "return", "true", "false", "nil"]
        case "java":
            keywords = ["public", "private", "protected", "class", "interface", "void", "int", "boolean", "String", "if", "else", "for", "while", "return", "true", "false", "null"]
        default:
            keywords = []
        }
        
        for keyword in keywords {
            let pattern = "\\b\(keyword)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: snippet.code, options: [], range: NSRange(location: 0, length: string.length))
                for match in matches {
                    string.addAttribute(.foregroundColor, value: theme.keywordColor, range: match.range)
                }
            }
        }
        
        return string
    }
}

// MARK: - 相关模型

// 代码片段模型
struct ServiceCodeSnippet: Identifiable, Codable, Equatable {
    var id: UUID
    var code: String
    var language: String
    var sourceURL: URL
    var pageNumber: Int?
    var lineStart: Int?
    var lineEnd: Int?
    var dateAdded: Date = Date()
    
    // 标准初始化方法
    init(id: UUID, code: String, language: String, sourceURL: URL, pageNumber: Int? = nil, lineStart: Int? = nil, lineEnd: Int? = nil, dateAdded: Date = Date()) {
        self.id = id
        self.code = code
        self.language = language
        self.sourceURL = sourceURL
        self.pageNumber = pageNumber
        self.lineStart = lineStart
        self.lineEnd = lineEnd
        self.dateAdded = dateAdded
    }
    
    enum CodingKeys: String, CodingKey {
        case id, code, language, sourceURLString, pageNumber, lineStart, lineEnd, dateAdded
    }
    
    // 自定义编码方法
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(code, forKey: .code)
        try container.encode(language, forKey: .language)
        try container.encode(sourceURL.path, forKey: .sourceURLString)
        try container.encodeIfPresent(pageNumber, forKey: .pageNumber)
        try container.encodeIfPresent(lineStart, forKey: .lineStart)
        try container.encodeIfPresent(lineEnd, forKey: .lineEnd)
        try container.encode(dateAdded, forKey: .dateAdded)
    }
    
    // 自定义解码方法
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        code = try container.decode(String.self, forKey: .code)
        language = try container.decode(String.self, forKey: .language)
        
        let sourceURLString = try container.decode(String.self, forKey: .sourceURLString)
        sourceURL = URL(fileURLWithPath: sourceURLString)
        
        pageNumber = try container.decodeIfPresent(Int.self, forKey: .pageNumber)
        lineStart = try container.decodeIfPresent(Int.self, forKey: .lineStart)
        lineEnd = try container.decodeIfPresent(Int.self, forKey: .lineEnd)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
    }
    
    // 自定义Equatable实现
    static func == (lhs: ServiceCodeSnippet, rhs: ServiceCodeSnippet) -> Bool {
        lhs.id == rhs.id
    }
}

// 代码片段分析结果
struct CodeSnippetAnalysis: Identifiable, Codable {
    var id: UUID = UUID()
    var snippetId: UUID
    var explanation: String
    var complexity: Int // 1-10
    var timestamp: Date
    
    // 格式化的复杂度评估
    var formattedComplexity: String {
        let stars = String(repeating: "★", count: complexity)
        let emptyStars = String(repeating: "☆", count: 10 - complexity)
        return stars + emptyStars
    }
}

// 代码高亮主题
struct CodeTheme {
    var backgroundColor: UIColor
    var textColor: UIColor
    var keywordColor: UIColor
    var stringColor: UIColor
    var commentColor: UIColor
    var fontSize: CGFloat
    
    static let `default` = CodeTheme(
        backgroundColor: .systemBackground,
        textColor: .label,
        keywordColor: .systemBlue,
        stringColor: .systemGreen,
        commentColor: .systemGray,
        fontSize: 14
    )
    
    static let dark = CodeTheme(
        backgroundColor: .black,
        textColor: .white,
        keywordColor: .systemPink,
        stringColor: .systemGreen,
        commentColor: .systemGray,
        fontSize: 14
    )
    
    static let light = CodeTheme(
        backgroundColor: .white,
        textColor: .black,
        keywordColor: .systemBlue,
        stringColor: .systemGreen,
        commentColor: .systemGray,
        fontSize: 14
    )
}

// 错误类型
enum CodeSnippetError: Error {
    case extractionFailed
    case analysisError
    case serviceUnavailable
    case languageDetectionFailed
    
    var localizedDescription: String {
        switch self {
        case .extractionFailed:
            return "代码提取失败"
        case .analysisError:
            return "代码分析错误"
        case .serviceUnavailable:
            return "服务不可用"
        case .languageDetectionFailed:
            return "语言检测失败"
        }
    }
} 