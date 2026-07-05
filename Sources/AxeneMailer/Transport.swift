import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An encodable request body that serializes a dictionary of values, omitting
/// any entry whose value is `nil`. This is how the SDK honours the API's
/// "omit-if-absent" convention while keeping exact wire keys (`from_`,
/// `email_address`, `is_active`, ...) intact.
///
/// Values are wrapped in ``JSONValue`` so encoding never goes through a
/// key-conversion strategy that could mangle keys like `from_`.
struct RequestBody: Encodable {
    private let fields: [(String, JSONValue)]

    /// Build from key/optional-value pairs; Swift-nil values are dropped so they
    /// are omitted from the JSON body entirely. Pass `.null` explicitly to send
    /// a JSON `null`.
    init(_ pairs: [(String, JSONValue?)]) {
        self.fields = pairs.compactMap { key, value in
            guard let value else { return nil }
            return (key, value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        for (key, value) in fields {
            try container.encode(value, forKey: DynamicKey(stringValue: key))
        }
    }
}

/// A `CodingKey` that carries an arbitrary string, used for dynamic JSON bodies.
struct DynamicKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

/// Configuration for ``Transport``.
public struct AxeneOptions {
    /// API key from your Axene Mailer dashboard (starts with `axm_k_`).
    public let apiKey: String
    /// Override the API base URL. Defaults to `https://mail.axene.io`.
    public let baseURL: String
    /// Total attempts on `429` / `5xx`, including the first. Defaults to `3`.
    public let maxRetries: Int
    /// Per-request timeout in seconds. Defaults to `30`.
    public let timeout: TimeInterval
    /// Inject a custom `URLSession` (for testing). Defaults to `.shared`.
    public let session: URLSession

    public init(
        apiKey: String,
        baseURL: String = "https://mail.axene.io",
        maxRetries: Int = 3,
        timeout: TimeInterval = 30,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.maxRetries = maxRetries
        self.timeout = timeout
        self.session = session
    }
}

/// The HTTP transport: the single place that talks to the network. Owns bearer
/// authentication, JSON encode/decode, retries on `429`/`5xx` with backoff
/// (honouring `Retry-After`), multipart upload, and error mapping to
/// ``AxeneError``. Resources are thin and call this.
final class Transport {
    private let apiKey: String
    private let baseURL: String
    private let maxRetries: Int
    private let timeout: TimeInterval
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(_ options: AxeneOptions) {
        precondition(!options.apiKey.isEmpty, "Axene: `apiKey` is required.")
        self.apiKey = options.apiKey
        // Strip trailing slashes from the base URL.
        var base = options.baseURL
        while base.hasSuffix("/") { base.removeLast() }
        self.baseURL = base
        self.maxRetries = max(1, options.maxRetries)
        self.timeout = options.timeout
        self.session = options.session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: Requests

    /// Perform a request expecting a decodable JSON response.
    func request<T: Decodable>(
        _ method: String,
        _ path: String,
        query: [String: String?] = [:],
        body: RequestBody? = nil
    ) async throws -> T {
        let data = try await send(method, path, query: query, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AxeneError(status: 0, message: "Axene: failed to decode response: \(error)")
        }
    }

    /// Perform a request whose body is an arbitrary ``JSONValue`` (e.g. a bare
    /// JSON array for the batch endpoint).
    func requestRaw<T: Decodable>(
        _ method: String,
        _ path: String,
        query: [String: String?] = [:],
        json: JSONValue
    ) async throws -> T {
        let data = try await send(method, path, query: query, jsonData: try encoder.encode(json))
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AxeneError(status: 0, message: "Axene: failed to decode response: \(error)")
        }
    }

    /// Perform a request that returns no body (204 / empty).
    func requestVoid(
        _ method: String,
        _ path: String,
        query: [String: String?] = [:],
        body: RequestBody? = nil
    ) async throws {
        _ = try await send(method, path, query: query, body: body)
    }

    /// Core send loop with retries. Accepts either a ``RequestBody`` or
    /// pre-encoded JSON data (for bare-array bodies).
    private func send(
        _ method: String,
        _ path: String,
        query: [String: String?],
        body: RequestBody? = nil,
        jsonData: Data? = nil
    ) async throws -> Data {
        let url = try buildURL(path, query: query)
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("axene-mailer-swift", forHTTPHeaderField: "User-Agent")
        if let jsonData {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
        } else if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw AxeneError(status: 0, message: "Axene: non-HTTP response")
                }
                if isRetryable(http.statusCode), attempt < maxRetries {
                    try await sleep(backoff(http, attempt: attempt))
                    continue
                }
                if !(200...299).contains(http.statusCode) {
                    throw mapError(status: http.statusCode, data: data)
                }
                return data
            } catch let error as AxeneError {
                throw error // a real API error: do not retry
            } catch {
                lastError = error // transport error: retry if attempts remain
                if attempt < maxRetries {
                    try await sleep(backoff(nil, attempt: attempt))
                    continue
                }
            }
        }
        throw AxeneError(status: 0, message: "Axene request failed: \(String(describing: lastError))")
    }

    // MARK: Multipart upload

    /// Upload a single file as `multipart/form-data` under the field name `file`.
    /// Used by the CSV / suppression import endpoints. Not retried.
    func upload<T: Decodable>(_ path: String, file: Data, filename: String) async throws -> T {
        let url = try buildURL(path, query: [:])
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("axene-mailer-swift", forHTTPHeaderField: "User-Agent")

        let boundary = "axene-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(boundary: boundary, field: "file", filename: filename, data: file)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AxeneError(status: 0, message: "Axene: non-HTTP response")
        }
        if !(200...299).contains(http.statusCode) {
            throw mapError(status: http.statusCode, data: data)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AxeneError(status: 0, message: "Axene: failed to decode response: \(error)")
        }
    }

    private func multipartBody(boundary: String, field: String, filename: String, data: Data) -> Data {
        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")
        return body
    }

    // MARK: Helpers

    private func buildURL(_ path: String, query: [String: String?]) throws -> URL {
        guard var components = URLComponents(string: baseURL + path) else {
            throw AxeneError(status: 0, message: "Axene: invalid URL for path \(path)")
        }
        let items = query.compactMap { key, value -> URLQueryItem? in
            guard let value else { return nil }
            return URLQueryItem(name: key, value: value)
        }
        if !items.isEmpty {
            components.queryItems = (components.queryItems ?? []) + items
        }
        guard let url = components.url else {
            throw AxeneError(status: 0, message: "Axene: failed to build URL for path \(path)")
        }
        return url
    }

    private func isRetryable(_ status: Int) -> Bool {
        status == 429 || status >= 500
    }

    /// Backoff in seconds. Honours `Retry-After` when present, else exponential.
    private func backoff(_ response: HTTPURLResponse?, attempt: Int) -> TimeInterval {
        if let header = response?.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(header), seconds > 0 {
            return seconds
        }
        return 0.25 * pow(2, Double(attempt - 1))
    }

    private func sleep(_ seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }

    /// Map the API's `{ detail: { code, message } }` (or string) into ``AxeneError``.
    private func mapError(status: Int, data: Data) -> AxeneError {
        let fallback = "Axene request failed (\(status))"
        guard !data.isEmpty,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return AxeneError(status: status, message: fallback)
        }
        let detail = root["detail"]
        if let obj = detail as? [String: Any] {
            let message = obj["message"] as? String ?? fallback
            let code = obj["code"] as? String
            return AxeneError(status: status, message: message, code: code)
        }
        if let text = detail as? String {
            return AxeneError(status: status, message: text)
        }
        return AxeneError(status: status, message: fallback)
    }
}

// MARK: - Body builders

extension RequestBody {
    /// Normalize a single address into a JSON object value.
    static func address(_ a: Address) -> JSONValue {
        var obj: [String: JSONValue] = ["email": .string(a.email)]
        if let name = a.name { obj["name"] = .string(name) }
        return .object(obj)
    }

    /// Normalize a list of addresses into a JSON array value.
    static func addresses(_ list: [Address]?) -> JSONValue? {
        guard let list else { return nil }
        return .array(list.map { address($0) })
    }

    static func strings(_ list: [String]?) -> JSONValue? {
        guard let list else { return nil }
        return .array(list.map { .string($0) })
    }

    static func stringMap(_ map: [String: String]?) -> JSONValue? {
        guard let map else { return nil }
        return .object(map.mapValues { .string($0) })
    }
}
