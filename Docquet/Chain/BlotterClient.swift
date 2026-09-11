import Foundation

/// Role: Chain. Typed transport failures. This product has no remote catalog; contact is a Settings link.
enum BlotterWireFault: Error, Equatable, Sendable {
    case notFound
    case decoding
    case transport
    case cancelled
    case invalidResponse
}

/// Role: Chain. One HTTP hop. Injected so tests never leave the process.
protocol BlotterCarrying: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Role: Chain. URLSession hop, 15 s timeout, app User-Agent on every request.
struct BlotterSessionCarrier: BlotterCarrying {
    let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        configuration.httpAdditionalHeaders = ["User-Agent": BlotterClient.userAgent]
        self.session = URLSession(configuration: configuration)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

/// Role: Chain. Owns the session. No required remote catalog — contact URL is a Settings link, not fetched here.
actor BlotterClient {
    static let userAgent = "Docquet/1.0 (iOS; +https://docquet-blotter.pro)"
    /// Programmer constant; the domain string is fixed in SPEC.md.
    static let contactURL = URL(string: "https://docquet-blotter.pro/contact-us")!

    private let carrier: any BlotterCarrying

    init(carrier: any BlotterCarrying) {
        self.carrier = carrier
    }

    init() {
        self.carrier = BlotterSessionCarrier()
    }

    func getJSON<DTO: Decodable & Sendable>(_ type: DTO.Type, from url: URL) async throws -> DTO {
        try Task.checkCancellation()
        let body = try await fetch(request(for: url))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        do {
            return try decoder.decode(DTO.self, from: body)
        } catch is CancellationError {
            throw BlotterWireFault.cancelled
        } catch {
            throw BlotterWireFault.decoding
        }
    }

    private func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private func fetch(_ request: URLRequest) async throws -> Data {
        do {
            return try await send(request)
        } catch let fault as BlotterWireFault {
            throw fault
        } catch is CancellationError {
            throw BlotterWireFault.cancelled
        } catch {
            if Self.cancelled(error) {
                throw BlotterWireFault.cancelled
            }
            guard Self.transient(error) else { throw BlotterWireFault.transport }
            do {
                return try await send(request)
            } catch let fault as BlotterWireFault {
                throw fault
            } catch is CancellationError {
                throw BlotterWireFault.cancelled
            } catch {
                if Self.cancelled(error) { throw BlotterWireFault.cancelled }
                throw BlotterWireFault.transport
            }
        }
    }

    private func send(_ request: URLRequest) async throws -> Data {
        try Task.checkCancellation()
        let (data, response) = try await carrier.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BlotterWireFault.invalidResponse
        }
        if http.statusCode == 404 {
            throw BlotterWireFault.notFound
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw BlotterWireFault.transport
        }
        return data
    }

    private static func transient(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet,
             .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private static func cancelled(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        return (error as? URLError)?.code == .cancelled
    }
}
