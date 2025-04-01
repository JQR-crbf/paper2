import Foundation

enum AIServiceProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case tongyi = "通义千问"
    case siliconFlow = "硅基流动"
    case custom = "自定义"
    
    var id: String { self.rawValue }
    
    var defaultEndpoint: String {
        switch self {
        case .openAI:
            return "https://api.openai.com/v1"
        case .tongyi:
            return "https://dashscope.aliyuncs.com/api/v1"
        case .siliconFlow:
            return "https://cloud.siliconflow.cn/api/v1"
        case .custom:
            return ""
        }
    }
    
    var defaultModel: String {
        switch self {
        case .openAI:
            return "gpt-4"
        case .tongyi:
            return "qwen-max"
        case .siliconFlow:
            return "deepseek-v3"
        case .custom:
            return ""
        }
    }
    
    var headerName: String {
        switch self {
        case .openAI:
            return "Authorization"
        case .tongyi:
            return "Authorization"
        case .siliconFlow:
            return "Authorization"
        case .custom:
            return "Authorization"
        }
    }
    
    var headerValuePrefix: String {
        switch self {
        case .openAI:
            return "Bearer "
        case .tongyi:
            return "Bearer "
        case .siliconFlow:
            return "Bearer "
        case .custom:
            return "Bearer "
        }
    }
    
    func formatRequest(prompt: String, model: String) -> [String: Any] {
        switch self {
        case .openAI:
            return [
                "model": model,
                "messages": [
                    ["role": "system", "content": "你是一个学术论文分析助手。"],
                    ["role": "user", "content": prompt]
                ],
                "temperature": 0.7
            ]
        case .tongyi:
            return [
                "model": model,
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
                    "result_format": "text"
                ]
            ]
        case .siliconFlow:
            return [
                "model": model,
                "messages": [
                    ["role": "system", "content": "你是一个学术论文分析助手，擅长分析学术论文并提供见解。回复应使用中文，并严格按照要求的格式返回。"],
                    ["role": "user", "content": prompt]
                ],
                "temperature": 0.3,
                "max_tokens": 3000,
                "top_p": 0.95,
                "stream": false
            ]
        case .custom:
            return [
                "model": model,
                "messages": [
                    ["role": "system", "content": "你是一个学术论文分析助手。"],
                    ["role": "user", "content": prompt]
                ],
                "temperature": 0.7
            ]
        }
    }
    
    func parseResponse(data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        
        switch self {
        case .openAI:
            guard let choices = json?["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIError.invalidResponse
            }
            return content
            
        case .tongyi:
            guard let output = json?["output"] as? [String: Any],
                  let text = output["text"] as? String else {
                if let response = json?["response"] as? String {
                    return response
                }
                throw AIError.invalidResponse
            }
            return text
            
        case .siliconFlow:
            guard let choices = json?["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIError.invalidResponse
            }
            return content
            
        case .custom:
            // 默认尝试OpenAI格式，用户可能需要在设置中指定如何解析
            guard let choices = json?["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIError.invalidResponse
            }
            return content
        }
    }
}

enum AIError: Error {
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case missingCredentials
    
    var localizedDescription: String {
        switch self {
        case .invalidResponse:
            return "无效的AI响应格式"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .apiError(let message):
            return "API错误: \(message)"
        case .missingCredentials:
            return "缺少API密钥或端点设置"
        }
    }
} 