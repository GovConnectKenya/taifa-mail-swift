# Axene Mailer Swift SDK

The official Swift SDK for [Axene Mailer](https://mail.axene.io), the email
platform built for Africa: KES pricing, M-Pesa billing, and deliverability tuned
for African ISPs.

Foundation `URLSession` with async/await. No third-party dependencies.
Swift 5.9+, macOS 12+, iOS 15+.

## Install

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/axene/axene-sdks", from: "0.1.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "AxeneMailer", package: "axene-sdks")
    ])
]
```

In Xcode: File, Add Package Dependencies, paste the repository URL, and add the
`AxeneMailer` library product.

## Quickstart

```swift
import AxeneMailer

let axene = AxeneClient(apiKey: "axm_k_...")

// Send an email. A bare string is sugar for an Address.
let result = try await axene.emails.send(.init(
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
let axene = AxeneClient(
    apiKey: "axm_k_...",
    baseURL: "https://mail.axene.io", // override for staging
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
try await axene.emails.send(params)
try await axene.emails.sendBatch([params1, params2])     // bare array, per-plan cap
try await axene.emails.validate(params)                  // dry-run, never sends
try await axene.emails.list(status: "delivered", page: 0, limit: 20)
try await axene.emails.get(id)
try await axene.emails.events(id)
try await axene.emails.retry(id)
try await axene.emails.search(q: "to:alice status:bounced")
try await axene.emails.listScheduled()
try await axene.emails.cancelScheduled(id)
try await axene.emails.sendScheduledNow(id)
try await axene.emails.updates(since: "2026-06-13T00:00:00Z")
try await axene.emails.getSavedSearches()
try await axene.emails.setSavedSearches(searches)
```

### domains

```swift
try await axene.domains.list()
try await axene.domains.create("send.yourdomain.com")
try await axene.domains.get(id)
try await axene.domains.delete(id)
try await axene.domains.verify(id)
try await axene.domains.health(id)
try await axene.domains.diagnose(id)
try await axene.domains.mxStatus(id)
try await axene.domains.publishedRecords(id)
try await axene.domains.rotateDkim(id)
try await axene.domains.transfer(id, targetEmail: "new@owner.com", note: "handover")
try await axene.domains.checkAvailability("send.yourdomain.com")
try await axene.domains.check("send.yourdomain.com")
```

### contacts

```swift
try await axene.contacts.listLists()
try await axene.contacts.createList(name: "Newsletter", iconSeed: "seed")
try await axene.contacts.getList(listId, page: 0, limit: 50)
try await axene.contacts.updateList(listId, name: "Renamed")
try await axene.contacts.deleteList(listId)
try await axene.contacts.addContact(listId, email: "a@x.com", name: "Ann")
try await axene.contacts.removeContact(listId, contactId: contactId)
try await axene.contacts.uploadCsv(listId, file: csvData, filename: "people.csv")
try await axene.contacts.bulkSend(listId, senderAddressId: "sa_1", subject: "Hi {{name}}", html: "<p>...</p>")
```

### suppressions

```swift
try await axene.suppressions.list(page: 0, limit: 50)         // paginated envelope
try await axene.suppressions.add(email: "bad@x.com")
try await axene.suppressions.bulkUpload(file: txtData, filename: "block.txt")
try await axene.suppressions.remove(id)
```

### templates

```swift
try await axene.templates.list()
try await axene.templates.create(name: "Welcome", html: "<p>Hi {{name}}</p>")
try await axene.templates.get(id)
try await axene.templates.update(id, subject: "Updated")
try await axene.templates.delete(id)
try await axene.templates.duplicate(id)
```

### webhooks

```swift
try await axene.webhooks.list()
try await axene.webhooks.create(url: "https://you.com/cb", events: ["email.delivered"])
try await axene.webhooks.update(id, isActive: false)
try await axene.webhooks.delete(id)
try await axene.webhooks.test(id)
try await axene.webhooks.listDeliveries(id, page: 0, limit: 20)   // paginated envelope
try await axene.webhooks.getDelivery(id, deliveryId: deliveryId)
```

## Error handling

Every non-2xx response (and any transport failure that survives retries) throws
an `AxeneError`:

```swift
do {
    try await axene.emails.send(params)
} catch let error as AxeneError {
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
