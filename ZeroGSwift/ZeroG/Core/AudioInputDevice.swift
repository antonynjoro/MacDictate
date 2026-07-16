import CoreAudio

/// A physical or virtual macOS audio input that ZeroG can record from.
struct AudioInputDevice: Equatable, Identifiable {
    let deviceID: AudioDeviceID
    let uid: String
    let name: String
    let isBuiltIn: Bool

    var id: String { uid }
}
