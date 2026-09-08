import Foundation
import CoreGraphics
import Testing
@testable import Clicky

@MainActor
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

    @Test func exposesTimeoutAsActionableClientError() {
        #expect(OllamaVisionClientError.requestTimedOut.errorDescription?.contains("too long") == true)
    }

    @Test func parsesPointTagAndRemovesItFromSpokenText() {
        let result = CompanionManager.parsePointingCoordinates(
            from: "open the settings menu. [POINT:320, 144:settings:screen2]"
        )

        #expect(result.spokenText == "open the settings menu.")
        #expect(result.coordinate == CGPoint(x: 320, y: 144))
        #expect(result.elementLabel == "settings")
        #expect(result.screenNumber == 2)
    }

    @Test func parsesNoPointTagWithoutChangingSpokenText() {
        let result = CompanionManager.parsePointingCoordinates(
            from: "that is a general question. [POINT:none]"
        )

        #expect(result.spokenText == "that is a general question.")
        #expect(result.coordinate == nil)
        #expect(result.elementLabel == "none")
        #expect(result.screenNumber == nil)
    }

    @Test func leavesMalformedPointTagInSpokenText() {
        let response = "look near the button [POINT:320,144:button"
        let result = CompanionManager.parsePointingCoordinates(from: response)

        #expect(result.spokenText == "look near the button")
        #expect(result.coordinate == nil)
    }

    @Test func preservesDoneReasonForDiagnostics() throws {
        let data = Data(#"{"message":{"role":"assistant","content":"answer"},"done_reason":"length"}"#.utf8)
        let details = try OllamaVisionClient.parseResponseDetails(data)

        #expect(details.text == "answer")
        #expect(details.doneReason == "length")
        #expect(OllamaVisionClient.doneReason(from: data) == "length")
    }

    @Test func typedPromptNormalizationAndCancellationArePure() {
        #expect(CompanionManager.normalizedTypedPrompt("  hello there \n") == "hello there")
        #expect(CompanionManager.normalizedTypedPrompt(" \n\t") == "")
        #expect(CompanionManager.isExpectedCancellation(CancellationError()))
        #expect(CompanionManager.isExpectedCancellation(URLError(.cancelled)))
        #expect(!CompanionManager.isExpectedCancellation(OllamaVisionClientError.emptyResponse))
    }
    @Test func suppressesCoordinatesOutsideTheCapturedImage() {
        let capture = CompanionScreenCapture(
            imageData: Data(), label: "test", isCursorScreen: true,
            displayWidthInPoints: 100, displayHeightInPoints: 100,
            displayFrame: .zero, screenshotWidthInPixels: 640, screenshotHeightInPixels: 480
        )

        #expect(CompanionManager.isPointCoordinateWithinCapture(CGPoint(x: 640, y: 480), capture: capture))
        #expect(!CompanionManager.isPointCoordinateWithinCapture(CGPoint(x: 641, y: 480), capture: capture))
        #expect(!CompanionManager.isPointCoordinateWithinCapture(CGPoint(x: 10, y: -1), capture: capture))
    }
}
