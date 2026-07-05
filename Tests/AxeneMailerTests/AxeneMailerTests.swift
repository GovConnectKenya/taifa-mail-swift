import XCTest
@testable import AxeneMailer

final class AxeneMailerTests: XCTestCase {
    private func makeClient(maxRetries: Int = 3) -> AxeneClient {
        AxeneClient(
            apiKey: "axm_k_test",
            baseURL: "https://mail.axene.io",
            maxRetries: maxRetries,
            session: MockURLProtocol.makeSession()
        )
    }

    /// Parse a captured JSON body into a dictionary for assertions.
    private func jsonBody(_ req: CapturedRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(req.body)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    // MARK: bearer header

    func testBearerHeaderAndAuth() async throws {
        MockURLProtocol.enqueue(StubResponse(json: "[]"))
        _ = try await makeClient().emails.list()
        let req = try XCTUnwrap(MockURLProtocol.capturedRequests().first)
        XCTAssertEqual(req.headers["Authorization"], "Bearer axm_k_test")
        XCTAssertTrue(req.url.absoluteString.hasPrefix("https://mail.axene.io/v1/emails/"))
    }

    // MARK: from_ mapping

    func testSendMapsFromToFromUnderscore() async throws {
        MockURLProtocol.enqueue(StubResponse(status: 202, json: #"{"id":"em_1","status":"queued"}"#))
        let res = try await makeClient().emails.send(.init(
            from: Address(email: "hello@yourdomain.com", name: "Acme"),
            to: ["customer@example.com"],
            subject: "Hi",
            html: "<p>Hi</p>"
        ))
        XCTAssertEqual(res.id, "em_1")
        XCTAssertEqual(res.status, "queued")

        let req = try XCTUnwrap(MockURLProtocol.capturedRequests().first)
        let body = try jsonBody(req)
        // The literal wire key must be `from_`, not `from`.
        XCTAssertNotNil(body["from_"], "expected wire key from_")
        XCTAssertNil(body["from"], "must not emit `from`")
        let fromObj = try XCTUnwrap(body["from_"] as? [String: Any])
        XCTAssertEqual(fromObj["email"] as? String, "hello@yourdomain.com")
        XCTAssertEqual(fromObj["name"] as? String, "Acme")
        // String-literal recipient sugar -> {email}.
        let to = try XCTUnwrap(body["to"] as? [[String: Any]])
        XCTAssertEqual(to.first?["email"] as? String, "customer@example.com")
        // Omitted optionals are absent.
        XCTAssertNil(body["text"])
        XCTAssertNil(body["cc"])
    }

    // MARK: batch bare array

    func testSendBatchSendsBareArray() async throws {
        MockURLProtocol.enqueue(StubResponse(status: 202, json: #"{"total":2,"sent":2,"failed":0,"results":[{"id":"a","status":"queued"},{"id":"b","status":"queued"}]}"#))
        let res = try await makeClient().emails.sendBatch([
            .init(from: "a@x.com", to: ["b@y.com"], subject: "1"),
            .init(from: "c@x.com", to: ["d@y.com"], subject: "2")
        ])
        XCTAssertEqual(res.total, 2)
        XCTAssertEqual(res.results.count, 2)

        let req = try XCTUnwrap(MockURLProtocol.capturedRequests().first)
        XCTAssertTrue(req.url.absoluteString.hasSuffix("/v1/emails/batch"))
        let data = try XCTUnwrap(req.body)
        let arr = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertEqual(arr.count, 2)
        XCTAssertEqual((arr[0]["from_"] as? [String: Any])?["email"] as? String, "a@x.com")
    }

    // MARK: validate full body

    func testValidateSendsFullBody() async throws {
        MockURLProtocol.enqueue(StubResponse(json: #"{"valid":true,"can_send":true,"issues":[],"plan":"starter","usage":{"daily":1,"daily_limit":100,"monthly":5,"monthly_limit":1000}}"#))
        let res = try await makeClient().emails.validate(.init(
            from: "a@x.com",
            to: ["b@y.com"],
            subject: "Check",
            text: "body",
            tags: ["t1"]
        ))
        XCTAssertTrue(res.valid)
        XCTAssertTrue(res.canSend)
        XCTAssertEqual(res.plan, "starter")
        XCTAssertEqual(res.usage.dailyLimit, 100)

        let req = try XCTUnwrap(MockURLProtocol.capturedRequests().first)
        XCTAssertTrue(req.url.absoluteString.hasSuffix("/v1/emails/validate"))
        let body = try jsonBody(req)
        XCTAssertEqual(body["subject"] as? String, "Check")
        XCTAssertEqual(body["text"] as? String, "body")
        XCTAssertEqual(body["tags"] as? [String], ["t1"])
        XCTAssertNotNil(body["from_"])
    }

    // MARK: multipart upload field `file`

    func testUploadCsvUsesMultipartFileField() async throws {
        MockURLProtocol.enqueue(StubResponse(json: #"{"imported":3,"skipped":1,"errors":[]}"#))
        let csv = "email,name\na@x.com,A\n".data(using: .utf8)!
        let res = try await makeClient().contacts.uploadCsv("list_1", file: csv, filename: "people.csv")
        XCTAssertEqual(res.imported, 3)
        XCTAssertEqual(res.skipped, 1)

        let req = try XCTUnwrap(MockURLProtocol.capturedRequests().first)
        let ct = try XCTUnwrap(req.headers["Content-Type"])
        XCTAssertTrue(ct.hasPrefix("multipart/form-data; boundary="), "got \(ct)")
        let bodyStr = String(data: try XCTUnwrap(req.body), encoding: .utf8) ?? ""
        XCTAssertTrue(bodyStr.contains("name=\"file\""), "multipart field must be `file`")
        XCTAssertTrue(bodyStr.contains("filename=\"people.csv\""))
        XCTAssertTrue(bodyStr.contains("a@x.com"))
    }

    // MARK: suppressions envelope + email_address mapping

    func testSuppressionsEnvelopeAndAddMapping() async throws {
        MockURLProtocol.enqueue(StubResponse(json: #"{"items":[{"id":"s1","email_address":"bad@x.com","reason":"bounce","created_at":"2026-01-01T00:00:00Z"}],"total":1,"page":0,"limit":50}"#))
        let page = try await makeClient().suppressions.list()
        XCTAssertEqual(page.total, 1)
        XCTAssertEqual(page.page, 0)
        XCTAssertEqual(page.limit, 50)
        XCTAssertEqual(page.items.first?.emailAddress, "bad@x.com")

        MockURLProtocol.reset()
        MockURLProtocol.enqueue(StubResponse(status: 201, json: #"{"id":"s2","email_address":"x@y.com","reason":"manual"}"#))
        let added = try await makeClient().suppressions.add(email: "x@y.com")
        XCTAssertEqual(added.emailAddress, "x@y.com")
        let req = try XCTUnwrap(MockURLProtocol.capturedRequests().first)
        let body = try jsonBody(req)
        XCTAssertEqual(body["email_address"] as? String, "x@y.com")
        XCTAssertEqual(body["reason"] as? String, "manual")
        XCTAssertNil(body["email"], "must map email -> email_address")
    }

    // MARK: webhooks is_active mapping

    func testWebhookUpdateMapsIsActive() async throws {
        MockURLProtocol.enqueue(StubResponse(json: #"{"id":"w1","url":"https://h.x/cb","events":["email.delivered"],"secret":"sk","is_active":false,"created_at":"2026-01-01T00:00:00Z"}"#))
        let hook = try await makeClient().webhooks.update("w1", isActive: false)
        XCTAssertEqual(hook.isActive, false)
        let req = try XCTUnwrap(MockURLProtocol.capturedRequests().first)
        let body = try jsonBody(req)
        XCTAssertEqual(body["is_active"] as? Bool, false)
        XCTAssertNil(body["isActive"], "must map isActive -> is_active")
        // Omitted optionals absent.
        XCTAssertNil(body["url"])
        XCTAssertNil(body["events"])
    }

    // MARK: 429 retry then success

    func testRetriesOn429ThenSucceeds() async throws {
        MockURLProtocol.enqueue(StubResponse(status: 429, headers: ["Retry-After": "0"], json: #"{"detail":"slow down"}"#))
        MockURLProtocol.enqueue(StubResponse(status: 200, json: "[]"))
        let emails = try await makeClient(maxRetries: 3).emails.list()
        XCTAssertEqual(emails.count, 0)
        // Two attempts: the 429, then the success.
        XCTAssertEqual(MockURLProtocol.capturedRequests().count, 2)
    }

    // MARK: error mapping

    func testMapsStructuredError() async throws {
        MockURLProtocol.enqueue(StubResponse(status: 422, json: #"{"detail":{"code":"unverified_sender","message":"Sender not verified"}}"#))
        do {
            _ = try await makeClient(maxRetries: 1).emails.send(.init(from: "a@x.com", to: ["b@y.com"], subject: "s"))
            XCTFail("expected AxeneError")
        } catch let error as AxeneError {
            XCTAssertEqual(error.status, 422)
            XCTAssertEqual(error.code, "unverified_sender")
            XCTAssertEqual(error.message, "Sender not verified")
        }
    }
}
