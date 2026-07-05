import Foundation

/// The `contacts` resource. Accessed as `axene.contacts`.
public final class Contacts {
    private let http: Transport
    init(_ http: Transport) { self.http = http }

    /// List all subscriber lists in the active workspace.
    public func listLists() async throws -> [ContactList] {
        try await http.request("GET", "/v1/contacts/")
    }

    /// Create a subscriber list.
    public func createList(name: String, description: String? = nil, iconSeed: String? = nil) async throws -> ContactList {
        let body = RequestBody([
            ("name", .string(name)),
            ("description", description.map(JSONValue.string)),
            ("icon_seed", iconSeed.map(JSONValue.string))
        ])
        return try await http.request("POST", "/v1/contacts/", body: body)
    }

    /// Get a list with a page of its contacts (zero-based `page`).
    public func getList(_ id: String, page: Int = 0, limit: Int = 50) async throws -> ContactListDetail {
        try await http.request("GET", "/v1/contacts/\(esc(id))", query: [
            "page": String(page), "limit": String(limit)
        ])
    }

    /// Update a list's name, description, or icon (partial).
    public func updateList(_ id: String, name: String? = nil, description: String? = nil, iconSeed: String? = nil) async throws -> ContactList {
        let body = RequestBody([
            ("name", name.map(JSONValue.string)),
            ("description", description.map(JSONValue.string)),
            ("icon_seed", iconSeed.map(JSONValue.string))
        ])
        return try await http.request("PATCH", "/v1/contacts/\(esc(id))", body: body)
    }

    /// Delete a list and all of its contacts.
    public func deleteList(_ id: String) async throws {
        try await http.requestVoid("DELETE", "/v1/contacts/\(esc(id))")
    }

    /// Add a single contact to a list.
    public func addContact(_ listId: String, email: String, name: String? = nil, metadata: JSONObject? = nil) async throws -> Contact {
        let body = RequestBody([
            ("email", .string(email)),
            ("name", name.map(JSONValue.string)),
            ("metadata", metadata.map(JSONValue.object))
        ])
        return try await http.request("POST", "/v1/contacts/\(esc(listId))/contacts", body: body)
    }

    /// Remove a contact from a list.
    public func removeContact(_ listId: String, contactId: String) async throws {
        try await http.requestVoid("DELETE", "/v1/contacts/\(esc(listId))/contacts/\(esc(contactId))")
    }

    /// Import contacts from a CSV file (header row required). Multipart field `file`.
    public func uploadCsv(_ listId: String, file: Data, filename: String = "contacts.csv") async throws -> CsvImportResult {
        try await http.upload("/v1/contacts/\(esc(listId))/upload", file: file, filename: filename)
    }

    /// Send a templated email to every contact in a list. The `contact_list_id`
    /// field is injected automatically to match `listId`.
    public func bulkSend(
        _ listId: String,
        senderAddressId: String,
        subject: String,
        html: String? = nil,
        text: String? = nil,
        tags: [String]? = nil
    ) async throws -> BulkSendResult {
        let body = RequestBody([
            ("contact_list_id", .string(listId)),
            ("sender_address_id", .string(senderAddressId)),
            ("subject", .string(subject)),
            ("html", html.map(JSONValue.string)),
            ("text", text.map(JSONValue.string)),
            ("tags", RequestBody.strings(tags))
        ])
        return try await http.request("POST", "/v1/contacts/\(esc(listId))/send", body: body)
    }
}
