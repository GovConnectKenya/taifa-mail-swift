import Foundation

/// Thrown for any non-2xx API response, or for a transport failure that survives
/// all retries.
///
/// Inspect ``status`` and ``code`` to branch on specific failures (for example a
/// `422` with code `"invalid"`). A ``status`` of `0` indicates a transport or
/// network failure where no HTTP response was received.
public struct AxeneError: Error, LocalizedError, CustomStringConvertible {
    /// HTTP status code. `0` indicates a transport/network failure (no response).
    public let status: Int
    /// Machine-readable error code from the API body, when present.
    public let code: String?
    /// Human-readable error message.
    public let message: String

    /// Create an error.
    public init(status: Int, message: String, code: String? = nil) {
        self.status = status
        self.message = message
        self.code = code
    }

    public var errorDescription: String? { message }

    public var description: String {
        if let code {
            return "AxeneError(status: \(status), code: \(code), message: \(message))"
        }
        return "AxeneError(status: \(status), message: \(message))"
    }
}
