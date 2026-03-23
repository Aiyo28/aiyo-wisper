import Foundation

struct LLMParameters: Sendable {
    let temperature: Double
    let repeatPenalty: Double
    let frequencyPenalty: Double
    let maxTokens: Int

    init(
        temperature: Double = Constants.LLM.defaultTemperature,
        repeatPenalty: Double = Constants.LLM.defaultRepeatPenalty,
        frequencyPenalty: Double = Constants.LLM.defaultFrequencyPenalty,
        maxTokens: Int = Constants.LLM.defaultMaxTokens
    ) {
        self.temperature = temperature
        self.repeatPenalty = repeatPenalty
        self.frequencyPenalty = frequencyPenalty
        self.maxTokens = maxTokens
    }
}
