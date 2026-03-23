import Foundation
import Testing
@testable import AiyoWisper

@Suite("ChatCompletionRequest encoding")
struct ChatCompletionRequestTests {

    @Test("encodes repeat_penalty and frequency_penalty when set")
    func encodesNewFields() throws {
        let request = ChatCompletionRequest(
            model: "test",
            messages: [ChatMessage(role: "user", content: "hi")],
            temperature: 0.5,
            max_tokens: 1024,
            repeat_penalty: 1.3,
            frequency_penalty: 0.5
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["repeat_penalty"] as? Double == 1.3)
        #expect(json["frequency_penalty"] as? Double == 0.5)
    }

    @Test("omits repeat_penalty and frequency_penalty when nil")
    func omitsNilFields() throws {
        let request = ChatCompletionRequest(
            model: "test",
            messages: [ChatMessage(role: "user", content: "hi")],
            temperature: 0.5,
            max_tokens: 1024,
            repeat_penalty: nil,
            frequency_penalty: nil
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["repeat_penalty"] == nil)
        #expect(json["frequency_penalty"] == nil)
    }

    @Test("preserves existing fields")
    func preservesExistingFields() throws {
        let request = ChatCompletionRequest(
            model: "llama3.2:3b",
            messages: [
                ChatMessage(role: "system", content: "sys"),
                ChatMessage(role: "user", content: "usr"),
            ],
            temperature: 0.3,
            max_tokens: 2048,
            repeat_penalty: nil,
            frequency_penalty: nil
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["model"] as? String == "llama3.2:3b")
        #expect(json["temperature"] as? Double == 0.3)
        #expect(json["max_tokens"] as? Int == 2048)
    }
}
