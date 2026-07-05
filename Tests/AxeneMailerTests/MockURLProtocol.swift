import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A captured request (URL, method, headers, body) for assertions.
struct CapturedRequest {
    let url: URL
    let method: String
    let headers: [String: String]
    let body: Data?
}

/// A queued canned response.
struct StubResponse {
    let status: Int
    let headers: [String: String]
    let body: Data

    init(status: Int = 200, headers: [String: String] = ["Content-Type": "application/json"], json: String = "{}") {
        self.status = status
        self.headers = headers
        self.body = json.data(using: .utf8)!
    }
}

/// A `URLProtocol` that intercepts every request, records it, and replies with a
/// queued ``StubResponse``. Register it on a `URLSession` config so SDK tests run
/// fully offline.
final class MockURLProtocol: URLProtocol {
    // Shared queues, guarded by a lock for thread safety across URLSession threads.
    private static let lock = NSLock()
    private static var responses: [StubResponse] = []
    private static var captured: [CapturedRequest] = []

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        responses = []
        captured = []
    }

    static func enqueue(_ response: StubResponse) {
        lock.lock(); defer { lock.unlock() }
        responses.append(response)
    }

    static func capturedRequests() -> [CapturedRequest] {
        lock.lock(); defer { lock.unlock() }
        return captured
    }

    /// A session whose only protocol is the mock.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // URLSession may strip httpBody into a stream; read it back.
        var bodyData = request.httpBody
        if bodyData == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            buffer.deallocate()
            stream.close()
            bodyData = data
        }

        MockURLProtocol.lock.lock()
        MockURLProtocol.captured.append(CapturedRequest(
            url: request.url!,
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields ?? [:],
            body: bodyData
        ))
        let stub = MockURLProtocol.responses.isEmpty
            ? StubResponse()
            : MockURLProtocol.responses.removeFirst()
        MockURLProtocol.lock.unlock()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
