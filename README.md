# Taifa Mail Swift SDK

The official Swift SDK for [Taifa Mail](https://govconnect.ke), the email
platform for the Kenyan public service: bulk and transactional email from
your institution's official domain.

Foundation `URLSession` with async/await. No third-party dependencies.
Swift 5.9+, macOS 12+, iOS 15+.

## Install

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/GovConnectKenya/taifa-mail-swift", from: "0.1.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "TaifaMailSDK", package: "taifa-mail-swift")
    ])
]
```

In Xcode: File, Add Package Dependencies, paste the repository URL, and add the
`TaifaMailSDK` library product.

## Quickstart

```swift
import TaifaMailSDK

let taifamail = TaifaMailClient(apiKey: "axm_k_...")

// Send an email. A bare string is sugar for an Address.
let result = try await taifamail.emails.send(.init(
    from: "hello@yourdomain.com",
    to: ["customer@example.com"],
    subject: "Your receipt",
    html: "<p>Thanks for your order.</p>"
))
print(result.id, result.status)
```

The client is safe to construct once and reuse.

## Configuration

```swift
let taifamail = TaifaMailClient(
    apiKey: "axm_k_...",
    baseURL: "https://govconnect.ke", // override for staging
    maxRetries: 3,                    // total attempts on 429 / 5xx
    timeout: 30                       // per-request seconds
)
```

Retries on `429` and `5xx` use exponential backoff and honour the `Retry-After`
header. `4xx` responses are never retried.

## Resources

Every method is `async throws`.

### emails

```swift
try await taifamail.emails.send(params)
try await taifamail.emails.sendBatch([params1, params2])     // bare array, per-plan cap
try await taifamail.emails.validate(params)                  // dry-run, never sends
try await taifamail.emails.list(status: "delivered", page: 0, limit: 20)
try await taifamail.emails.get(id)
try await taifamail.emails.events(id)
try await taifamail.emails.retry(id)
try await taifamail.emails.search(q: "to:alice status:bounced")
try await taifamail.emails.listScheduled()
try await taifamail.emails.cancelScheduled(id)
try await taifamail.emails.sendScheduledNow(id)
try await taifamail.emails.updates(since: "2026-06-13T00:00:00Z")
try await taifamail.emails.getSavedSearches()
try await taifamail.emails.setSavedSearches(searches)
```

### domains

```swift
try await taifamail.domains.list()
try await taifamail.domains.create("send.yourdomain.com")
try await taifamail.domains.get(id)
try await taifamail.domains.delete(id)
try await taifamail.domains.verify(id)
try await taifamail.domains.health(id)
try await taifamail.domains.diagnose(id)
try await taifamail.domains.mxStatus(id)
try await taifamail.domains.publishedRecords(id)
try await taifamail.domains.rotateDkim(id)
try await taifamail.domains.transfer(id, targetEmail: "new@owner.com", note: "handover")
try await taifamail.domains.checkAvailability("send.yourdomain.com")
try await taifamail.domains.check("send.yourdomain.com")
```

### contacts

```swift
try await taifamail.contacts.listLists()
try await taifamail.contacts.createList(name: "Newsletter", iconSeed: "seed")
try await taifamail.contacts.getList(listId, page: 0, limit: 50)
try await taifamail.contacts.updateList(listId, name: "Renamed")
try await taifamail.contacts.deleteList(listId)
try await taifamail.contacts.addContact(listId, email: "a@x.com", name: "Ann")
try await taifamail.contacts.removeContact(listId, contactId: contactId)
try await taifamail.contacts.uploadCsv(listId, file: csvData, filename: "people.csv")
try await taifamail.contacts.bulkSend(listId, senderAddressId: "sa_1", subject: "Hi {{name}}", html: "<p>...</p>")
```

### suppressions

```swift
try await taifamail.suppressions.list(page: 0, limit: 50)         // paginated envelope
try await taifamail.suppressions.add(email: "bad@x.com")
try await taifamail.suppressions.bulkUpload(file: txtData, filename: "block.txt")
try await taifamail.suppressions.remove(id)
```

### templates

```swift
try await taifamail.templates.list()
try await taifamail.templates.create(name: "Welcome", html: "<p>Hi {{name}}</p>")
try await taifamail.templates.get(id)
try await taifamail.templates.update(id, subject: "Updated")
try await taifamail.templates.delete(id)
try await taifamail.templates.duplicate(id)
```

### webhooks

```swift
try await taifamail.webhooks.list()
try await taifamail.webhooks.create(url: "https://you.com/cb", events: ["email.delivered"])
try await taifamail.webhooks.update(id, isActive: false)
try await taifamail.webhooks.delete(id)
try await taifamail.webhooks.test(id)
try await taifamail.webhooks.listDeliveries(id, page: 0, limit: 20)   // paginated envelope
try await taifamail.webhooks.getDelivery(id, deliveryId: deliveryId)
```

## Error handling

Every non-2xx response (and any transport failure that survives retries) throws
an `TaifaMailError`:

```swift
do {
    try await taifamail.emails.send(params)
} catch let error as TaifaMailError {
    print(error.status)   // e.g. 422, or 0 for a network failure
    print(error.code)     // machine-readable code when present
    print(error.message)  // human-readable message
}
```

## Notes

- Pagination is zero-based (`page: 0` is the first page).
- Bare-array endpoints return a plain `[T]`; envelope endpoints return `Page<T>`.
- Loosely-typed shapes (open maps, event metadata, webhook payloads) are exposed
  as `JSONValue` / `JSONObject`.
- The niche domain endpoints (ns-provider, BIMI, domain-connect) are not yet
  covered.

## License

MIT.
