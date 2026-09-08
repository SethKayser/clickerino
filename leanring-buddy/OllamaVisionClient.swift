//
//  OllamaVisionClient.swift
//  leanring-buddy
//
//  Local vision inference through Ollama's chat API.
//

import Foundation

protocol CompanionVisionProvider: AnyObject {
    var model: String { get set }
    var lastDoneReason: String? { get }
    func listModels() async throws -> [String]
    func analyzeImageStreaming(
        images: [(data: Data, label: String)],
        systemPrompt: String,
        conversationHistory: [(userPlaceholder: String, assistantResponse: String)],
        userPrompt: String,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> (text: String, duration: TimeInterval)
}

enum OllamaVisionClientError: LocalizedError, Equatable {
    case connectionFailed(endpoint: String, reason: String)
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case serverError(String)
    case emptyResponse
    case requestTimedOut

    var errorDescription: String? {
        switch self {
        case let .connectionFailed(endpoint, reason):
            return "Could not connect to Ollama at \(endpoint). Make sure Ollama is running. \(reason)"
        case .invalidResponse:
            return "Ollama returned an invalid HTTP response."
        case let .httpError(statusCode, message):
            return "Ollama request failed (HTTP \(statusCode)): \(message)"
        case let .serverError(message):
            return "Ollama could not complete the request: \(message)"
        case .emptyResponse:
            return "Ollama returned an empty response. Check that the configured model supports images."
        case .requestTimedOut:
            return "Ollama took too long to respond."
        }
    }
}

/// Sends screenshots and conversation context to a locally running Ollama server.
///
/// Runtime configuration can be supplied through the app bundle using:
/// - `OLLAMA_API_URL` (defaults to `http://127.0.0.1:11434/api/chat`)
/// - `OLLAMA_VISION_MODEL` (defaults to `gemma3:4b`)
final class OllamaVisionClient: CompanionVisionProvider {
    static let defaultEndpoint = URL(string: "http://127.0.0.1:11434/api/chat")!
    static let defaultModel = "gemma3:4b"

    let endpoint: URL
    var model: String
    private(set) var lastDoneReason: String?

    private let session: URLSession

    init(
        endpoint: URL? = nil,
        model: String? = nil,
        session: URLSession? = nil
    ) {
        self.endpoint = endpoint ?? Self.configuredEndpoint
        self.model = model ?? AppBundleConfiguration.stringValue(forKey: "OLLAMA_VISION_MODEL") ?? Self.defaultModel
        self.lastDoneReason = nil

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 180
            configuration.timeoutIntervalForResource = 300
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
    }

    /// Non-streaming request with the same inputs used by Clicky's existing vision client.
    func analyzeImage(
        images: [(data: Data, label: String)],
        systemPrompt: String,
        conversationHistory: [(userPlaceholder: String, assistantResponse: String)] = [],
        userPrompt: String
    ) async throws -> (text: String, duration: TimeInterval) {
        let startedAt = Date()
        lastDoneReason = nil
        var messages: [ChatMessage] = [
            ChatMessage(role: "system", content: systemPrompt, images: nil)
        ]

        for exchange in conversationHistory {
            messages.append(ChatMessage(role: "user", content: exchange.userPlaceholder, images: nil))
            messages.append(ChatMessage(role: "assistant", content: exchange.assistantResponse, images: nil))
        }

        let labels = images.enumerated().map { index, image in
            "Screenshot \(index + 1): \(image.label)"
        }
        // The Qwen thinking tag may still exhaust its budget with this directive.
        // Keep the hint for compatibility; always validate non-empty content.
        let currentContent = (labels + [userPrompt, "/no_think"]).joined(separator: "\n\n")
        messages.append(ChatMessage(
            role: "user",
            content: currentContent,
            images: images.isEmpty ? nil : images.map { $0.data.base64EncodedString() }
        ))

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatRequest(
            model: model,
            messages: messages,
            stream: false,
            options: ChatOptions(numPredict: 512, temperature: 0.2)
        ))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError where error.code == .timedOut {
            throw OllamaVisionClientError.requestTimedOut
        } catch {
            throw OllamaVisionClientError.connectionFailed(
                endpoint: endpoint.absoluteString,
                reason: error.localizedDescription
            )
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaVisionClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = Self.serverMessage(from: data)
                ?? String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "No error details were returned."
            throw OllamaVisionClientError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        lastDoneReason = Self.doneReason(from: data)
        let parsedResponse = try Self.parseResponseDetails(data)
        lastDoneReason = parsedResponse.doneReason
        let text = parsedResponse.text
        return (text: text, duration: Date().timeIntervalSince(startedAt))
    }

    func listModels() async throws -> [String] {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.path = "/api/tags"
        guard let modelsURL = components?.url else { throw OllamaVisionClientError.invalidResponse }
        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError { throw CancellationError() }
        guard let httpResponse = response as? HTTPURLResponse else { throw OllamaVisionClientError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw OllamaVisionClientError.httpError(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(ModelTagsResponse.self, from: data).models.map(\.name)
    }

    /// Compatibility helper for the current companion flow. Ollama still receives a
    /// non-streaming request; the completed response is delivered as one UI update.
    func analyzeImageStreaming(
        images: [(data: Data, label: String)],
        systemPrompt: String,
        conversationHistory: [(userPlaceholder: String, assistantResponse: String)] = [],
        userPrompt: String,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> (text: String, duration: TimeInterval) {
        let result = try await analyzeImage(
            images: images,
            systemPrompt: systemPrompt,
            conversationHistory: conversationHistory,
            userPrompt: userPrompt
        )
        await onTextChunk(result.text)
        return result
    }

    static func parseResponse(_ data: Data) throws -> String {
        try parseResponseDetails(data).text
    }

    static func parseResponseDetails(_ data: Data) throws -> (text: String, doneReason: String?) {
        let response: ChatResponse
        do {
            response = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw OllamaVisionClientError.invalidResponse
        }

        if let error = response.error?.trimmingCharacters(in: .whitespacesAndNewlines), !error.isEmpty {
            throw OllamaVisionClientError.serverError(error)
        }

        guard let text = response.message?.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw OllamaVisionClientError.emptyResponse
        }
        return (text: text, doneReason: response.doneReason)
    }

    static func doneReason(from data: Data) -> String? {
        (try? JSONDecoder().decode(ChatResponse.self, from: data))?.doneReason
    }

    private static var configuredEndpoint: URL {
        guard let configuredValue = AppBundleConfiguration.stringValue(forKey: "OLLAMA_API_URL"),
              let configuredURL = URL(string: configuredValue),
              let scheme = configuredURL.scheme,
              scheme == "http" || scheme == "https" else {
            return defaultEndpoint
        }
        return configuredURL
    }

    private static func serverMessage(from data: Data) -> String? {
        (try? JSONDecoder().decode(ChatResponse.self, from: data))?.error
    }
}

private extension OllamaVisionClient {
    struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let stream: Bool
        let options: ChatOptions
    }

    struct ChatOptions: Encodable {
        let numPredict: Int
        let temperature: Double

        enum CodingKeys: String, CodingKey {
            case numPredict = "num_predict"
            case temperature
        }
    }

    struct ChatMessage: Codable {
        let role: String
        let content: String
        let images: [String]?
    }

    struct ChatResponse: Decodable {
        let message: ChatMessage?
        let error: String?
        let doneReason: String?

        enum CodingKeys: String, CodingKey {
            case message, error
            case doneReason = "done_reason"
        }
    }

    struct ModelTagsResponse: Decodable {
        struct Model: Decodable { let name: String }
        let models: [Model]
    }
}
