import Foundation

/// Taifa Mail API client.
///
/// Construct it with your API key, then reach the resource groups:
/// ``emails``, ``domains``, ``contacts``, ``suppressions``, ``templates``,
/// and ``webhooks``.
///
/// ```swift
/// let taifamail = TaifaMailClient(apiKey: "tfm_k_...")
/// let result = try await taifamail.emails.send(
///     .init(from: "hello@yourdomain.com",
///           to: ["customer@example.com"],
///           subject: "Your receipt",
///           html: "<p>Thanks for your order.</p>")
/// )
/// ```
public final class TaifaMailClient {
    /// Send, search, schedule, and inspect emails.
    public let emails: Emails
    /// Register, verify, and transfer sending domains.
    public let domains: Domains
    /// Manage subscriber lists and bulk sends.
    public let contacts: Contacts
    /// Manage the do-not-send suppression list.
    public let suppressions: Suppressions
    /// Manage reusable email templates.
    public let templates: Templates
    /// Manage event webhooks and inspect deliveries.
    public let webhooks: Webhooks

    /// Create a client from full options.
    public init(options: TaifaMailOptions) {
        let transport = Transport(options)
        self.emails = Emails(transport)
        self.domains = Domains(transport)
        self.contacts = Contacts(transport)
        self.suppressions = Suppressions(transport)
        self.templates = Templates(transport)
        self.webhooks = Webhooks(transport)
    }

    /// Create a client with an API key and optional overrides.
    public convenience init(
        apiKey: String,
        baseURL: String = "https://govconnect.ke",
        maxRetries: Int = 3,
        timeout: TimeInterval = 30,
        session: URLSession = .shared
    ) {
        self.init(options: TaifaMailOptions(
            apiKey: apiKey,
            baseURL: baseURL,
            maxRetries: maxRetries,
            timeout: timeout,
            session: session
        ))
    }
}
