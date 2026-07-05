import Foundation

/// The `suppressions` resource. Accessed as `axene.suppressions`.
public final class Suppressions {
    private let http: Transport
    init(_ http: Transport) { self.http = http }

    /// List suppressed addresses (paginated envelope; zero-based `page`).
    public func list(page: Int = 0, limit: Int = 50, search: String? = nil) async throws -> Page<Suppression> {
        try await http.request("GET", "/v1/suppressions", query: [
            "page": String(page), "limit": String(limit), "search": search
        ])
    }

    /// Suppress a single address. The clean `email` maps to the wire field
    /// `email_address`.
    public func add(email: String, reason: String = "manual") async throws -> Suppression {
        let body = RequestBody([
            ("email_address", .string(email)),
            ("reason", .string(reason))
        ])
        return try await http.request("POST", "/v1/suppressions", body: body)
    }

    /// Bulk-import suppressions from a file (one email per line). Multipart field `file`.
    public func bulkUpload(file: Data, filename: String = "suppressions.txt") async throws -> BulkSuppressionResult {
        try await http.upload("/v1/suppressions/bulk", file: file, filename: filename)
    }

    /// Remove an address from the suppression list.
    public func remove(_ id: String) async throws {
        try await http.requestVoid("DELETE", "/v1/suppressions/\(esc(id))")
    }
}
