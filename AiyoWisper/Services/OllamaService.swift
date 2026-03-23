import Foundation

struct OllamaModel: Sendable {
    let name: String
    let size: Int64
    let modifiedAt: String
}

struct OllamaService: Sendable {
    let baseURL: String

    init(llmEndpoint: String) {
        var url = llmEndpoint
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        if url.hasSuffix("/v1") { url = String(url.dropLast(3)) }
        self.baseURL = url
    }

    func isRunning() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func listModels() async throws -> [OllamaModel] {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            throw OllamaError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OllamaError.requestFailed
        }
        let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return decoded.models.map { OllamaModel(name: $0.name, size: $0.size, modifiedAt: $0.modified_at) }
    }

    func pullModel(name: String, onProgress: @Sendable @escaping (Double) -> Void) async throws {
        guard let url = URL(string: "\(baseURL)/api/pull") else {
            throw OllamaError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["name": name])

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OllamaError.requestFailed
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }
            if let total = json["total"] as? Double, total > 0,
               let completed = json["completed"] as? Double {
                onProgress(completed / total)
            }
        }
    }

    func deleteModel(name: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/delete") else {
            throw OllamaError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["name": name])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OllamaError.requestFailed
        }
    }
}

enum OllamaError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case notRunning

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid Ollama URL"
        case .requestFailed: "Ollama request failed"
        case .notRunning: "Ollama is not running"
        }
    }
}

// MARK: - Response Types

private struct OllamaTagsResponse: Codable {
    struct Model: Codable {
        let name: String
        let size: Int64
        let modified_at: String
    }
    let models: [Model]
}
