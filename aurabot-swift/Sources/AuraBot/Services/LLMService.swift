import Foundation

actor LLMService {
    private let config: LLMConfig
    private let session: URLSession
    
    init(config: LLMConfig) {
        self.config = config
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval(config.timeoutSeconds)
        self.session = URLSession(configuration: config)
    }
    
    func analyzeScreen(imageData: Data, context: String) async throws -> AnalysisResult {
        let base64Image = imageData.base64EncodedString()
        
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": "You are a screen analysis assistant. Analyze the screenshot and describe what the user is doing."
            ],
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": "Analyze this screenshot. Context from previous memories: \(context)"
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64Image)"
                        ]
                    ]
                ]
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "max_tokens": config.maxTokens,
            "temperature": config.temperature
        ]
        
        let result = try await makeRequest(body: requestBody)
        return parseAnalysisResult(result)
    }
    
    func generateResponse(message: String, memories: [String]) async throws -> String {
        let context = memories.joined(separator: "\n")
        
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": "You are a helpful assistant with access to the user's memory. Use the provided context to answer questions."
            ],
            [
                "role": "user",
                "content": "Context from user's memories:\n\(context)\n\nUser question: \(message)"
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "max_tokens": config.maxTokens,
            "temperature": config.temperature
        ]
        
        let result = try await makeRequest(body: requestBody)
        return result
    }
    
    func enhancePrompt(prompt: String, memories: [MemoryInfo]) async throws -> EnhancementResult {
        let memoriesText = memories.map { "- [\($0.context)] \($0.content)" }.joined(separator: "\n")
        
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": "Enhance the user's prompt with relevant context from their memory. Keep the original intent but add helpful context."
            ],
            [
                "role": "user",
                "content": """
                Original prompt: \(prompt)
                
                Relevant memories:
                \(memoriesText)
                
                Enhance the prompt with relevant context. Return ONLY the enhanced prompt.
                """
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "max_tokens": config.maxTokens,
            "temperature": 0.5
        ]
        
        let enhanced = try await makeRequest(body: requestBody)
        
        return EnhancementResult(
            originalPrompt: prompt,
            enhancedPrompt: enhanced,
            memoriesUsed: memories.map { $0.content },
            memoryCount: memories.count,
            enhancementType: memories.count > 2 ? "contextual" : memories.count > 0 ? "detailed" : "minimal"
        )
    }
    
    func checkHealth() async -> Bool {
        guard let url = URL(string: "\(config.baseURL)/models") else { return false }
        
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    private func makeRequest(body: [String: Any]) async throws -> String {
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        
        return content
    }
    
    private func parseAnalysisResult(_ text: String) -> AnalysisResult {
        return AnalysisResult(
            summary: text,
            context: "Screen capture",
            activities: ["Working"],
            keyElements: [],
            userIntent: "Productivity"
        )
    }
}
