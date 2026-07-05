import Foundation

/// The `templates` resource. Accessed as `axene.templates`. Starter plan and up.
public final class Templates {
    private let http: Transport
    init(_ http: Transport) { self.http = http }

    /// List all templates, most recently updated first.
    public func list() async throws -> [Template] {
        try await http.request("GET", "/v1/templates/")
    }

    /// Create a template. `html` maps to `html_body` and `text` to `text_body`.
    /// `variables` are derived server-side and are not passed.
    public func create(
        name: String,
        subject: String? = nil,
        html: String? = nil,
        text: String? = nil,
        blocksJson: JSONObject? = nil
    ) async throws -> Template {
        let body = RequestBody([
            ("name", .string(name)),
            ("subject", subject.map(JSONValue.string)),
            ("html_body", html.map(JSONValue.string)),
            ("text_body", text.map(JSONValue.string)),
            ("blocks_json", blocksJson.map(JSONValue.object))
        ])
        return try await http.request("POST", "/v1/templates/", body: body)
    }

    /// Fetch a single template.
    public func get(_ id: String) async throws -> Template {
        try await http.request("GET", "/v1/templates/\(esc(id))")
    }

    /// Update a template (partial). `html` -> `html_body`, `text` -> `text_body`.
    public func update(
        _ id: String,
        name: String? = nil,
        subject: String? = nil,
        html: String? = nil,
        text: String? = nil,
        blocksJson: JSONObject? = nil
    ) async throws -> Template {
        let body = RequestBody([
            ("name", name.map(JSONValue.string)),
            ("subject", subject.map(JSONValue.string)),
            ("html_body", html.map(JSONValue.string)),
            ("text_body", text.map(JSONValue.string)),
            ("blocks_json", blocksJson.map(JSONValue.object))
        ])
        return try await http.request("PATCH", "/v1/templates/\(esc(id))", body: body)
    }

    /// Delete a template.
    public func delete(_ id: String) async throws {
        try await http.requestVoid("DELETE", "/v1/templates/\(esc(id))")
    }

    /// Duplicate a template (the copy's `blocks_json` is not carried over).
    public func duplicate(_ id: String) async throws -> Template {
        try await http.request("POST", "/v1/templates/\(esc(id))/duplicate")
    }
}
