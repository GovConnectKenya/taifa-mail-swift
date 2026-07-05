import Foundation

/// The `webhooks` resource. Accessed as `axene.webhooks`.
public final class Webhooks {
    private let http: Transport
    init(_ http: Transport) { self.http = http }

    /// List your active webhooks.
    public func list() async throws -> [Webhook] {
        try await http.request("GET", "/v1/webhooks/")
    }

    /// Create a webhook. The signing `secret` is generated and returned.
    public func create(url: String, events: [String]) async throws -> Webhook {
        let body = RequestBody([
            ("url", .string(url)),
            ("events", .array(events.map { .string($0) }))
        ])
        return try await http.request("POST", "/v1/webhooks/", body: body)
    }

    /// Update a webhook's url, events, or active state (partial). The clean
    /// `isActive` maps to the wire field `is_active`.
    public func update(_ id: String, url: String? = nil, events: [String]? = nil, isActive: Bool? = nil) async throws -> Webhook {
        let body = RequestBody([
            ("url", url.map(JSONValue.string)),
            ("events", RequestBody.strings(events)),
            ("is_active", isActive.map(JSONValue.bool))
        ])
        return try await http.request("PATCH", "/v1/webhooks/\(esc(id))", body: body)
    }

    /// Delete a webhook.
    public func delete(_ id: String) async throws {
        try await http.requestVoid("DELETE", "/v1/webhooks/\(esc(id))")
    }

    /// Queue a sample `email.delivered` delivery to test the endpoint.
    public func test(_ id: String) async throws -> WebhookTestResult {
        try await http.request("POST", "/v1/webhooks/\(esc(id))/test")
    }

    /// List delivery attempts for a webhook (paginated envelope).
    public func listDeliveries(_ id: String, page: Int = 0, limit: Int = 20, status: String? = nil) async throws -> Page<WebhookDelivery> {
        try await http.request("GET", "/v1/webhooks/\(esc(id))/deliveries", query: [
            "page": String(page), "limit": String(limit), "status": status
        ])
    }

    /// Fetch one delivery with its full payload and the endpoint's response.
    public func getDelivery(_ id: String, deliveryId: String) async throws -> WebhookDeliveryDetail {
        try await http.request("GET", "/v1/webhooks/\(esc(id))/deliveries/\(esc(deliveryId))")
    }
}
