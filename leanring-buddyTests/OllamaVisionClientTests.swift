import Foundation
import Testing
@testable import leanring_buddy

struct OllamaVisionClientTests {
    @Test func parsesSuccessfulChatResponse() throws {
        let data = Data(#"{"message":{"role":"assistant","content":"  The Settings button is at the top right.  "},"done":true}"#.utf8)

        let text = try OllamaVisionClient.parseResponse(data)

        #expect(text == "The Settings button is at the top right.")
    }

    @Test func surfacesOllamaServerError() throws {
        let data = Data(#"{"error":"model 'missing' not found"}"#.utf8)

        #expect(throws: OllamaVisionClientError.serverError("model 'missing' not found")) {
            try OllamaVisionClient.parseResponse(data)
        }
    }

    @Test func rejectsEmptyModelOutput() throws {
        let data = Data(#"{"message":{"role":"assistant","content":"   "},"done":true}"#.utf8)

        #expect(throws: OllamaVisionClientError.emptyResponse) {
            try OllamaVisionClient.parseResponse(data)
        }
    }

    @Test func rejectsMalformedResponse() throws {
        let data = Data(#"{"message":42}"#.utf8)

        #expect(throws: OllamaVisionClientError.invalidResponse) {
            try OllamaVisionClient.parseResponse(data)
        }
    }
}
