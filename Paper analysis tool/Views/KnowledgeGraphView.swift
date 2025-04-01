import SwiftUI
import Foundation

struct KnowledgeGraphView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var graph: KnowledgeGraph
    @State private var selectedNode: KnowledgeNode?
    @State private var selectedEdge: KnowledgeEdge?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingNodeEditor = false
    @State private var showingEdgeEditor = false
    
    // 布局参数
    private let nodeSize: CGFloat = 100
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 2.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                Color(.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                // 图谱内容
                graphContent(in: geometry.size)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(dragGesture)
                    .gesture(magnificationGesture)
                
                // 工具栏
                VStack {
                    toolbar
                    Spacer()
                    if let node = selectedNode {
                        nodeDetailView(node)
                    }
                }
            }
        }
        .sheet(isPresented: $showingNodeEditor) {
            if let node = selectedNode {
                NodeEditorView(node: node) { updatedNode in
                    graph.updateNode(updatedNode)
                }
            }
        }
        .sheet(isPresented: $showingEdgeEditor) {
            if let edge = selectedEdge {
                EdgeEditorView(edge: edge) { updatedEdge in
                    graph.updateEdge(updatedEdge)
                }
            }
        }
        .navigationBarItems(leading:
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
            }
        )
    }
    
    // MARK: - 子视图
    
    private func graphContent(in size: CGSize) -> some View {
        ZStack {
            // 绘制边
            ForEach(Array(graph.edges.values)) { edge in
                EdgeView(edge: edge, nodes: graph.nodes)
                    .onTapGesture {
                        selectedEdge = edge
                        showingEdgeEditor = true
                    }
            }
            
            // 绘制节点
            ForEach(Array(graph.nodes.values)) { node in
                NodeView(node: node)
                    .position(nodePosition(for: node.id, in: size))
                    .onTapGesture {
                        selectedNode = node
                    }
            }
        }
    }
    
    private var toolbar: some View {
        HStack {
            Button(action: resetView) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button(action: { scale = min(maxScale, scale * 1.2) }) {
                Image(systemName: "plus.magnifyingglass")
                    .foregroundColor(.primary)
            }
            
            Button(action: { scale = max(minScale, scale / 1.2) }) {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button(action: exportGraph) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
    }
    
    private func nodeDetailView(_ node: KnowledgeNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(node.title)
                .font(.headline)
            
            Text(node.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                let starCount = min(5, node.importance)
                ForEach(0..<starCount, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            
            Text("页码引用：\(node.pageReferences.map(String.init).joined(separator: ", "))")
                .font(.caption)
            
            HStack {
                Button("编辑") {
                    showingNodeEditor = true
                }
                
                Spacer()
                
                Button("删除") {
                    graph.removeNode(id: node.id)
                    selectedNode = nil
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding()
    }
    
    // MARK: - 手势
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                }
                offset = CGSize(
                    width: offset.width + value.translation.width,
                    height: offset.height + value.translation.height
                )
            }
            .onEnded { _ in
                isDragging = false
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = scale * value
                scale = min(maxScale, max(minScale, newScale))
            }
    }
    
    // MARK: - 辅助方法
    
    private func nodePosition(for id: UUID, in size: CGSize) -> CGPoint {
        // 使用力导向算法计算节点位置
        // 这里使用简化版本，实际应用中应该使用更复杂的布局算法
        let index = Array(graph.nodes.keys).firstIndex(of: id) ?? 0
        let angle = 2 * .pi * Double(index) / Double(graph.nodes.count)
        let radius = min(size.width, size.height) * 0.4
        
        return CGPoint(
            x: size.width / 2 + Foundation.cos(angle) * radius,
            y: size.height / 2 + Foundation.sin(angle) * radius
        )
    }
    
    private func resetView() {
        withAnimation {
            scale = 1.0
            offset = .zero
        }
    }
    
    private func exportGraph() {
        do {
            _ = try graph.exportJSON()
            // 这里可以添加导出到文件或分享的逻辑
        } catch {
            print("导出失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - 辅助视图

struct NodeView: View {
    let node: KnowledgeNode
    
    var body: some View {
        VStack {
            Image(systemName: node.type.icon)
                .font(.system(size: 30))
                .foregroundColor(.white)
            
            Text(node.title)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80, height: 80)
        .background(node.type.color)
        .cornerRadius(40)
        .shadow(radius: 5)
    }
}

struct EdgeView: View {
    let edge: KnowledgeEdge
    let nodes: [UUID: KnowledgeNode]
    
    var body: some View {
        GeometryReader { geometry in
            if let sourceNode = nodes[edge.sourceId],
               let targetNode = nodes[edge.targetId],
               let sourcePt = nodePosition(for: sourceNode.id, in: geometry.size),
               let targetPt = nodePosition(for: targetNode.id, in: geometry.size) {
                Path { path in
                    path.move(to: sourcePt)
                    path.addLine(to: targetPt)
                }
                .stroke(edge.relationship.color, lineWidth: edge.strength * 3)
            }
        }
    }
    
    private func nodePosition(for id: UUID, in size: CGSize) -> CGPoint? {
        // 使用与KnowledgeGraphView相同的布局算法
        guard let index = Array(nodes.keys).firstIndex(of: id) else { return nil }
        let angle = 2 * .pi * Double(index) / Double(nodes.count)
        let radius = min(size.width, size.height) * 0.4
        
        return CGPoint(
            x: size.width / 2 + Foundation.cos(angle) * radius,
            y: size.height / 2 + Foundation.sin(angle) * radius
        )
    }
}

// MARK: - 编辑器视图

struct NodeEditorView: View {
    let node: KnowledgeNode
    let onSave: (KnowledgeNode) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var title: String
    @State private var description: String
    @State private var type: KnowledgeNode.NodeType
    @State private var importance: Int
    @State private var pageReferences: String
    
    init(node: KnowledgeNode, onSave: @escaping (KnowledgeNode) -> Void) {
        self.node = node
        self.onSave = onSave
        _title = State(initialValue: node.title)
        _description = State(initialValue: node.description)
        _type = State(initialValue: node.type)
        _importance = State(initialValue: node.importance)
        _pageReferences = State(initialValue: node.pageReferences.map(String.init).joined(separator: ", "))
    }
    
    // 主视图
    var body: some View {
        NavigationView {
            nodeForm
        }
    }
    
    // 将表单分解为单独的计算属性
    private var nodeForm: some View {
        Form {
            basicInfoSection
            importanceSection
            pageReferencesSection
        }
        .navigationTitle("编辑节点")
        .navigationBarItems(leading: cancelButton, trailing: saveButton)
    }
    
    // 基本信息部分
    private var basicInfoSection: some View {
        VStack(alignment: .leading) {
            Text("基本信息").font(.headline)
            TextField("标题", text: $title)
            TextEditor(text: $description)
                .frame(height: 100)
            Picker("类型", selection: $type) {
                ForEach(KnowledgeNode.NodeType.allCases, id: \.self) { type in
                    Label(type.rawValue.capitalized, systemImage: type.icon)
                        .tag(type)
                }
            }
        }
    }
    
    // 重要程度部分
    private var importanceSection: some View {
        VStack(alignment: .leading) {
            Text("重要程度").font(.headline)
            Stepper("重要程度: \(importance)", value: $importance, in: 1...5)
        }
    }
    
    // 页码引用部分
    private var pageReferencesSection: some View {
        VStack(alignment: .leading) {
            Text("页码引用").font(.headline)
            TextField("页码（用逗号分隔）", text: $pageReferences)
        }
    }
    
    // 取消按钮
    private var cancelButton: some View {
        Button("取消") {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // 保存按钮
    private var saveButton: some View {
        Button("保存") {
            saveNode()
        }
    }
    
    // 保存节点的方法
    private func saveNode() {
        // 将复杂表达式分解为多个步骤
        let pageNumberStrings = pageReferences.components(separatedBy: ",")
        let pageNumbers = pageNumberStrings.compactMap { 
            Int($0.trimmingCharacters(in: .whitespaces)) 
        }
        
        let updatedNode = KnowledgeNode(
            id: node.id,
            title: title,
            description: description,
            type: type,
            importance: importance,
            pageReferences: pageNumbers,
            relatedConcepts: node.relatedConcepts
        )
        onSave(updatedNode)
        presentationMode.wrappedValue.dismiss()
    }
}

struct EdgeEditorView: View {
    let edge: KnowledgeEdge
    let onSave: (KnowledgeEdge) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var relationship: KnowledgeEdge.RelationType
    @State private var strength: Double
    @State private var description: String
    
    init(edge: KnowledgeEdge, onSave: @escaping (KnowledgeEdge) -> Void) {
        self.edge = edge
        self.onSave = onSave
        _relationship = State(initialValue: edge.relationship)
        _strength = State(initialValue: edge.strength)
        _description = State(initialValue: edge.description)
    }
    
    // 主视图
    var body: some View {
        NavigationView {
            edgeForm
        }
    }
    
    // 将表单分解为单独的计算属性
    private var edgeForm: some View {
        Form {
            relationshipTypeSection
            strengthSection
            descriptionSection
        }
        .navigationTitle("编辑关系")
        .navigationBarItems(leading: cancelButton, trailing: saveButton)
    }
    
    // 关系类型部分
    private var relationshipTypeSection: some View {
        VStack(alignment: .leading) {
            Text("关系类型").font(.headline)
            Picker("类型", selection: $relationship) {
                ForEach(KnowledgeEdge.RelationType.allCases, id: \.self) { type in
                    Text(type.displayName)
                        .tag(type)
                }
            }
        }
    }
    
    // 关系强度部分
    private var strengthSection: some View {
        VStack(alignment: .leading) {
            Text("关系强度").font(.headline)
            Slider(value: $strength, in: 0...1, step: 0.1)
            Text("强度: \(Int(strength * 100))%")
        }
    }
    
    // 描述部分
    private var descriptionSection: some View {
        VStack(alignment: .leading) {
            Text("描述").font(.headline)
            TextEditor(text: $description)
                .frame(height: 100)
        }
    }
    
    // 取消按钮
    private var cancelButton: some View {
        Button("取消") {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // 保存按钮
    private var saveButton: some View {
        Button("保存") {
            saveEdge()
        }
    }
    
    // 保存关系的方法
    private func saveEdge() {
        let updatedEdge = KnowledgeEdge(
            id: edge.id,
            sourceId: edge.sourceId,
            targetId: edge.targetId,
            relationship: relationship,
            strength: strength,
            description: description
        )
        onSave(updatedEdge)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - 预览
struct KnowledgeGraphView_Previews: PreviewProvider {
    static var previews: some View {
        let graph = KnowledgeGraph(
            nodes: [
                KnowledgeNode(
                    title: "机器学习",
                    description: "计算机系统通过经验自动改进的能力",
                    type: .concept,
                    importance: 5,
                    pageReferences: [1, 2, 3]
                ),
                KnowledgeNode(
                    title: "深度学习",
                    description: "基于深层神经网络的机器学习方法",
                    type: .method,
                    importance: 4,
                    pageReferences: [4, 5]
                )
            ],
            edges: [
                KnowledgeEdge(
                    sourceId: UUID(),
                    targetId: UUID(),
                    relationship: .isPartOf,
                    strength: 0.8,
                    description: "深度学习是机器学习的一个子领域"
                )
            ]
        )
        
        return KnowledgeGraphView(graph: graph)
    }
} 