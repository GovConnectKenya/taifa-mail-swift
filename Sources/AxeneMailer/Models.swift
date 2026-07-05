import Foundation

// MARK: - Loose JSON

/// A type-erased JSON value used for loosely-typed API shapes (open maps, event
/// metadata, diagnosis issues, webhook payloads). Decodes any JSON and re-encodes
/// it faithfully.
public enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let d = try? c.decode(Double.self) {
            self = .number(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .object(let o): try c.encode(o)
        case .array(let a): try c.encode(a)
        case .null: try c.encodeNil()
        }
    }

    /// Convenience: the underlying Swift value as `Any`.
    public var value: Any? {
        switch self {
        case .string(let s): return s
        case .number(let n): return n
        case .bool(let b): return b
        case .object(let o): return o.mapValues { $0.value }
        case .array(let a): return a.map { $0.value }
        case .null: return nil
        }
    }
}

/// An open string-keyed JSON map.
public typealias JSONObject = [String: JSONValue]

// MARK: - Address

/// A recipient or sender. A bare string literal is sugar for ``Address(email:)``.
///
/// ```swift
/// let to: Address = "customer@example.com"
/// let from = Address(email: "hello@yourdomain.com", name: "Acme")
/// ```
public struct Address: Codable, Equatable, ExpressibleByStringLiteral {
    public let email: String
    public let name: String?

    public init(email: String, name: String? = nil) {
        self.email = email
        self.name = name
    }

    public init(stringLiteral value: String) {
        self.email = value
        self.name = nil
    }
}

/// A file attachment. `contentBase64` is the raw base64-encoded content (no
/// `data:` prefix).
public struct Attachment: Codable, Equatable {
    public let filename: String
    public let contentBase64: String
    public let contentType: String?

    public init(filename: String, contentBase64: String, contentType: String? = nil) {
        self.filename = filename
        self.contentBase64 = contentBase64
        self.contentType = contentType
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case contentBase64 = "content_base64"
        case contentType = "content_type"
    }
}

// MARK: - Pagination

/// A paginated envelope `{ items, total, page, limit }`.
public struct Page<T: Decodable>: Decodable {
    public let items: [T]
    public let total: Int
    public let page: Int
    public let limit: Int
}

// MARK: - Emails

/// Result of a send: the queued message id and its initial status.
public struct SendEmailResponse: Decodable {
    public let id: String
    public let status: String
    public let messageId: String?
    public let rejectionReason: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case messageId = "message_id"
        case rejectionReason = "rejection_reason"
    }
}

/// One result row inside a batch send.
public struct BatchResultItem: Decodable {
    public let id: String?
    public let status: String
    public let rejectionReason: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case rejectionReason = "rejection_reason"
    }
}

/// Result of ``Emails/sendBatch(_:)``.
public struct BatchResponse: Decodable {
    public let total: Int
    public let sent: Int
    public let failed: Int
    public let results: [BatchResultItem]
}

/// A single reason a message would not send.
public struct ValidationIssue: Decodable {
    public let field: String
    public let error: String
}

/// Sending-quota usage returned alongside a validation.
public struct ValidationUsage: Decodable {
    public let daily: Int
    public let dailyLimit: Int
    public let monthly: Int
    public let monthlyLimit: Int

    enum CodingKeys: String, CodingKey {
        case daily, monthly
        case dailyLimit = "daily_limit"
        case monthlyLimit = "monthly_limit"
    }
}

/// Result of ``Emails/validate(_:)``: a dry-run that never sends.
public struct ValidationResult: Decodable {
    public let valid: Bool
    public let canSend: Bool
    public let issues: [ValidationIssue]
    public let plan: String
    public let usage: ValidationUsage

    enum CodingKeys: String, CodingKey {
        case valid, issues, plan, usage
        case canSend = "can_send"
    }
}

/// A delivery / open / click / bounce event for a message.
public struct EmailEvent: Decodable {
    public let id: String
    public let eventType: String
    public let metadata: JSONObject?
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, metadata
        case eventType = "event_type"
        case createdAt = "created_at"
    }
}

/// A stored email and its current status.
public struct Email: Decodable {
    public let id: String
    public let fromAddress: String
    public let toAddresses: [String]
    public let subject: String?
    public let status: String
    public let source: String?
    public let openedCount: Int?
    public let clickedCount: Int?
    public let tags: [String]?
    public let scheduledAt: String?
    public let createdAt: String?
    public let sentAt: String?
    public let deliveredAt: String?
    public let retryOfId: String?

    enum CodingKeys: String, CodingKey {
        case id, subject, status, source, tags
        case fromAddress = "from_address"
        case toAddresses = "to_addresses"
        case openedCount = "opened_count"
        case clickedCount = "clicked_count"
        case scheduledAt = "scheduled_at"
        case createdAt = "created_at"
        case sentAt = "sent_at"
        case deliveredAt = "delivered_at"
        case retryOfId = "retry_of_id"
    }
}

/// A stored email with its bodies and events, from ``Emails/get(_:)``.
public struct EmailDetail: Decodable {
    public let id: String
    public let fromAddress: String
    public let toAddresses: [String]
    public let subject: String?
    public let status: String
    public let source: String?
    public let openedCount: Int?
    public let clickedCount: Int?
    public let tags: [String]?
    public let scheduledAt: String?
    public let createdAt: String?
    public let sentAt: String?
    public let deliveredAt: String?
    public let retryOfId: String?
    public let ccAddresses: [String]?
    public let bccAddresses: [String]?
    public let textBody: String?
    public let htmlBody: String?
    public let headers: JSONObject?
    public let messageId: String?
    public let events: [EmailEvent]

    enum CodingKeys: String, CodingKey {
        case id, subject, status, source, tags, headers, events
        case fromAddress = "from_address"
        case toAddresses = "to_addresses"
        case openedCount = "opened_count"
        case clickedCount = "clicked_count"
        case scheduledAt = "scheduled_at"
        case createdAt = "created_at"
        case sentAt = "sent_at"
        case deliveredAt = "delivered_at"
        case retryOfId = "retry_of_id"
        case ccAddresses = "cc_addresses"
        case bccAddresses = "bcc_addresses"
        case textBody = "text_body"
        case htmlBody = "html_body"
        case messageId = "message_id"
    }
}

/// A search hit from ``Emails/search(q:status:tag:page:limit:)``.
public struct EmailSearchHit: Decodable {
    public let id: String
    public let fromAddress: String
    public let toAddresses: [String]
    public let subject: String?
    public let status: String
    public let tags: [String]?
    public let source: String?
    public let createdAt: String?
    public let deliveredAt: String?

    enum CodingKeys: String, CodingKey {
        case id, subject, status, tags, source
        case fromAddress = "from_address"
        case toAddresses = "to_addresses"
        case createdAt = "created_at"
        case deliveredAt = "delivered_at"
    }
}

/// A scheduled email awaiting send.
public struct ScheduledEmail: Decodable {
    public let id: String
    public let fromAddress: String
    public let toAddresses: [String]
    public let subject: String?
    public let status: String
    public let tags: [String]?
    public let scheduledAt: String?
    public let secondsUntilSend: Int
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, subject, status, tags
        case fromAddress = "from_address"
        case toAddresses = "to_addresses"
        case scheduledAt = "scheduled_at"
        case secondsUntilSend = "seconds_until_send"
        case createdAt = "created_at"
    }
}

/// A simple `{ id, status }` acknowledgement.
public struct StatusAck: Decodable {
    public let id: String
    public let status: String
}

// MARK: - Domains

/// A row from ``Domains/list()``: a sending domain and its status.
public struct DomainListItem: Decodable {
    public let id: String
    public let name: String
    public let status: String
    public let createdAt: String?
    public let platformWarning: String?

    enum CodingKeys: String, CodingKey {
        case id, name, status
        case createdAt = "created_at"
        case platformWarning = "platform_warning"
    }
}

/// A DNS record the API expects you to publish for a domain.
public struct DnsRecord: Decodable {
    public let id: String
    public let recordType: String
    public let purpose: String
    public let host: String
    public let value: String
    public let isVerified: Bool
    public let lastCheckedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, purpose, host, value
        case recordType = "record_type"
        case isVerified = "is_verified"
        case lastCheckedAt = "last_checked_at"
    }
}

/// A sending domain with its DKIM selector and DNS records.
public struct Domain: Decodable {
    public let id: String
    public let name: String
    public let status: String
    public let dkimSelector: String?
    public let verifiedAt: String?
    public let createdAt: String?
    public let dnsRecords: [DnsRecord]
    public let platformWarning: String?

    enum CodingKeys: String, CodingKey {
        case id, name, status
        case dkimSelector = "dkim_selector"
        case verifiedAt = "verified_at"
        case createdAt = "created_at"
        case dnsRecords = "dns_records"
        case platformWarning = "platform_warning"
    }
}

/// One row of a domain health report.
public struct DomainHealthCheck: Decodable {
    public struct Record: Decodable {
        public let type: String
        public let host: String
        public let value: String
    }
    public let key: String
    public let label: String
    public let status: String
    public let detail: String
    public let recommendation: String?
    public let record: Record?
}

/// Result of ``Domains/health(_:)``: per-record checks plus a summary tally.
public struct DomainHealth: Decodable {
    public struct Summary: Decodable {
        public let ok: Int
        public let warn: Int
        public let error: Int
        public let info: Int
    }
    public let domain: String
    public let checks: [DomainHealthCheck]
    public let summary: Summary
}

/// Result of ``Domains/diagnose(_:)``. `issues` shapes vary; treated as opaque.
public struct DomainDiagnosis: Decodable {
    public let domain: String
    public let issues: [JSONValue]
    public let healthScore: Int

    enum CodingKeys: String, CodingKey {
        case domain, issues
        case healthScore = "health_score"
    }
}

/// Result of ``Domains/rotateDkim(_:)``: the new DKIM record plus the domain.
public struct DkimRotation: Decodable {
    public let dkimRecordHost: String
    public let dkimRecordValue: String
    public let domain: Domain

    enum CodingKeys: String, CodingKey {
        case domain
        case dkimRecordHost = "dkim_record_host"
        case dkimRecordValue = "dkim_record_value"
    }
}

/// A domain transfer record returned by ``Domains/transfer(_:targetEmail:note:)``.
public struct DomainTransfer: Decodable {
    public let id: String
    public let domainId: String
    public let domainName: String?
    public let sourceLabel: String?
    public let targetEmail: String
    public let status: String
    public let note: String?
    public let cooloffUntil: String?
    public let initiatedAt: String
    public let acceptedAt: String?
    public let completedAt: String?
    public let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case id, status, note
        case domainId = "domain_id"
        case domainName = "domain_name"
        case sourceLabel = "source_label"
        case targetEmail = "target_email"
        case cooloffUntil = "cooloff_until"
        case initiatedAt = "initiated_at"
        case acceptedAt = "accepted_at"
        case completedAt = "completed_at"
        case expiresAt = "expires_at"
    }
}

/// Result of ``Domains/checkAvailability(_:)``.
public struct DomainAvailability: Decodable {
    public let available: Bool
    public let reason: String?
    public let detail: String?
    public let staleTokens: Int?

    enum CodingKeys: String, CodingKey {
        case available, reason, detail
        case staleTokens = "stale_tokens"
    }
}

/// Result of ``Domains/check(_:)``: whether a domain name exists in your account.
public struct DomainCheck: Decodable {
    public let exists: Bool
    public let verified: Bool
    public let status: String?
    public let domain: String
    public let id: String?
}

// MARK: - Contacts

/// A subscriber list.
public struct ContactList: Decodable {
    public let id: String
    public let name: String
    public let description: String?
    public let iconSeed: String?
    public let contactCount: Int
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case iconSeed = "icon_seed"
        case contactCount = "contact_count"
        case createdAt = "created_at"
    }
}

/// A single contact in a list.
public struct Contact: Decodable {
    public let id: String
    public let email: String
    public let name: String?
    public let metadata: JSONObject?
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, email, name, metadata
        case createdAt = "created_at"
    }
}

/// A contact list with a page of its contacts.
public struct ContactListDetail: Decodable {
    public let id: String
    public let name: String
    public let description: String?
    public let iconSeed: String?
    public let contactCount: Int
    public let createdAt: String
    public let contacts: [Contact]

    enum CodingKeys: String, CodingKey {
        case id, name, description, contacts
        case iconSeed = "icon_seed"
        case contactCount = "contact_count"
        case createdAt = "created_at"
    }
}

/// Result of ``Contacts/uploadCsv(listId:file:filename:)``.
public struct CsvImportResult: Decodable {
    public let imported: Int
    public let skipped: Int
    public let errors: [String]
}

/// Result of ``Contacts/bulkSend(listId:senderAddressId:subject:html:text:tags:)``.
public struct BulkSendResult: Decodable {
    public let queued: Int
    public let skipped: Int
    public let errors: [String]
}

// MARK: - Suppressions

/// A suppressed recipient address.
public struct Suppression: Decodable {
    public let id: String
    public let emailAddress: String
    public let reason: String
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, reason
        case emailAddress = "email_address"
        case createdAt = "created_at"
    }
}

/// Result of ``Suppressions/bulkUpload(file:filename:)``.
public struct BulkSuppressionResult: Decodable {
    public let added: Int
    public let skipped: Int
    public let totalProcessed: Int

    enum CodingKeys: String, CodingKey {
        case added, skipped
        case totalProcessed = "total_processed"
    }
}

// MARK: - Templates

/// A reusable email template. `variables` is derived server-side and read-only.
public struct Template: Decodable {
    public let id: String
    public let name: String
    public let subject: String?
    public let htmlBody: String?
    public let textBody: String?
    public let variables: [String]?
    public let blocksJson: JSONObject?
    public let createdAt: String
    public let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, subject, variables
        case htmlBody = "html_body"
        case textBody = "text_body"
        case blocksJson = "blocks_json"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Webhooks

/// A configured webhook endpoint. `secret` is returned in plaintext.
public struct Webhook: Decodable {
    public let id: String
    public let url: String
    public let events: [String]
    public let secret: String
    public let isActive: Bool
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, url, events, secret
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

/// A test result `{ queued, url }`.
public struct WebhookTestResult: Decodable {
    public let queued: Bool
    public let url: String
}

/// A summary of one webhook delivery attempt.
public struct WebhookDelivery: Decodable {
    public let id: String
    public let webhookId: String
    public let eventType: String?
    public let status: String
    public let responseStatus: Int?
    public let attempt: Int
    public let nextRetryAt: String?
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, attempt
        case webhookId = "webhook_id"
        case eventType = "event_type"
        case responseStatus = "response_status"
        case nextRetryAt = "next_retry_at"
        case createdAt = "created_at"
    }
}

/// A webhook delivery with the full payload and endpoint response.
public struct WebhookDeliveryDetail: Decodable {
    public let id: String
    public let webhookId: String
    public let eventType: String?
    public let status: String
    public let responseStatus: Int?
    public let attempt: Int
    public let nextRetryAt: String?
    public let createdAt: String?
    public let payload: JSONObject
    public let responseBody: String?
    public let endpointUrl: String

    enum CodingKeys: String, CodingKey {
        case id, status, attempt, payload
        case webhookId = "webhook_id"
        case eventType = "event_type"
        case responseStatus = "response_status"
        case nextRetryAt = "next_retry_at"
        case createdAt = "created_at"
        case responseBody = "response_body"
        case endpointUrl = "endpoint_url"
    }
}
