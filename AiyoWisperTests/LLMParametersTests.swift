import Testing
@testable import AiyoWisper

@Suite("LLMParameters")
struct LLMParametersTests {

    @Test("default values match Balanced preset for llama3.2:3b")
    func defaultValues() {
        let params = LLMParameters()
        #expect(params.temperature == 0.5)
        #expect(params.repeatPenalty == 1.3)
        #expect(params.frequencyPenalty == 0.5)
        #expect(params.maxTokens == 1024)
    }

    @Test("custom values are preserved")
    func customValues() {
        let params = LLMParameters(
            temperature: 0.7,
            repeatPenalty: 1.5,
            frequencyPenalty: 0.8,
            maxTokens: 2048
        )
        #expect(params.temperature == 0.7)
        #expect(params.repeatPenalty == 1.5)
        #expect(params.frequencyPenalty == 0.8)
        #expect(params.maxTokens == 2048)
    }

    @Test("is Sendable")
    func sendable() {
        let params = LLMParameters()
        let _: any Sendable = params
    }
}
