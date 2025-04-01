import Foundation
import SwiftUI

// 知识图谱节点
struct KnowledgeNode: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var type: NodeType
    var importance: Int // 1-5，表示重要程度
    var pageReferences: [Int] // 在论文中出现的页码
    var relatedConcepts: Set<UUID> // 相关概念的ID
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        type: NodeType = .concept,
        importance: Int = 3,
        pageReferences: [Int] = [],
        relatedConcepts: Set<UUID> = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.importance = max(1, min(5, importance))
        self.pageReferences = pageReferences
        self.relatedConcepts = relatedConcepts
    }
    
    // 节点类型
    enum NodeType: String, Codable, CaseIterable {
        case concept = "concept" // 概念
        case method = "method" // 方法
        case theory = "theory" // 理论
        case finding = "finding" // 发现
        case conclusion = "conclusion" // 结论
        
        var color: Color {
            switch self {
            case .concept:
                return .blue
            case .method:
                return .green
            case .theory:
                return .purple
            case .finding:
                return .orange
            case .conclusion:
                return .red
            }
        }
        
        var icon: String {
            switch self {
            case .concept:
                return "lightbulb"
            case .method:
                return "gear"
            case .theory:
                return "book"
            case .finding:
                return "magnifyingglass"
            case .conclusion:
                return "checkmark.circle"
            }
        }
    }
}

// 知识图谱边
struct KnowledgeEdge: Identifiable, Codable, Hashable {
    let id: UUID
    let sourceId: UUID
    let targetId: UUID
    var relationship: RelationType
    var strength: Double // 0.0-1.0，表示关系强度
    var description: String
    
    init(
        id: UUID = UUID(),
        sourceId: UUID,
        targetId: UUID,
        relationship: RelationType,
        strength: Double = 0.5,
        description: String = ""
    ) {
        self.id = id
        self.sourceId = sourceId
        self.targetId = targetId
        self.relationship = relationship
        self.strength = max(0.0, min(1.0, strength))
        self.description = description
    }
    
    // 关系类型
    enum RelationType: String, Codable, CaseIterable {
        case isPartOf = "isPartOf" // 包含关系
        case influences = "influences" // 影响关系
        case supports = "supports" // 支持关系
        case contradicts = "contradicts" // 矛盾关系
        case references = "references" // 引用关系
        case implements = "implements" // 实现关系
        
        var displayName: String {
            switch self {
            case .isPartOf:
                return "包含"
            case .influences:
                return "影响"
            case .supports:
                return "支持"
            case .contradicts:
                return "矛盾"
            case .references:
                return "引用"
            case .implements:
                return "实现"
            }
        }
        
        var color: Color {
            switch self {
            case .isPartOf:
                return .blue
            case .influences:
                return .purple
            case .supports:
                return .green
            case .contradicts:
                return .red
            case .references:
                return .gray
            case .implements:
                return .orange
            }
        }
    }
}

// 知识图谱
class KnowledgeGraph: ObservableObject {
    @Published private(set) var nodes: [UUID: KnowledgeNode]
    @Published private(set) var edges: [UUID: KnowledgeEdge]
    
    init(nodes: [KnowledgeNode] = [], edges: [KnowledgeEdge] = []) {
        self.nodes = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        self.edges = Dictionary(uniqueKeysWithValues: edges.map { ($0.id, $0) })
    }
    
    // MARK: - 节点操作
    
    func addNode(_ node: KnowledgeNode) {
        nodes[node.id] = node
    }
    
    func updateNode(_ node: KnowledgeNode) {
        nodes[node.id] = node
    }
    
    func removeNode(id: UUID) {
        nodes.removeValue(forKey: id)
        // 删除相关的边
        edges = edges.filter { $0.value.sourceId != id && $0.value.targetId != id }
    }
    
    // MARK: - 边操作
    
    func addEdge(_ edge: KnowledgeEdge) {
        edges[edge.id] = edge
    }
    
    func updateEdge(_ edge: KnowledgeEdge) {
        edges[edge.id] = edge
    }
    
    func removeEdge(id: UUID) {
        edges.removeValue(forKey: id)
    }
    
    // MARK: - 图分析
    
    // 获取节点的所有相邻节点
    func getNeighbors(of nodeId: UUID) -> [KnowledgeNode] {
        let connectedEdges = edges.values.filter { $0.sourceId == nodeId || $0.targetId == nodeId }
        let neighborIds = connectedEdges.flatMap { [$0.sourceId, $0.targetId] }
            .filter { $0 != nodeId }
        return neighborIds.compactMap { nodes[$0] }
    }
    
    // 获取两个节点之间的最短路径
    func shortestPath(from sourceId: UUID, to targetId: UUID) -> [UUID]? {
        var queue = [(nodeId: sourceId, path: [sourceId])]
        var visited = Set<UUID>()
        
        while !queue.isEmpty {
            let (currentId, path) = queue.removeFirst()
            
            if currentId == targetId {
                return path
            }
            
            if visited.contains(currentId) {
                continue
            }
            
            visited.insert(currentId)
            
            for neighbor in getNeighbors(of: currentId) {
                if !visited.contains(neighbor.id) {
                    queue.append((neighbor.id, path + [neighbor.id]))
                }
            }
        }
        
        return nil
    }
    
    // 计算节点的中心性（重要程度）
    func calculateCentrality(of nodeId: UUID) -> Double {
        let allNodes = Set(nodes.keys)
        var totalShortestPaths = 0
        var pathsThroughNode = 0
        
        for source in allNodes {
            for target in allNodes where source != target {
                if let path = shortestPath(from: source, to: target) {
                    totalShortestPaths += 1
                    if path.contains(nodeId) {
                        pathsThroughNode += 1
                    }
                }
            }
        }
        
        return Double(pathsThroughNode) / Double(max(1, totalShortestPaths))
    }
    
    // MARK: - 导入导出
    
    // 导出为JSON
    func exportJSON() throws -> Data {
        let export = KnowledgeGraphExport(
            nodes: Array(nodes.values),
            edges: Array(edges.values)
        )
        return try JSONEncoder().encode(export)
    }
    
    // 从JSON导入
    static func importJSON(_ data: Data) throws -> KnowledgeGraph {
        let import_ = try JSONDecoder().decode(KnowledgeGraphExport.self, from: data)
        return KnowledgeGraph(nodes: import_.nodes, edges: import_.edges)
    }
}

// 用于JSON导入导出的结构
private struct KnowledgeGraphExport: Codable {
    let nodes: [KnowledgeNode]
    let edges: [KnowledgeEdge]
} 