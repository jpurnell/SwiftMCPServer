import Foundation

/// Privacy level for log message interpolation values
///
/// Mirrors Apple's OSLogPrivacy for use with swift-log's Logger.
/// Ensures interpolated values in log messages are annotated with
/// their intended privacy level.
public enum LogPrivacy: Sendable {
    /// Value may appear in logs visible to operators
    case `public`
    /// Value should be redacted in production logs
    case `private`
}

extension DefaultStringInterpolation {
    /// Appends a privacy-annotated value to the interpolation
    /// - Parameters:
    ///   - value: The value to interpolate
    ///   - privacy: The privacy level for this value
    mutating func appendInterpolation<T>(_ value: T, privacy: LogPrivacy) {
        switch privacy {
        case .public:
            appendLiteral("\(value)")
        case .private:
            appendLiteral("<private>")
        }
    }
}
