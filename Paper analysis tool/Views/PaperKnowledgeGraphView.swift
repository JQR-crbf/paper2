import SwiftUI
import Combine

// 重新实现为使用ObservableObject模式的视图
struct PaperKnowledgeGraphView: View {
    let paper: Paper
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var viewModel = PaperKnowledgeGraphViewModel()
    
    var body: some View {
        VStack {
            if viewModel.graph.nodes.isEmpty {
                // 空状态视图
                emptyStateView
            } else {
                // 知识图谱视图
                KnowledgeGraphView(graph: viewModel.graph)
            }
        }
        .navigationTitle("知识图谱")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        viewModel.showingAddNodeSheet = true
                    }) {
                        Label("添加节点", systemImage: "plus.circle")
                    }
                    
                    Button(action: {
                        if viewModel.graph.nodes.count >= 2 {
                            viewModel.showingAddEdgeSheet = true
                        } else {
                            viewModel.errorMessage = "至少需要两个节点才能创建连接"
                            viewModel.showError = true
                        }
                    }) {
                        Label("添加连接", systemImage: "arrow.triangle.branch")
                    }
                    
                    Button(action: {
                        viewModel.generateKnowledgeGraph(for: paper)
                    }) {
                        Label("AI生成知识图谱", systemImage: "brain")
                    }
                    .disabled(viewModel.isGenerating)
                    
                    Button(action: {
                        viewModel.exportGraph()
                    }) {
                        Label("导出知识图谱", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.graph.nodes.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddNodeSheet) {
            NodeCreationView { newNode in
                viewModel.graph.addNode(newNode)
                viewModel.showingAddNodeSheet = false
            }
        }
        .sheet(isPresented: $viewModel.showingAddEdgeSheet) {
            EdgeCreationView(
                nodes: Array(viewModel.graph.nodes.values),
                onSave: { sourceId, targetId, relationship, strength, description in
                    let edge = KnowledgeEdge(
                        sourceId: sourceId,
                        targetId: targetId,
                        relationship: relationship,
                        strength: strength,
                        description: description
                    )
                    viewModel.graph.addEdge(edge)
                    viewModel.showingAddEdgeSheet = false
                }
            )
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("错误"),
                message: Text(viewModel.errorMessage ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
        .overlay(
            viewModel.isGenerating ? 
                ProgressView("正在生成知识图谱...")
                    .padding()
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(10)
                    .shadow(radius: 10)
                : nil
        )
    }
    
    // MARK: - 视图组件
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 70))
                .foregroundColor(.gray)
            
            Text("没有知识图谱")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("添加节点或使用AI自动生成知识图谱")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 15) {
                Button(action: {
                    viewModel.showingAddNodeSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("手动添加节点")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    viewModel.generateKnowledgeGraph(for: paper)
                }) {
                    HStack {
                        Image(systemName: "brain")
                        Text("AI自动生成知识图谱")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(viewModel.isGenerating ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isGenerating)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .padding()
    }
}

// 视图模型用于管理状态
class PaperKnowledgeGraphViewModel: ObservableObject {
    @Published var graph = KnowledgeGraph()
    @Published var isGenerating = false
    @Published var showingAddNodeSheet = false
    @Published var showingAddEdgeSheet = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var selectedSourceNode: KnowledgeNode?
    @Published var selectedTargetNode: KnowledgeNode?
    
    private var cancellables = Set<AnyCancellable>()
    private let aiService = AIAnalysisService()
    
    // 生成知识图谱
    func generateKnowledgeGraph(for paper: Paper) {
        guard !isGenerating else { return }
        
        isGenerating = true
        
        // 获取论文章节数据
        let sections = paper.sections ?? []
        
        // 调用AI服务生成知识图谱
        aiService.generateKnowledgeGraph(from: sections)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isGenerating = false
                    if case .failure(let error) = completion {
                        self.errorMessage = "知识图谱生成失败: \(error.localizedDescription)"
                        self.showError = true
                    }
                },
                receiveValue: { [weak self] result in
                    guard let self = self else { return }
                    let nodes = self.convertToNodes(from: result.nodes)
                    let edges = self.convertToEdges(from: result.edges, nodeMap: nodes)
                    
                    // 清空现有图谱
                    self.graph = KnowledgeGraph()
                    
                    // 更新图谱
                    for node in nodes.values {
                        self.graph.addNode(node)
                    }
                    
                    for edge in edges {
                        self.graph.addEdge(edge)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // 转换AI生成的节点到知识图谱节点
    private func convertToNodes(from graphNodes: [GraphNode]) -> [String: KnowledgeNode] {
        var nodeMap: [String: KnowledgeNode] = [:]
        
        for graphNode in graphNodes {
            let nodeType = KnowledgeNode.NodeType(rawValue: graphNode.type) ?? .concept
            let node = KnowledgeNode(
                title: graphNode.id,
                description: "由AI生成的概念",
                type: nodeType,
                importance: graphNode.importance,
                pageReferences: []
            )
            nodeMap[graphNode.id] = node
        }
        
        return nodeMap
    }
    
    // 转换AI生成的边到知识图谱边
    private func convertToEdges(from graphEdges: [GraphEdge], nodeMap: [String: KnowledgeNode]) -> [KnowledgeEdge] {
        var edges: [KnowledgeEdge] = []
        
        for graphEdge in graphEdges {
            guard let sourceNode = nodeMap[graphEdge.source],
                  let targetNode = nodeMap[graphEdge.target] else {
                continue
            }
            
            let relationType = KnowledgeEdge.RelationType(rawValue: graphEdge.relationship) ?? .influences
            
            let edge = KnowledgeEdge(
                sourceId: sourceNode.id,
                targetId: targetNode.id,
                relationship: relationType,
                strength: graphEdge.strength,
                description: ""
            )
            
            edges.append(edge)
        }
        
        return edges
    }
    
    // 导出图谱
    func exportGraph() {
        do {
            let data = try graph.exportJSON()
            // 导出逻辑，可以保存到文件或分享
            // ...
        } catch {
            errorMessage = "导出失败: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - 节点创建视图

struct NodeCreationView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    let onSave: (KnowledgeNode) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedType: KnowledgeNode.NodeType = .concept
    @State private var importance = 3
    @State private var pageReferences = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("标题", text: $title)
                    
                    TextEditor(text: $description)
                        .frame(height: 100)
                    
                    Picker("类型", selection: $selectedType) {
                        ForEach(KnowledgeNode.NodeType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(typeDisplayName(type))
                            }.tag(type)
                        }
                    }
                }
                
                Section(header: Text("重要程度")) {
                    Stepper("重要程度: \(importance)", value: $importance, in: 1...5)
                    
                    HStack {
                        ForEach(1...5, id: \.self) { rating in
                            Image(systemName: rating <= importance ? "star.fill" : "star")
                                .foregroundColor(rating <= importance ? .yellow : .gray)
                                .onTapGesture {
                                    importance = rating
                                }
                        }
                    }
                }
                
                Section(header: Text("页码引用")) {
                    TextField("页码，用逗号分隔（如 1,3,5）", text: $pageReferences)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .navigationTitle("添加节点")
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    saveNode()
                }
                .disabled(title.isEmpty)
            )
        }
    }
    
    private func typeDisplayName(_ type: KnowledgeNode.NodeType) -> String {
        switch type {
        case .concept: return "概念"
        case .method: return "方法"
        case .theory: return "理论"
        case .finding: return "发现"
        case .conclusion: return "结论"
        }
    }
    
    private func saveNode() {
        // 解析页码引用
        let pages = pageReferences
            .components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        
        let node = KnowledgeNode(
            title: title,
            description: description,
            type: selectedType,
            importance: importance,
            pageReferences: pages
        )
        
        onSave(node)
    }
}

// MARK: - 边创建视图

struct EdgeCreationView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    let nodes: [KnowledgeNode]
    let onSave: (UUID, UUID, KnowledgeEdge.RelationType, Double, String) -> Void
    
    @State private var selectedSourceIndex = 0
    @State private var selectedTargetIndex = 0
    @State private var selectedRelationship: KnowledgeEdge.RelationType = .influences
    @State private var strength: Double = 0.5
    @State private var description = ""
    
    private var sourceNode: KnowledgeNode {
        nodes[selectedSourceIndex]
    }
    
    private var targetNode: KnowledgeNode {
        nodes[selectedTargetIndex]
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("节点选择")) {
                    Picker("源节点", selection: $selectedSourceIndex) {
                        ForEach(0..<nodes.count, id: \.self) { index in
                            Text(nodes[index].title).tag(index)
                        }
                    }
                    
                    Picker("目标节点", selection: $selectedTargetIndex) {
                        ForEach(0..<nodes.count, id: \.self) { index in
                            Text(nodes[index].title).tag(index)
                        }
                    }
                }
                
                Section(header: Text("关系类型")) {
                    Picker("关系", selection: $selectedRelationship) {
                        ForEach(KnowledgeEdge.RelationType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(DefaultPickerStyle())
                    
                    VStack {
                        Text("关系强度: \(Int(strength * 100))%")
                        Slider(value: $strength)
                    }
                }
                
                Section(header: Text("描述")) {
                    TextEditor(text: $description)
                        .frame(height: 100)
                }
            }
            .navigationTitle("添加连接")
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    onSave(
                        sourceNode.id,
                        targetNode.id,
                        selectedRelationship,
                        strength,
                        description
                    )
                }
                .disabled(selectedSourceIndex == selectedTargetIndex)
            )
        }
    }
}

// MARK: - 预览

struct PaperKnowledgeGraphView_Previews: PreviewProvider {
    static var previews: some View {
        let samplePaper = Paper(
            title: "示例论文",
            authors: ["作者1", "作者2"]
        )
        
        NavigationView {
            PaperKnowledgeGraphView(paper: samplePaper)
                .environmentObject(DataStore())
        }
    }
} 