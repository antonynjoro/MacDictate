import Foundation
import os

// MARK: - Logging

/// Tiny logging facade so call sites don't hand-roll `print("[Module] …")`
/// strings or per-file `#if DEBUG` guards.
///
/// - `debug` is compiled out of release builds and takes its message as an
///   `@autoclosure`, so interpolation cost is never paid when DEBUG is off.
/// - `info`/`error` always log — via os.Logger, NOT NSLog: the unified log
///   redacts NSLog's dynamic content to `<private>` regardless of format
///   specifiers (`%{public}@` is honored by os_log only — verified in the
///   field 2026-07-03). `privacy: .public` on the interpolation is the only
///   thing that keeps `log show` output readable.
enum Log {

    private static let logger = os.Logger(subsystem: "com.zerog.app", category: "app")

    /// Verbose / developer-only logging. No-op in release builds.
    static func debug(_ tag: String, _ message: @autoclosure () -> String) {
        #if DEBUG
        print("[\(tag)] \(message())")
        #endif
    }

    /// Always-on breadcrumb for the dictation pipeline (press/release/stop
    /// reason, audio + inference durations, paste outcome). Sparse by design —
    /// a handful of lines per dictation, enough to reconstruct a flaky field
    /// failure from `log show` without a debug build. Never log transcript
    /// content here — lengths and durations only.
    static func info(_ tag: String, _ message: String) {
        logger.log("[\(tag, privacy: .public)] \(message, privacy: .public)")
    }

    /// Always-on logging for failures and operationally significant events.
    /// Lands in the unified log (Console, filtered by process "ZeroG").
    static func error(_ tag: String, _ message: String) {
        logger.error("[\(tag, privacy: .public)] \(message, privacy: .public)")
    }
}
