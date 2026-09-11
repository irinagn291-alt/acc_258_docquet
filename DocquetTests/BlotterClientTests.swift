import XCTest
@testable import Docquet

private struct ProbeDTO: Decodable, Sendable {
    var remainder: Double
}

private actor ScriptedCarrier: BlotterCarrying {
    private var results: [Result<(Data, URLResponse), Error>]
    private var requests: [URLRequest] = []

    init(results: [Result<(Data, URLResponse), Error>]) {
        self.results = results
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !results.isEmpty else { throw URLError(.cannotConnectToHost) }
        return try results.removeFirst().get()
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}

final class BlotterClientTests: XCTestCase {
    private let url = URL(string: "https://docquet-blotter.pro/probe")!

    func test_setsUserAgentOnEveryRequest() async throws {
        let carrier = ScriptedCarrier(results: [
            .success((Data("{\"remainder\":1}".utf8), http(200))),
        ])
        let client = BlotterClient(carrier: carrier)
        _ = try await client.getJSON(ProbeDTO.self, from: url)
        let request = await carrier.recordedRequests().first
        XCTAssertEqual(request?.value(forHTTPHeaderField: "User-Agent"), BlotterClient.userAgent)
        XCTAssertEqual(request?.timeoutInterval, 15)
        XCTAssertEqual(BlotterClient.userAgent, "Docquet/1.0 (iOS; +https://docquet-blotter.pro)")
        XCTAssertEqual(BlotterClient.contactURL.absoluteString, "https://docquet-blotter.pro/contact-us")
    }

    func test_retriesTransientTransportOnce() async throws {
        let carrier = ScriptedCarrier(results: [
            .failure(URLError(.timedOut)),
            .success((Data("{\"remainder\":4.5}".utf8), http(200))),
        ])
        let client = BlotterClient(carrier: carrier)
        let dto = try await client.getJSON(ProbeDTO.self, from: url)
        XCTAssertEqual(dto.remainder, 4.5)
        let count = await carrier.recordedRequests().count
        XCTAssertEqual(count, 2)
    }

    func test_doesNotRetry404() async {
        let carrier = ScriptedCarrier(results: [
            .success((Data(), http(404))),
            .success((Data("{\"remainder\":1}".utf8), http(200))),
        ])
        let client = BlotterClient(carrier: carrier)
        do {
            _ = try await client.getJSON(ProbeDTO.self, from: url)
            XCTFail("expected notFound")
        } catch {
            XCTAssertEqual(error as? BlotterWireFault, .notFound)
        }
        let count = await carrier.recordedRequests().count
        XCTAssertEqual(count, 1)
    }

    func test_secondTransientFailureIsTransport() async {
        let carrier = ScriptedCarrier(results: [
            .failure(URLError(.cannotConnectToHost)),
            .failure(URLError(.timedOut)),
        ])
        let client = BlotterClient(carrier: carrier)
        do {
            _ = try await client.getJSON(ProbeDTO.self, from: url)
            XCTFail("expected transport")
        } catch {
            XCTAssertEqual(error as? BlotterWireFault, .transport)
        }
        let count = await carrier.recordedRequests().count
        XCTAssertEqual(count, 2)
    }

    func test_cancellationIsNotRetried() async {
        let carrier = ScriptedCarrier(results: [
            .failure(CancellationError()),
            .success((Data("{\"remainder\":1}".utf8), http(200))),
        ])
        let client = BlotterClient(carrier: carrier)
        do {
            _ = try await client.getJSON(ProbeDTO.self, from: url)
            XCTFail("expected cancelled")
        } catch {
            XCTAssertEqual(error as? BlotterWireFault, .cancelled)
        }
        let count = await carrier.recordedRequests().count
        XCTAssertEqual(count, 1)
    }

    func test_malformedJSONIsDecodingError() async {
        let carrier = ScriptedCarrier(results: [
            .success((Data("{".utf8), http(200))),
        ])
        let client = BlotterClient(carrier: carrier)
        do {
            _ = try await client.getJSON(ProbeDTO.self, from: url)
            XCTFail("expected decoding")
        } catch {
            XCTAssertEqual(error as? BlotterWireFault, .decoding)
        }
    }

    private func http(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}
