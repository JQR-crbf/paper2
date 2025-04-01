import Foundation
import Combine
import SwiftUI

class AIAnalysisService: ObservableObject {
    // 发布属性
    @Published var isAnalyzing: Bool = false
    @Published var progress: Double = 0.0
    @Published var error: Error?
    
    // API配置
    private var apiKey: String = ""
    private var baseURL: String = ""
    private var serviceProvider: AIServiceProvider
    private var cancellables = Set<AnyCancellable>()
    private var useSimulatedData: Bool = false
    private var selectedModel: String = ""
    private var requestTimeout: TimeInterval
    private var enableKnowledgeBase: Bool = false
    private var knowledgeBaseId: String = ""
    
    // 模拟数据
    private let simulatedSummary = "这篇论文探讨了深度学习在自然语言处理中的应用。作者提出了一种新的神经网络架构，能够更有效地处理长文本序列。实验结果表明，该模型在多个基准测试中都优于现有方法。"
    
    private let simulatedStructure = "## 论文结构\n\n1. **摘要** - 简述研究目标和成果\n2. **引言** - 介绍研究背景和问题\n3. **相关工作** - 回顾现有方法\n4. **方法** - 详细描述提出的模型\n5. **实验** - 实验设置和结果\n6. **结论** - 总结研究发现和未来工作方向"
    
    private let simulatedKeyPoints = "## 论文关键点\n\n- 提出了一种新的深度学习模型用于自然语言处理\n- 该模型能够处理更长的文本序列\n- 在多个基准数据集上进行了评估\n- 结果显示比现有方法提高了15%的性能\n- 模型参数更少，训练速度更快"
    
    private let simulatedAnalysis = "## 论文分析\n\n**优势**:\n- 创新性方法解决长序列问题\n- 实验设计合理，结果可信\n- 模型效率高，适合实际应用\n\n**局限性**:\n- 仅在英文数据集上测试\n- 缺乏在特定领域的应用案例\n- 可能需要大量计算资源\n\n**研究影响**:\n该工作为处理长文本序列提供了新思路，可能对多种NLP任务产生积极影响。"
    
    private let simulatedGeneral = "这是一篇关于深度学习的高质量论文。论文结构清晰，实验充分，结果令人信服。作者的创新点主要在于改进了模型架构，使其能够更好地处理长序列文本。未来工作可以考虑在更多语言和特定领域进行测试。"
    
    enum AnalysisType {
        case summary
        case keyConcepts
        case codeAnalysis
        case knowledgeGraph
        case researchQuestions
        case methodAnalysis
        case contributionsAnalysis
        case futureDirections
        case literatureReview
    }
    
    init(apiKey: String = "", 
         baseURL: String = "https://api.openai.com/v1",
         useSimulatedData: Bool = false,
         selectedModel: String = "gpt-4",
         serviceProvider: AIServiceProvider = .openAI,
         requestTimeout: TimeInterval = 60,
         enableKnowledgeBase: Bool = false,
         knowledgeBaseId: String = "") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.useSimulatedData = useSimulatedData
        self.selectedModel = selectedModel
        self.serviceProvider = serviceProvider
        self.requestTimeout = requestTimeout
        self.enableKnowledgeBase = enableKnowledgeBase
        self.knowledgeBaseId = knowledgeBaseId
    }
    
    // 更新API设置
    func updateSettings(apiKey: String, baseURL: String, useSimulatedData: Bool, selectedModel: String? = nil, serviceProvider: AIServiceProvider? = nil, requestTimeout: TimeInterval? = nil, enableKnowledgeBase: Bool = false, knowledgeBaseId: String = "") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.useSimulatedData = useSimulatedData
        
        if let model = selectedModel {
            self.selectedModel = model
        }
        
        if let provider = serviceProvider {
            self.serviceProvider = provider
        }
        
        if let timeout = requestTimeout {
            self.requestTimeout = timeout
        }
        
        self.enableKnowledgeBase = enableKnowledgeBase
        self.knowledgeBaseId = knowledgeBaseId
    }
    
    // 生成论文摘要
    func generateSummary(from text: String, maxLength: Int = 500) -> AnyPublisher<String, Error> {
        if useSimulatedData {
            return simulateResponse(for: .summary, text: text)
        }
        
        let prompt = """
        请为以下论文内容生成一个简洁的摘要，最多\(maxLength)字，包含以下要点：
        1. 研究目的和背景
        2. 主要方法和研究设计
        3. 关键发现和实验结果
        4. 结论意义和潜在应用
        
        用简明、专业的学术语言撰写。
        
        论文内容：
        \(text)
        """
        
        return sendRequest(prompt: prompt)
    }
    
    // 提取关键概念
    func extractKeyConcepts(from text: String, maxConcepts: Int = 10) -> AnyPublisher<[ConceptItem], Error> {
        if useSimulatedData {
            return simulateResponse(for: .keyConcepts, text: text)
                .map { response -> [ConceptItem] in
                    return self.parseConceptsFromText(response)
                }
                .eraseToAnyPublisher()
        }
        
        let prompt = """
        请从以下论文内容中提取最多\(maxConcepts)个关键概念，并以JSON格式返回：
        [
            {
                "name": "概念名称",
                "description": "简短解释（最多100字）",
                "importance": "在论文中的重要性评分（1-5）"
            },
            ...
        ]
        
        确保概念按重要性排序，最重要的概念在前。
        
        论文内容：
        \(text)
        """
        
        return sendRequest(prompt: prompt)
            .map { response -> [ConceptItem] in
                do {
                    if let jsonData = response.data(using: .utf8) {
                        return try JSONDecoder().decode([ConceptItem].self, from: jsonData)
                    }
                } catch {
                    print("解析概念JSON失败: \(error)")
                }
                // 如果JSON解析失败，尝试从文本中提取
                return self.parseConceptsFromText(response)
            }
            .eraseToAnyPublisher()
    }
    
    // 从文本中提取概念（备用方法）
    private func parseConceptsFromText(_ text: String) -> [ConceptItem] {
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        var concepts: [ConceptItem] = []
        
        for (index, line) in lines.enumerated() {
            if index >= 10 { break } // 最多10个概念
            
            let parts = line.components(separatedBy: ":")
            if parts.count >= 2 {
                let name = parts[0].trimmingCharacters(in: .whitespaces)
                let description = parts[1].trimmingCharacters(in: .whitespaces)
                let importance = min(5, 5 - (index / 2)) // 根据位置降低重要性
                
                concepts.append(ConceptItem(name: name, description: description, importance: importance))
            }
        }
        
        return concepts
    }
    
    // 分析代码片段
    func analyzeCodeSnippet(_ snippet: CodeSnippet) -> AnyPublisher<CodeAnalysisResult, Error> {
        if useSimulatedData {
            return simulateResponse(for: .codeAnalysis, text: snippet.code)
                .map { response -> CodeAnalysisResult in
                    return CodeAnalysisResult(
                        functionality: "这段代码实现了基本的数据处理功能",
                        algorithm: "使用了贪心算法进行优化",
                        suggestions: ["可以使用并行处理提高性能", "建议添加错误处理"],
                        bestPractices: ["遵循了命名规范", "模块化设计良好"]
                    )
                }
                .eraseToAnyPublisher()
        }
        
        let prompt = """
        请以JSON格式分析以下代码片段：
        {
            "functionality": "代码功能详细说明",
            "algorithm": "使用的主要算法或技术说明",
            "suggestions": ["优化建议1", "优化建议2", ...],
            "bestPractices": ["最佳实践1", "最佳实践2", ...]
        }
        
        代码语言：\(snippet.language)
        代码内容：
        \(snippet.code)
        """
        
        return sendRequest(prompt: prompt)
            .map { response -> CodeAnalysisResult in
                do {
                    if let jsonData = response.data(using: .utf8) {
                        return try JSONDecoder().decode(CodeAnalysisResult.self, from: jsonData)
                    }
                } catch {
                    print("解析代码分析JSON失败: \(error)")
                }
                // 备用响应
                return CodeAnalysisResult(
                    functionality: "无法解析代码功能",
                    algorithm: "未能识别算法",
                    suggestions: ["请检查代码格式"],
                    bestPractices: []
                )
            }
            .eraseToAnyPublisher()
    }
    
    // 生成知识图谱
    func generateKnowledgeGraph(from sections: [PaperSection]) -> AnyPublisher<KnowledgeGraphResult, Error> {
        if useSimulatedData {
            return simulateResponse(for: .knowledgeGraph, text: "")
                .map { _ -> KnowledgeGraphResult in
                    return self.createDummyKnowledgeGraph()
                }
                .eraseToAnyPublisher()
        }
        
        let sectionTexts = sections.map { "标题：\($0.title)\n内容：\($0.content)" }.joined(separator: "\n\n")
        let prompt = """
        请分析以下论文章节，生成一个完整的知识图谱，以JSON格式返回：
        {
            "nodes": [
                {"id": "概念1", "type": "concept|method|theory|finding", "importance": 5},
                {"id": "概念2", "type": "concept", "importance": 3}
            ],
            "edges": [
                {"source": "概念1", "target": "概念2", "relationship": "isPartOf|influences|supports|contradicts|references", "strength": 0.8}
            ]
        }
        
        包含10-15个最重要的概念节点，并连接相关的关系边。
        
        论文章节：
        \(sectionTexts)
        """
        
        return sendRequest(prompt: prompt)
            .map { response -> KnowledgeGraphResult in
                do {
                    if let jsonData = response.data(using: .utf8) {
                        return try JSONDecoder().decode(KnowledgeGraphResult.self, from: jsonData)
                    }
                } catch {
                    print("解析知识图谱JSON失败: \(error)")
                }
                // 备用响应
                return self.createDummyKnowledgeGraph()
            }
            .eraseToAnyPublisher()
    }
    
    // 创建备用知识图谱
    private func createDummyKnowledgeGraph() -> KnowledgeGraphResult {
        let nodes = [
            GraphNode(id: "深度学习", type: "concept", importance: 5),
            GraphNode(id: "自然语言处理", type: "concept", importance: 4),
            GraphNode(id: "Transformer", type: "method", importance: 5),
            GraphNode(id: "BERT", type: "method", importance: 4),
            GraphNode(id: "注意力机制", type: "method", importance: 3)
        ]
        
        let edges = [
            GraphEdge(source: "深度学习", target: "自然语言处理", relationship: "influences", strength: 0.9),
            GraphEdge(source: "Transformer", target: "BERT", relationship: "isPartOf", strength: 0.8),
            GraphEdge(source: "注意力机制", target: "Transformer", relationship: "isPartOf", strength: 0.7)
        ]
        
        return KnowledgeGraphResult(nodes: nodes, edges: edges)
    }
    
    // 获取论文的方法分析
    func analyzeMethodology(from text: String) -> AnyPublisher<MethodAnalysisResult, Error> {
        if useSimulatedData {
            return Just(MethodAnalysisResult(
                mainApproach: "深度学习方法",
                datasets: ["MNIST", "CIFAR-10"],
                evaluationMetrics: ["准确率", "F1分数"],
                limitations: ["数据集规模有限", "计算资源需求高"]
            ))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
        }
        
        let prompt = """
        请分析下面论文中使用的研究方法，以JSON格式返回：
        {
            "mainApproach": "主要研究方法",
            "datasets": ["使用的数据集1", "数据集2", ...],
            "evaluationMetrics": ["评估指标1", "评估指标2", ...],
            "limitations": ["方法局限性1", "局限性2", ...]
        }
        
        论文内容：
        \(text)
        """
        
        return sendRequest(prompt: prompt)
            .map { response -> MethodAnalysisResult in
                do {
                    if let jsonData = response.data(using: .utf8) {
                        return try JSONDecoder().decode(MethodAnalysisResult.self, from: jsonData)
                    }
                } catch {
                    print("解析方法分析JSON失败: \(error)")
                }
                // 备用响应
                return MethodAnalysisResult(
                    mainApproach: "无法识别主要方法",
                    datasets: [],
                    evaluationMetrics: [],
                    limitations: ["分析失败"]
                )
            }
            .eraseToAnyPublisher()
    }
    
    // 生成研究问题
    func generateResearchQuestions(from text: String, count: Int = 5) -> AnyPublisher<[String], Error> {
        if useSimulatedData {
            return simulateResponse(for: .researchQuestions, text: text)
                .map { response -> [String] in
                    return response.components(separatedBy: "\n")
                        .filter { !$0.isEmpty }
                        .prefix(count)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .compactMap { line -> String? in
                            // 移除数字前缀
                            if let range = line.range(of: #"^\d+[\.\)\s]+\s*"#, options: .regularExpression) {
                                return String(line[range.upperBound...])
                            }
                            return line
                        }
                }
                .eraseToAnyPublisher()
        }
        
        let prompt = """
        基于以下论文内容，生成\(count)个相关的研究问题，这些问题可以作为未来研究的方向。
        问题应该是具体的、可研究的，并与论文内容直接相关。
        以简单的列表形式返回。
        
        论文内容：
        \(text)
        """
        
        return sendRequest(prompt: prompt)
            .map { response -> [String] in
                return response.components(separatedBy: "\n")
                    .filter { !$0.isEmpty }
                    .prefix(count)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .compactMap { line -> String? in
                        // 移除数字前缀
                        if let range = line.range(of: #"^\d+[\.\)\s]+\s*"#, options: .regularExpression) {
                            return String(line[range.upperBound...])
                        }
                        return line
                    }
            }
            .eraseToAnyPublisher()
    }
    
    // 贡献分析
    func analyzeContributions(from text: String) -> AnyPublisher<ContributionsAnalysisResult, Error> {
        if useSimulatedData {
            return Just(ContributionsAnalysisResult(
                theoretical: ["提出了新的神经网络架构理论"],
                methodological: ["开发了一种新的优化算法"],
                practical: ["提高了20%的模型效率"],
                limitations: ["仅在特定数据集上验证"]
            ))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
        }
        
        let prompt = """
        请分析以下论文的主要学术贡献，以JSON格式返回：
        {
            "theoretical": ["理论贡献1", "理论贡献2", ...],
            "methodological": ["方法贡献1", "方法贡献2", ...],
            "practical": ["实践应用贡献1", "实践应用贡献2", ...],
            "limitations": ["局限性1", "局限性2", ...]
        }
        
        论文内容：
        \(text)
        """
        
        return sendRequest(prompt: prompt)
            .map { response -> ContributionsAnalysisResult in
                do {
                    if let jsonData = response.data(using: .utf8) {
                        return try JSONDecoder().decode(ContributionsAnalysisResult.self, from: jsonData)
                    }
                } catch {
                    print("解析贡献分析JSON失败: \(error)")
                }
                // 备用响应
                return ContributionsAnalysisResult(
                    theoretical: [],
                    methodological: [],
                    practical: [],
                    limitations: ["分析失败"]
                )
            }
            .eraseToAnyPublisher()
    }
    
    // 未来研究方向分析
    func analyzeFutureDirections(from text: String) -> AnyPublisher<FutureDirectionsResult, Error> {
        if useSimulatedData {
            return Just(FutureDirectionsResult(
                shortTerm: ["优化模型参数", "扩展应用场景"],
                longTerm: ["探索多模态融合", "研究模型可解释性"],
                potentialImpact: ["可能彻底改变自然语言处理领域"]
            ))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
        }
        
        let prompt = """
        请基于以下论文内容，分析可能的未来研究方向，以JSON格式返回：
        {
            "shortTerm": ["短期研究方向1", "短期研究方向2", ...],
            "longTerm": ["长期研究方向1", "长期研究方向2", ...],
            "potentialImpact": ["潜在影响1", "潜在影响2", ...]
        }
        
        论文内容：
        \(text)
        """
        
        return sendRequest(prompt: prompt)
            .map { response -> FutureDirectionsResult in
                do {
                    if let jsonData = response.data(using: .utf8) {
                        return try JSONDecoder().decode(FutureDirectionsResult.self, from: jsonData)
                    }
                } catch {
                    print("解析未来方向JSON失败: \(error)")
                }
                // 备用响应
                return FutureDirectionsResult(
                    shortTerm: [],
                    longTerm: [],
                    potentialImpact: ["分析失败"]
                )
            }
            .eraseToAnyPublisher()
    }
    
    // 相关文献分析
    func analyzeLiteratureConnections(paperTitle: String, abstract: String) -> AnyPublisher<LiteratureConnectionsResult, Error> {
        if useSimulatedData {
            return Just(LiteratureConnectionsResult(
                relatedFields: ["计算机视觉", "自然语言处理"],
                keyPapers: [
                    RelatedPaper(title: "Attention Is All You Need", authors: "Vaswani et al.", year: 2017, relationship: "基础工作"),
                    RelatedPaper(title: "BERT: Pre-training of Deep Bidirectional Transformers for Language Understanding", authors: "Devlin et al.", year: 2018, relationship: "相似方法")
                ],
                researchGaps: ["多语言模型训练效率", "小样本学习能力"]
            ))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
        }
        
        let prompt = """
        请分析以下论文标题和摘要，推断其与学术文献的关系，以JSON格式返回：
        {
            "relatedFields": ["相关领域1", "相关领域2", ...],
            "keyPapers": [
                {"title": "相关论文标题", "authors": "作者", "year": 2020, "relationship": "关系描述"},
                ...
            ],
            "researchGaps": ["研究空白1", "研究空白2", ...]
        }
        
        论文标题：\(paperTitle)
        摘要：\(abstract)
        """
        
        return sendRequest(prompt: prompt)
            .map { response -> LiteratureConnectionsResult in
                do {
                    if let jsonData = response.data(using: .utf8) {
                        return try JSONDecoder().decode(LiteratureConnectionsResult.self, from: jsonData)
                    }
                } catch {
                    print("解析文献分析JSON失败: \(error)")
                }
                // 备用响应
                return LiteratureConnectionsResult(
                    relatedFields: [],
                    keyPapers: [],
                    researchGaps: ["分析失败"]
                )
            }
            .eraseToAnyPublisher()
    }
    
    // 获取可用的模型列表
    func getAvailableModels() -> [String] {
        return [
            "deepseek-v3",
            "deepseek-v2",
            "deepseek-coder",
            "deepseek-chat"
        ]
    }
    
    // 更新进度（用于长时间运行的分析任务）
    private func updateProgress(_ value: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.progress = min(1.0, max(0.0, value))
        }
    }
    
    // 模拟响应（用于离线模式）
    private func simulateResponse(for type: AnalysisType, text: String) -> AnyPublisher<String, Error> {
        return Future<String, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                switch type {
                case .summary:
                    promise(.success(self.simulatedSummary))
                case .keyConcepts:
                    promise(.success("[{\"name\":\"Transformer\",\"description\":\"一种基于自注意力机制的神经网络架构\",\"importance\":5},{\"name\":\"BERT\",\"description\":\"双向编码器表示，谷歌开发的预训练语言模型\",\"importance\":5},{\"name\":\"自注意力机制\",\"description\":\"允许模型关注输入序列中的不同部分并捕获长距离依赖\",\"importance\":4},{\"name\":\"微调\",\"description\":\"在预训练模型的基础上针对特定任务进行调整的过程\",\"importance\":3},{\"name\":\"迁移学习\",\"description\":\"将在一个任务上学到的知识应用到另一个相关任务的技术\",\"importance\":3}]"))
                case .codeAnalysis:
                    promise(.success("这段代码实现了一个基于卷积神经网络的图像分类器。主要使用了PyTorch框架，采用了ResNet架构进行特征提取。代码结构清晰，但缺少适当的注释和错误处理。建议添加数据增强步骤以提高模型泛化能力，并考虑使用批量归一化来加速训练。"))
                case .knowledgeGraph:
                    promise(.success("{\"nodes\":[{\"id\":\"深度学习\",\"type\":\"concept\",\"importance\":5},{\"id\":\"自然语言处理\",\"type\":\"concept\",\"importance\":5},{\"id\":\"Transformer\",\"type\":\"method\",\"importance\":5},{\"id\":\"BERT\",\"type\":\"method\",\"importance\":4},{\"id\":\"预训练\",\"type\":\"method\",\"importance\":4}],\"edges\":[{\"source\":\"深度学习\",\"target\":\"自然语言处理\",\"relationship\":\"influences\",\"strength\":0.9},{\"source\":\"Transformer\",\"target\":\"BERT\",\"relationship\":\"isPartOf\",\"strength\":0.8},{\"source\":\"预训练\",\"target\":\"BERT\",\"relationship\":\"isPartOf\",\"strength\":0.7}]}"))
                case .researchQuestions:
                    promise(.success("1. 如何优化Transformer模型以减少计算资源需求？\n2. BERT模型在低资源语言中的效果如何？\n3. 自注意力机制能否应用于多模态学习任务？\n4. 如何有效缓解预训练语言模型中的偏见问题？\n5. 针对特定领域的预训练策略如何影响下游任务性能？"))
                default:
                    promise(.success("模拟数据"))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // 更新sendRequest方法以支持不同的AI服务提供商
    private func sendRequest(prompt: String) -> AnyPublisher<String, Error> {
        // 更新进度状态
        self.isAnalyzing = true
        self.progress = 0.1
        
        // 如果使用模拟数据，返回预设的响应
        if useSimulatedData {
            return simulatedResponse(for: prompt)
        }
        
        guard !apiKey.isEmpty else {
            return Fail(error: AIAnalysisError.missingAPIKey).eraseToAnyPublisher()
        }
        
        // 构建请求URL
        var urlString: String
        switch serviceProvider {
        case .openAI:
            urlString = "\(baseURL)/chat/completions"
        case .tongyi:
            urlString = "\(baseURL)/services/aigc/text-generation/generation"
        case .siliconFlow:
            urlString = "\(baseURL)/chat/completions"
        case .custom:
            urlString = baseURL
        }
        
        guard let url = URL(string: urlString) else {
            return Fail(error: AIAnalysisError.invalidResponse).eraseToAnyPublisher()
        }
        
        // 创建HTTP请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("\(serviceProvider.headerValuePrefix)\(apiKey)", forHTTPHeaderField: serviceProvider.headerName)
        request.timeoutInterval = requestTimeout
        
        // 更新进度
        self.progress = 0.2
        
        // 准备请求主体
        var requestBody: [String: Any]
        
        // 根据不同服务提供商格式化请求
        if serviceProvider == .tongyi && enableKnowledgeBase && !knowledgeBaseId.isEmpty {
            // 通义千问特殊处理 - 添加知识库查询
            requestBody = [
                "model": selectedModel,
                "input": [
                    "messages": [
                        ["role": "system", "content": "你是一个学术论文分析助手，擅长分析学术论文的结构、关键点和见解。回复应使用中文，请提供详细、有条理的分析。"],
                        ["role": "user", "content": prompt]
                    ]
                ],
                "parameters": [
                    "temperature": 0.5,
                    "top_p": 0.8,
                    "max_tokens": 4000,
                    "result_format": "text",
                    "enable_search": true,
                    "knowledge_base_id": knowledgeBaseId
                ]
            ]
        } else {
            requestBody = serviceProvider.formatRequest(prompt: prompt, model: selectedModel)
        }
        
        // 将请求主体转换为JSON数据
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        // 更新进度
        self.progress = 0.3
        
        // 创建和返回发布者
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { [weak self] data, response -> Data in
                self?.progress = 0.7
                return data
            }
            .tryMap { [weak self] data -> String in
                do {
                    let result = try self?.serviceProvider.parseResponse(data: data) ?? ""
                    self?.progress = 0.9
                    return result
                } catch {
                    throw error
                }
            }
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveCompletion: { [weak self] completion in
                self?.isAnalyzing = false
                self?.progress = 1.0
            })
            .eraseToAnyPublisher()
    }
    
    // 重试机制
    func retryLastRequest(with prompt: String, maxRetries: Int = 3) -> AnyPublisher<String, Error> {
        return Deferred {
            var currentRetry = 0
            
            func attemptRequest() -> AnyPublisher<String, Error> {
                return self.sendRequest(prompt: prompt)
                    .catch { (error: Error) -> AnyPublisher<String, Error> in
                        currentRetry += 1
                        
                        // 如果是网络错误或服务器错误且未超过最大重试次数，则重试
                        if currentRetry < maxRetries {
                            if let analysisError = error as? AIAnalysisError {
                                switch analysisError {
                                case .serverError, .invalidResponse, .rateLimitExceeded:
                                    print("重试请求 \(currentRetry)/\(maxRetries)")
                                    // 指数退避策略
                                    let delay = TimeInterval(pow(2.0, Double(currentRetry))) * 0.5
                                    return Just(())
                                        .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
                                        .flatMap { _ in attemptRequest() }
                                        .eraseToAnyPublisher()
                                default:
                                    return Fail(error: error).eraseToAnyPublisher()
                                }
                            }
                        }
                        
                        return Fail(error: error).eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            
            return attemptRequest()
        }
        .eraseToAnyPublisher()
    }
    
    // 批量分析功能
    func batchAnalyze(papers: [Paper], analysisType: AnalysisType) -> AnyPublisher<[Paper.ID: String], Error> {
        let publishers = papers.map { paper -> AnyPublisher<(Paper.ID, String), Error> in
            let text = paper.abstract
            
            let publisher: AnyPublisher<String, Error>
            
            switch analysisType {
            case .summary:
                publisher = generateSummary(from: text)
            case .keyConcepts:
                publisher = extractKeyConcepts(from: text)
                    .map { concepts in
                        concepts.map { "\($0.name): \($0.description)" }.joined(separator: "\n")
                    }
                    .eraseToAnyPublisher()
            case .researchQuestions:
                publisher = generateResearchQuestions(from: text)
                    .map { questions in
                        questions.enumerated().map { index, question in
                            "\(index + 1). \(question)"
                        }.joined(separator: "\n")
                    }
                    .eraseToAnyPublisher()
            default:
                publisher = Just("不支持批量处理此分析类型").setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            
            return publisher
                .map { (paper.id, $0) }
                .eraseToAnyPublisher()
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { results in
                Dictionary(uniqueKeysWithValues: results)
            }
            .eraseToAnyPublisher()
    }
    
    // 将simulatedResponse方法修改为与现有代码保持一致
    private func simulatedResponse(for prompt: String) -> AnyPublisher<String, Error> {
        // 模拟延迟
        self.progress = 0.2
        return Future<String, Error> { [weak self] promise in
            // 模拟网络延迟
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self?.progress = 0.6
                
                // 根据提示返回不同的模拟响应
                if prompt.contains("摘要") {
                    promise(.success(self?.simulatedSummary ?? ""))
                } else if prompt.contains("结构") {
                    promise(.success(self?.simulatedStructure ?? ""))
                } else if prompt.contains("关键点") {
                    promise(.success(self?.simulatedKeyPoints ?? ""))
                } else if prompt.contains("评论") || prompt.contains("分析") {
                    promise(.success(self?.simulatedAnalysis ?? ""))
                } else {
                    promise(.success(self?.simulatedGeneral ?? ""))
                }
                
                self?.progress = 1.0
                self?.isAnalyzing = false
            }
        }.eraseToAnyPublisher()
    }
}

// API响应模型
private struct AIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct AIErrorResponse: Codable {
    struct ErrorDetails: Codable {
        let message: String
        let type: String?
        let param: String?
        let code: String?
    }
    let error: ErrorDetails
}

// 错误类型
enum AIAnalysisError: Error {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case decodingError
    case missingAPIKey
    case authenticationError
    case rateLimitExceeded
    case serverError(Int)
    case serializationError(String)
    case otherError(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .apiError(let message):
            return "API错误: \(message)"
        case .decodingError:
            return "解码错误: 无法解析API响应"
        case .missingAPIKey:
            return "缺少API密钥，请在设置中配置"
        case .authenticationError:
            return "身份验证失败: 请检查API密钥是否有效"
        case .rateLimitExceeded:
            return "超出API速率限制: 请稍后重试"
        case .serverError(let code):
            return "服务器错误 (\(code)): 请稍后重试"
        case .serializationError(let message):
            return "序列化错误: \(message)"
        case .otherError(let message):
            return "其他错误: \(message)"
        }
    }
}

// 数据模型
struct ConceptItem: Codable, Identifiable {
    let name: String
    let description: String
    let importance: Int
    
    var id: String { name }
}

struct CodeAnalysisResult: Codable {
    let functionality: String
    let algorithm: String
    let suggestions: [String]
    let bestPractices: [String]
}

struct GraphNode: Codable, Identifiable {
    let id: String
    let type: String
    let importance: Int
}

struct GraphEdge: Codable, Identifiable {
    let source: String
    let target: String
    let relationship: String
    let strength: Double
    
    var id: String { "\(source)-\(relationship)-\(target)" }
}

struct KnowledgeGraphResult: Codable {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
}

struct MethodAnalysisResult: Codable {
    let mainApproach: String
    let datasets: [String]
    let evaluationMetrics: [String]
    let limitations: [String]
}

struct ContributionsAnalysisResult: Codable {
    let theoretical: [String]
    let methodological: [String]
    let practical: [String]
    let limitations: [String]
}

struct FutureDirectionsResult: Codable {
    let shortTerm: [String]
    let longTerm: [String]
    let potentialImpact: [String]
}

struct RelatedPaper: Codable, Identifiable {
    let title: String
    let authors: String
    let year: Int
    let relationship: String
    
    var id: String { title }
}

struct LiteratureConnectionsResult: Codable {
    let relatedFields: [String]
    let keyPapers: [RelatedPaper]
    let researchGaps: [String]
} 