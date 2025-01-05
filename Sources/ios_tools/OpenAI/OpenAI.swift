import Foundation

public class OpenAI {
    private let apiKey: String
    private let baseURL: String
    private let organizationId: String?
    
    public init(apiKey: String, organizationId: String? = nil, baseURL: String = "https://api.openai.com/v1") {
        self.apiKey = apiKey
        self.organizationId = organizationId
        self.baseURL = baseURL
    }
    
    // MARK: - Chat Completion
    
    public func chat(
        messages: [ChatMessage],
        model: String = "gpt-3.5-turbo",
        temperature: Double = 1.0,
        topP: Double = 1.0,
        n: Int = 1,
        stream: Bool = false,
        stop: [String]? = nil,
        maxTokens: Int? = nil,
        presencePenalty: Double = 0,
        frequencyPenalty: Double = 0,
        user: String? = nil
    ) async throws -> ChatCompletionResponse {
        let endpoint = "\(baseURL)/chat/completions"
        
        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { $0.dictionary },
            "temperature": temperature,
            "top_p": topP,
            "n": n,
            "stream": stream,
            "presence_penalty": presencePenalty,
            "frequency_penalty": frequencyPenalty
        ]
        
        if let stop = stop { body["stop"] = stop }
        if let maxTokens = maxTokens { body["max_tokens"] = maxTokens }
        if let user = user { body["user"] = user }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let organizationId = organizationId {
            request.setValue(organizationId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw OpenAIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ChatCompletionResponse.self, from: data)
    }
    
    // MARK: - Chat Completion Stream
    
    public func chatStream(
        messages: [ChatMessage],
        model: String = "gpt-3.5-turbo",
        temperature: Double = 1.0,
        topP: Double = 1.0,
        n: Int = 1,
        stop: [String]? = nil,
        maxTokens: Int? = nil,
        presencePenalty: Double = 0,
        frequencyPenalty: Double = 0,
        user: String? = nil,
        onReceive: @escaping (String) -> Void
    ) async throws {
        let endpoint = "\(baseURL)/chat/completions"
        
        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { $0.dictionary },
            "temperature": temperature,
            "top_p": topP,
            "n": n,
            "stream": true,
            "presence_penalty": presencePenalty,
            "frequency_penalty": frequencyPenalty
        ]
        
        if let stop = stop { body["stop"] = stop }
        if let maxTokens = maxTokens { body["max_tokens"] = maxTokens }
        if let user = user { body["user"] = user }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        if let organizationId = organizationId {
            request.setValue(organizationId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            throw OpenAIError.httpError(statusCode: httpResponse.statusCode, data: errorData)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        var byteArray = [UInt8]()
        var buffer = ""
        
        for try await byte in bytes {
            byteArray.append(byte)
            
            if byte == 10 { // newline character
                if let line = String(bytes: byteArray, encoding: .utf8) {
                    if line.hasPrefix("data: ") {
                        let data = line.dropFirst(6)
                        if data.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                            return
                        }
                        if let jsonData = data.data(using: .utf8),
                           let streamResponse = try? decoder.decode(ChatCompletionStreamResponse.self, from: jsonData),
                           let content = streamResponse.choices.first?.delta.content {
                            onReceive(content)
                        }
                    }
                }
                byteArray.removeAll()
            }
        }
    }
    
    // MARK: - Embeddings
    
    public func embeddings(
        input: [String],
        model: String = "text-embedding-ada-002",
        user: String? = nil
    ) async throws -> EmbeddingResponse {
        let endpoint = "\(baseURL)/embeddings"
        
        var body: [String: Any] = [
            "model": model,
            "input": input
        ]
        
        if let user = user { body["user"] = user }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let organizationId = organizationId {
            request.setValue(organizationId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw OpenAIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(EmbeddingResponse.self, from: data)
    }
}

// MARK: - Models

public struct ChatMessage: Codable {
    public let role: String
    public let content: String
    public let name: String?
    
    public init(role: String, content: String, name: String? = nil) {
        self.role = role
        self.content = content
        self.name = name
    }
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "role": role,
            "content": content
        ]
        if let name = name {
            dict["name"] = name
        }
        return dict
    }
}

public struct ChatCompletionResponse: Codable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [Choice]
    public let usage: Usage
    
    public struct Choice: Codable {
        public let index: Int
        public let message: ChatMessage
        public let finishReason: String?
    }
    
    public struct Usage: Codable {
        public let promptTokens: Int
        public let completionTokens: Int
        public let totalTokens: Int
    }
}

public struct EmbeddingResponse: Codable {
    public let object: String
    public let data: [EmbeddingData]
    public let model: String
    public let usage: Usage
    
    public struct EmbeddingData: Codable {
        public let object: String
        public let embedding: [Double]
        public let index: Int
    }
    
    public struct Usage: Codable {
        public let promptTokens: Int
        public let totalTokens: Int
    }
}

// MARK: - Stream Response Models

public struct ChatCompletionStreamResponse: Codable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [StreamChoice]
    
    public struct StreamChoice: Codable {
        public let index: Int
        public let delta: DeltaMessage
        public let finishReason: String?
    }
    
    public struct DeltaMessage: Codable {
        public let role: String?
        public let content: String?
    }
}

// MARK: - Errors

public enum OpenAIError: Error, CustomStringConvertible {
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    
    public var description: String {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let data):
            if let errorString = String(data: data, encoding: .utf8) {
                return "HTTP error \(statusCode): \(errorString)"
            } else {
                return "HTTP error \(statusCode)"
            }
        }
    }
} 