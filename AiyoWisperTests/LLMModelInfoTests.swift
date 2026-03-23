import Testing
@testable import AiyoWisper

@Suite("LLMModelInfo")
struct LLMModelInfoTests {

    @Test("registry contains 6 known models")
    func registryCount() {
        #expect(LLMModelInfo.registry.count == 6)
    }

    @Test("lookup by name returns correct model")
    func lookupByName() {
        let model = LLMModelInfo.find("gemma3:4b")
        #expect(model != nil)
        #expect(model?.name == "gemma3:4b")
        #expect(model?.description == "Recommended for most tasks")
    }

    @Test("lookup unknown model returns nil")
    func lookupUnknown() {
        let model = LLMModelInfo.find("nonexistent:1b")
        #expect(model == nil)
    }

    @Test("balanced preset returns model-specific defaults")
    func balancedPreset() {
        let params = LLMModelInfo.presetParameters(for: "llama3.2:3b", preset: .balanced)
        #expect(params.temperature == 0.5)
        #expect(params.repeatPenalty == 1.3)
        #expect(params.frequencyPenalty == 0.5)
        #expect(params.maxTokens == 1024)
    }

    @Test("balanced preset for gemma3 has lower repeat penalty than llama3.2")
    func balancedPresetGemma() {
        let params = LLMModelInfo.presetParameters(for: "gemma3:4b", preset: .balanced)
        #expect(params.repeatPenalty == 1.1)
    }

    @Test("fast preset uses low temperature and no penalties")
    func fastPreset() {
        let params = LLMModelInfo.presetParameters(for: "gemma3:4b", preset: .fast)
        #expect(params.temperature == 0.2)
        #expect(params.repeatPenalty == 1.0)
        #expect(params.frequencyPenalty == 0.0)
        #expect(params.maxTokens == 512)
    }

    @Test("creative preset uses higher temperature")
    func creativePreset() {
        let params = LLMModelInfo.presetParameters(for: "gemma3:4b", preset: .creative)
        #expect(params.temperature == 0.7)
        #expect(params.maxTokens == 2048)
    }

    @Test("unknown model uses global balanced defaults")
    func unknownModelPreset() {
        let params = LLMModelInfo.presetParameters(for: "custom:latest", preset: .balanced)
        #expect(params.temperature == Constants.LLM.defaultTemperature)
        #expect(params.repeatPenalty == Constants.LLM.defaultRepeatPenalty)
    }

    @Test("preset enum has three cases")
    func presetCases() {
        let cases: [LLMPreset] = [.fast, .balanced, .creative]
        #expect(cases.count == 3)
    }
}
