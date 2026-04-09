import Foundation

struct LLMParameters: Sendable {
    let temperature: Double
    let maxTokens: Int

    init(
        temperature: Double = Constants.LLM.defaultTemperature,
        maxTokens: Int = Constants.LLM.defaultMaxTokens
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}
