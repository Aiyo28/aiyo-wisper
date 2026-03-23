import Testing
@testable import AiyoWisper

@Suite("OllamaService")
struct OllamaServiceTests {

    @Test("derives base URL by stripping /v1 suffix")
    func deriveBaseURL() {
        let service = OllamaService(llmEndpoint: "http://localhost:11434/v1")
        #expect(service.baseURL == "http://localhost:11434")
    }

    @Test("derives base URL when no /v1 suffix")
    func deriveBaseURLNoSuffix() {
        let service = OllamaService(llmEndpoint: "http://localhost:11434")
        #expect(service.baseURL == "http://localhost:11434")
    }

    @Test("derives base URL strips trailing slash before /v1")
    func deriveBaseURLTrailingSlash() {
        let service = OllamaService(llmEndpoint: "http://localhost:11434/v1/")
        #expect(service.baseURL == "http://localhost:11434")
    }
}
