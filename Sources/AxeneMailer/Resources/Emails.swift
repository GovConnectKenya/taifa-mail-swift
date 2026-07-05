import Foundation

/// Parameters for ``Emails/send(_:)``, ``Emails/sendBatch(_:)`` and
/// ``Emails/validate(_:)``. A bare string is accepted anywhere an ``Address`` is.
public struct SendEmailParams {
    /// Sender address. Must be on a verified domain in your account.
    public var from: Address
    /// One or more recipients.
    public var to: [Address]
    public var subject: String
    /// HTML body. Provide `html`, `text`, or both.
    public var html: String?
    /// Plain-text body. Provide `html`, `text`, or both.
    public var text: String?
    public var cc: [Address]?
    public var bcc: [Address]?
    public var replyTo: Address?
    /// Custom headers to attach to the message.
    public var headers: [String: String]?
    /// Tags for filtering and analytics.
    public var tags: [String]?
    /// Schedule delivery for later (ISO 8601 string). Starter plan and up.
    public var sendAt: String?
    public var attachments: [Attachment]?

    public init(
        from: Address,
        to: [Address],
        subject: String,
        html: String? = nil,
        text: String? = nil,
        cc: [Address]? = nil,
        bcc: [Address]? = nil,
        replyTo: Address? = nil,
        headers: [String: String]? = nil,
        tags: [String]? = nil,
        sendAt: String? = nil,
        attachments: [Attachment]? = nil
    ) {
        self.from = from
        self.to = to
        self.subject = subject
        self.html = html
        self.text = text
        self.cc = cc
        self.bcc = bcc
        self.replyTo = replyTo
        self.headers = headers
        self.tags = tags
        self.sendAt = sendAt
        self.attachments = attachments
    }

    /// Build the exact JSON body the API expects. The sender field serializes as
    /// the literal wire key `from_` (trailing underscore).
    func body() -> RequestBody {
        let attachmentsValue: JSONValue? = attachments.map { list in
            .array(list.map { att in
                var obj: [String: JSONValue] = [
                    "filename": .string(att.filename),
                    "content_base64": .string(att.contentBase64)
                ]
                if let ct = att.contentType { obj["content_type"] = .string(ct) }
                return .object(obj)
            })
        }
        return RequestBody([
            ("from_", RequestBody.address(from)),
            ("to", RequestBody.addresses(to)),
            ("subject", .string(subject)),
            ("html", html.map(JSONValue.string)),
            ("text", text.map(JSONValue.string)),
            ("cc", RequestBody.addresses(cc)),
            ("bcc", RequestBody.addresses(bcc)),
            ("reply_to", replyTo.map(RequestBody.address)),
            ("headers", RequestBody.stringMap(headers)),
            ("tags", RequestBody.strings(tags)),
            ("send_at", sendAt.map(JSONValue.string)),
            ("attachments", attachmentsValue)
        ])
    }
}

/// The `emails` resource. Accessed as `axene.emails`.
public final class Emails {
    private let http: Transport
    init(_ http: Transport) { self.http = http }

    /// Send a single email.
    public func send(_ params: SendEmailParams) async throws -> SendEmailResponse {
        try await http.request("POST", "/v1/emails/", body: params.body())
    }

    /// Send up to your plan's batch limit in one call. The API accepts a bare
    /// array of messages and returns a per-message result set.
    public func sendBatch(_ messages: [SendEmailParams]) async throws -> BatchResponse {
        // The batch endpoint takes a bare JSON array, so encode it directly.
        let array = JSONValue.array(messages.map { $0.bodyAsJSON() })
        return try await http.requestRaw("POST", "/v1/emails/batch", json: array)
    }

    /// Dry-run a send: check whether `message` would be accepted without sending.
    public func validate(_ message: SendEmailParams) async throws -> ValidationResult {
        try await http.request("POST", "/v1/emails/validate", body: message.body())
    }

    /// List recent emails, newest first. `page` is zero-based.
    public func list(status: String? = nil, page: Int = 0, limit: Int = 20) async throws -> [Email] {
        try await http.request("GET", "/v1/emails/", query: [
            "status": status, "page": String(page), "limit": String(limit)
        ])
    }

    /// Fetch a single email with its bodies and events.
    public func get(_ id: String) async throws -> EmailDetail {
        try await http.request("GET", "/v1/emails/\(esc(id))")
    }

    /// List delivery / open / click / bounce events for an email.
    public func events(_ id: String) async throws -> [EmailEvent] {
        try await http.request("GET", "/v1/emails/\(esc(id))/events")
    }

    /// Re-send a bounced, rejected, or failed email as a new message.
    public func retry(_ id: String) async throws -> SendEmailResponse {
        try await http.request("POST", "/v1/emails/\(esc(id))/retry")
    }

    /// Search emails. `q` supports inline tokens (`to:`, `from:`, `status:`,
    /// `domain:`, `tag:`); leftover words are matched as free text.
    public func search(
        q: String? = nil, status: String? = nil, tag: String? = nil, page: Int = 0, limit: Int = 20
    ) async throws -> [EmailSearchHit] {
        try await http.request("GET", "/v1/emails/search", query: [
            "q": q, "status": status, "tag": tag, "page": String(page), "limit": String(limit)
        ])
    }

    /// List emails scheduled for future delivery, soonest first.
    public func listScheduled() async throws -> [ScheduledEmail] {
        try await http.request("GET", "/v1/emails/scheduled")
    }

    /// Cancel a scheduled email.
    public func cancelScheduled(_ id: String) async throws -> StatusAck {
        try await http.request("DELETE", "/v1/emails/scheduled/\(esc(id))")
    }

    /// Send a scheduled email immediately instead of waiting.
    public func sendScheduledNow(_ id: String) async throws -> StatusAck {
        try await http.request("POST", "/v1/emails/scheduled/\(esc(id))/send-now")
    }

    /// Poll for emails whose status changed at or after `since` (ISO 8601).
    /// Capped at 50 rows.
    public func updates(since: String) async throws -> [Email] {
        try await http.request("GET", "/v1/emails/updates", query: ["since": since])
    }

    /// Get the caller's saved searches.
    public func getSavedSearches() async throws -> [JSONObject] {
        let wrapped: SavedSearches = try await http.request("GET", "/v1/emails/saved-searches")
        return wrapped.searches
    }

    /// Replace the caller's saved searches (max 50).
    @discardableResult
    public func setSavedSearches(_ searches: [JSONObject]) async throws -> [JSONObject] {
        let body = RequestBody([("searches", .array(searches.map { .object($0) }))])
        let wrapped: SavedSearches = try await http.request("PUT", "/v1/emails/saved-searches", body: body)
        return wrapped.searches
    }

    private struct SavedSearches: Decodable { let searches: [JSONObject] }
}

extension SendEmailParams {
    /// The send body as a ``JSONValue`` (for the bare-array batch endpoint).
    func bodyAsJSON() -> JSONValue {
        var obj: [String: JSONValue] = [
            "from_": RequestBody.address(from),
            "to": .array(to.map { RequestBody.address($0) }),
            "subject": .string(subject)
        ]
        if let html { obj["html"] = .string(html) }
        if let text { obj["text"] = .string(text) }
        if let cc { obj["cc"] = .array(cc.map { RequestBody.address($0) }) }
        if let bcc { obj["bcc"] = .array(bcc.map { RequestBody.address($0) }) }
        if let replyTo { obj["reply_to"] = RequestBody.address(replyTo) }
        if let headers { obj["headers"] = .object(headers.mapValues { .string($0) }) }
        if let tags { obj["tags"] = .array(tags.map { .string($0) }) }
        if let sendAt { obj["send_at"] = .string(sendAt) }
        if let attachments {
            obj["attachments"] = .array(attachments.map { att in
                var a: [String: JSONValue] = [
                    "filename": .string(att.filename),
                    "content_base64": .string(att.contentBase64)
                ]
                if let ct = att.contentType { a["content_type"] = .string(ct) }
                return .object(a)
            })
        }
        return .object(obj)
    }
}

/// Percent-encode a path segment.
func esc(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s
}
