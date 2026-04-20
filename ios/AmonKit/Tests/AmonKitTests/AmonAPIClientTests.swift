import Foundation
import XCTest
@testable import AmonKit

final class AmonAPIClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testDevLoginDecodesStructuredBackendErrorEnvelope() async {
        let client = makeClient(
            statusCode: 503,
            body: #"{"detail":{"code":"retrieve_timeout","message":"Amon could not prepare a clean view because the site took too long to respond."}}"#
        )

        do {
            _ = try await client.devLogin(appleSubject: "dev-user")
            XCTFail("Expected typed server error")
        } catch let error as AmonAPIError {
            guard case .serverError(let context) = error else {
                return XCTFail("Expected serverError, got \(error)")
            }

            XCTAssertEqual(
                context,
                AmonBackendErrorContext(
                    statusCode: 503,
                    code: "retrieve_timeout",
                    message: "Amon could not prepare a clean view because the site took too long to respond."
                )
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDevLoginDecodesSimpleDetailStringEnvelope() async {
        let client = makeClient(
            statusCode: 503,
            body: #"{"detail":"Search provider is not configured."}"#
        )

        do {
            _ = try await client.devLogin(appleSubject: "dev-user")
            XCTFail("Expected typed server error")
        } catch let error as AmonAPIError {
            guard case .serverError(let context) = error else {
                return XCTFail("Expected serverError, got \(error)")
            }

            XCTAssertEqual(context.statusCode, 503)
            XCTAssertNil(context.code)
            XCTAssertEqual(context.message, "Search provider is not configured.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDevLoginFallsBackToRawBodyWhenErrorPayloadIsMalformed() async {
        let client = makeClient(statusCode: 502, body: "upstream gateway failed")

        do {
            _ = try await client.devLogin(appleSubject: "dev-user")
            XCTFail("Expected typed server error")
        } catch let error as AmonAPIError {
            guard case .serverError(let context) = error else {
                return XCTFail("Expected serverError, got \(error)")
            }

            XCTAssertEqual(context.statusCode, 502)
            XCTAssertNil(context.code)
            XCTAssertEqual(context.message, "upstream gateway failed")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeClient(statusCode: Int, body: String) -> AmonAPIClient {
        StubURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
            return (try XCTUnwrap(response), Data(body.utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return AmonAPIClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: session
        )
    }
}

final class AmonErrorPresenterTests: XCTestCase {
    func testMessageUsesTypedBackendContextWithoutReparsingRawJSON() {
        let error = AmonAPIError.serverError(
            AmonBackendErrorContext(
                statusCode: 403,
                code: "retrieve_blocked",
                message: "That site blocked Amon from preparing a clean view."
            )
        )

        let message = AmonErrorPresenter.message(
            for: error,
            fallback: "fallback"
        )

        XCTAssertEqual(message, "That site blocked Amon from preparing a clean view.")
    }

    func testProtectedSessionTerminalStateUsesTypedBackendCode() {
        let error = AmonAPIError.serverError(
            AmonBackendErrorContext(
                statusCode: 410,
                code: "protected_session_expired",
                message: "That protected session expired and was cleared remotely."
            )
        )

        XCTAssertEqual(
            AmonErrorPresenter.protectedSessionTerminalState(
                for: error,
                fallback: "fallback"
            ),
            .expired(message: "That protected session expired and was cleared remotely.")
        )
    }
}

private final class StubURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
