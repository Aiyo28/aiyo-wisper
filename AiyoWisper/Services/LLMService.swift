import Foundation

// MARK: - Errors

enum LLMError: Error, LocalizedError {
    case invalidEndpoint
    case requestFailed(statusCode: Int, message: String)
    case decodingFailed
    case noResponseContent
    case connectionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "Invalid LLM endpoint URL"
        case .requestFailed(let statusCode, let message):
            "LLM request failed (HTTP \(statusCode)): \(message)"
        case .decodingFailed:
            "Failed to decode LLM response"
        case .noResponseContent:
            "LLM response contained no content"
        case .connectionFailed(let error):
            "Failed to connect to LLM server: \(error.localizedDescription)"
        }
    }
}

// MARK: - OpenAI-Compatible API Models

struct ChatMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct ChatCompletionRequest: Codable, Sendable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let max_tokens: Int
    let repeat_penalty: Double?
    let frequency_penalty: Double?
}

struct ChatCompletionResponse: Codable, Sendable {
    struct Choice: Codable, Sendable {
        struct Message: Codable, Sendable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

// MARK: - LLM Service

struct LLMService: Sendable {
    let endpointURL: String
    let modelName: String

    /// Send a chat completion request and return the response content.
    func complete(systemPrompt: String, userPrompt: String, parameters: LLMParameters = LLMParameters()) async throws -> String {
        guard let baseURL = URL(string: endpointURL),
              let url = URL(string: "/chat/completions", relativeTo: baseURL)
        else {
            throw LLMError.invalidEndpoint
        }

        let requestBody = ChatCompletionRequest(
            model: modelName,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userPrompt),
            ],
            temperature: parameters.temperature,
            max_tokens: parameters.maxTokens,
            repeat_penalty: parameters.repeatPenalty > 1.0 ? parameters.repeatPenalty : nil,
            frequency_penalty: parameters.frequencyPenalty > 0.0 ? parameters.frequencyPenalty : nil
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw LLMError.decodingFailed
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            throw LLMError.connectionFailed(urlError)
        } catch {
            throw LLMError.connectionFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.connectionFailed(
                URLError(.badServerResponse)
            )
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        let decoded: ChatCompletionResponse
        do {
            decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw LLMError.decodingFailed
        }

        guard let content = decoded.choices.first?.message.content else {
            throw LLMError.noResponseContent
        }

        return content
    }

    /// Test whether the LLM server is reachable and responds to a simple prompt.
    func testConnection() async -> Bool {
        do {
            _ = try await complete(systemPrompt: "You are a helpful assistant.", userPrompt: "Say hi.")
            return true
        } catch {
            return false
        }
    }
}
