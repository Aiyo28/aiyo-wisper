import Foundation

enum LLMPreset: String, Codable, Sendable, CaseIterable {
    case fast
    case balanced
    case creative
}

struct LLMModelInfo: Sendable {
    let name: String
    let size: String
    let description: String
    let balancedParams: LLMParameters

    static func find(_ name: String) -> LLMModelInfo? {
        registry.first { $0.name == name }
    }

    static func presetParameters(for modelName: String, preset: LLMPreset) -> LLMParameters {
        let balanced = find(modelName)?.balancedParams ?? LLMParameters()

        switch preset {
        case .fast:
            return LLMParameters(
                temperature: 0.2,
                repeatPenalty: 1.0,
                frequencyPenalty: 0.0,
                maxTokens: 512
            )
        case .balanced:
            return balanced
        case .creative:
            return LLMParameters(
                temperature: 0.7,
                repeatPenalty: 1.1,
                frequencyPenalty: 0.2,
                maxTokens: 2048
            )
        }
    }

    static let registry: [LLMModelInfo] = [
        LLMModelInfo(
            name: "llama3.2:3b",
            size: "2.0 GB",
            description: "Fast, good for simple commands",
            balancedParams: LLMParameters(temperature: 0.5, repeatPenalty: 1.3, frequencyPenalty: 0.5, maxTokens: 1024)
        ),
        LLMModelInfo(
            name: "gemma3:4b",
            size: "2.3 GB",
            description: "Recommended for most tasks",
            balancedParams: LLMParameters(temperature: 0.5, repeatPenalty: 1.1, frequencyPenalty: 0.3, maxTokens: 1024)
        ),
        LLMModelInfo(
            name: "phi-4-mini",
            size: "2.2 GB",
            description: "Strong reasoning",
            balancedParams: LLMParameters(temperature: 0.4, repeatPenalty: 1.1, frequencyPenalty: 0.3, maxTokens: 1024)
        ),
        LLMModelInfo(
            name: "llama3.1:8b",
            size: "4.7 GB",
            description: "Best quality, slower",
            balancedParams: LLMParameters(temperature: 0.5, repeatPenalty: 1.1, frequencyPenalty: 0.2, maxTokens: 2048)
        ),
        LLMModelInfo(
            name: "qwen2.5:7b",
            size: "4.4 GB",
            description: "Multilingual",
            balancedParams: LLMParameters(temperature: 0.5, repeatPenalty: 1.1, frequencyPenalty: 0.3, maxTokens: 1024)
        ),
        LLMModelInfo(
            name: "mistral:7b",
            size: "4.1 GB",
            description: "Versatile all-rounder",
            balancedParams: LLMParameters(temperature: 0.5, repeatPenalty: 1.1, frequencyPenalty: 0.3, maxTokens: 1024)
        ),
    ]
}
