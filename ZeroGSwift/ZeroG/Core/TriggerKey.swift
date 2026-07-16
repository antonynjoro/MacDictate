import Foundation
import CoreGraphics

/// A modifier key that can be held to trigger recording.
struct TriggerKey: Equatable {
    let id: String
    let displayName: String
    let keyCode: CGKeyCode
    /// Device-specific NX flag bit (not generic masks like maskControl).
    /// Device bits distinguish left from right, preventing stuck-recording
    /// when both sides of the same modifier family are held simultaneously.
    let deviceFlagMask: UInt64
    /// Generic CGEventFlags mask for the key's modifier family (maskControl,
    /// maskShift, …). Used by the release watchdog to poll the session's live
    /// flags via `CGEventSource.flagsState` — per-keycode `keyState` misreports
    /// held modifiers (e.g. Right Shift reads "up" while physically held).
    let familyFlagMask: CGEventFlags

    static let allOptions: [TriggerKey] = [
        TriggerKey(id: "leftControl",  displayName: "Left Control",  keyCode: 59, deviceFlagMask: 0x00000001, familyFlagMask: .maskControl),
        TriggerKey(id: "rightControl", displayName: "Right Control", keyCode: 62, deviceFlagMask: 0x00002000, familyFlagMask: .maskControl),
        TriggerKey(id: "leftOption",   displayName: "Left Option",   keyCode: 58, deviceFlagMask: 0x00000020, familyFlagMask: .maskAlternate),
        TriggerKey(id: "rightOption",  displayName: "Right Option",  keyCode: 61, deviceFlagMask: 0x00000040, familyFlagMask: .maskAlternate),
        TriggerKey(id: "rightShift",   displayName: "Right Shift",   keyCode: 60, deviceFlagMask: 0x00000004, familyFlagMask: .maskShift),
        TriggerKey(id: "fn",           displayName: "Fn / Globe",    keyCode: 63, deviceFlagMask: 0x00800000, familyFlagMask: .maskSecondaryFn),
    ]

    static let defaultKey = allOptions[0]

    static func from(id: String) -> TriggerKey {
        allOptions.first { $0.id == id } ?? defaultKey
    }
}
