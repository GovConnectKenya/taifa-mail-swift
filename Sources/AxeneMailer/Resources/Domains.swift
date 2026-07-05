import Foundation

/// The `domains` resource. Accessed as `axene.domains`.
///
/// NICHE endpoints (ns-provider, bimi*, domain-connect*) are intentionally not
/// covered in this version.
public final class Domains {
    private let http: Transport
    init(_ http: Transport) { self.http = http }

    /// List your sending domains and their verification status.
    public func list() async throws -> [DomainListItem] {
        try await http.request("GET", "/v1/domains/")
    }

    /// Register a new sending domain. Returns the DNS records to publish.
    public func create(_ name: String) async throws -> Domain {
        try await http.request("POST", "/v1/domains/", body: RequestBody([("name", .string(name))]))
    }

    /// Fetch a domain with its DKIM selector and DNS records.
    public func get(_ id: String) async throws -> Domain {
        try await http.request("GET", "/v1/domains/\(esc(id))")
    }

    /// Delete a domain.
    public func delete(_ id: String) async throws {
        try await http.requestVoid("DELETE", "/v1/domains/\(esc(id))")
    }

    /// Re-check DNS and verify the domain.
    public func verify(_ id: String) async throws -> Domain {
        try await http.request("POST", "/v1/domains/\(esc(id))/verify")
    }

    /// Run live DNS health checks (DKIM, SPF, DMARC, return-path, MX).
    public func health(_ id: String) async throws -> DomainHealth {
        try await http.request("GET", "/v1/domains/\(esc(id))/health")
    }

    /// Diagnose configuration issues and get a health score.
    public func diagnose(_ id: String) async throws -> DomainDiagnosis {
        try await http.request("GET", "/v1/domains/\(esc(id))/diagnose")
    }

    /// Current MX status (shape varies by provider; an open map).
    public func mxStatus(_ id: String) async throws -> JSONObject {
        try await http.request("GET", "/v1/domains/\(esc(id))/mx-status")
    }

    /// The values currently published in DNS for each record (open map).
    public func publishedRecords(_ id: String) async throws -> JSONObject {
        try await http.request("GET", "/v1/domains/\(esc(id))/published-records")
    }

    /// Rotate the domain's DKIM key, returning the new record to publish.
    public func rotateDkim(_ id: String) async throws -> DkimRotation {
        try await http.request("POST", "/v1/domains/\(esc(id))/rotate-dkim")
    }

    /// Initiate a transfer of this domain to another Axene account.
    public func transfer(_ id: String, targetEmail: String, note: String? = nil) async throws -> DomainTransfer {
        let body = RequestBody([
            ("target_email", .string(targetEmail)),
            ("note", note.map(JSONValue.string))
        ])
        return try await http.request("POST", "/v1/domains/\(esc(id))/transfer", body: body)
    }

    /// Check whether a domain name is available to add (checks public DNS).
    public func checkAvailability(_ name: String) async throws -> DomainAvailability {
        try await http.request("GET", "/v1/domains/check-availability", query: ["name": name])
    }

    /// Check whether a domain name already exists in your account.
    public func check(_ name: String) async throws -> DomainCheck {
        try await http.request("GET", "/v1/domains/check/\(esc(name))")
    }
}
