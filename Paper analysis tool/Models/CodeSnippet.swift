//
//  CodeSnippet.swift
//  Paper analysis tool
//
//  Created by AI on 2023/4/2.
//

import Foundation

// 代码片段结构体
public struct CodeSnippet: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var code: String
    public var language: String
    public var pageNumber: Int
    public var paperId: UUID
    
    public init(code: String, language: String, pageNumber: Int, paperId: UUID, id: UUID = UUID()) {
        self.id = id
        self.code = code
        self.language = language
        self.pageNumber = pageNumber
        self.paperId = paperId
    }
    
    public static func == (lhs: CodeSnippet, rhs: CodeSnippet) -> Bool {
        lhs.id == rhs.id
    }
}
