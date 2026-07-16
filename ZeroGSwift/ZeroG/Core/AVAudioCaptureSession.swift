import AudioToolbox
import AVFoundation

/// A fresh AVAudioEngine configured for one recording and one concrete input device.
/// Recreating this object avoids retaining a dead audio route after calls or device changes.
final class AVAudioCaptureSession: AudioCaptureSession {
    private enum CaptureError: LocalizedError {
        case audioUnitUnavailable
        case deviceSelectionFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .audioUnitUnavailable:
                "The microphone audio unit is unavailable."
            case .deviceSelectionFailed(let status):
                "The microphone could not be selected (Core Audio error \(status))."
            }
        }
    }

    private let audioEngine: AVAudioEngine
    private let inputNode: AVAudioInputNode

    let recordingFormat: AVAudioFormat

    init(device: AudioInputDevice) throws {
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        guard let audioUnit = inputNode.audioUnit else {
            throw CaptureError.audioUnitUnavailable
        }

        var deviceID = device.deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw CaptureError.deviceSelectionFailed(status)
        }

        self.audioEngine = audioEngine
        self.inputNode = inputNode
        self.recordingFormat = inputNode.inputFormat(forBus: 0)
    }

    func installTap(
        bufferSize: AVAudioFrameCount,
        handler: @escaping (AVAudioPCMBuffer, AVAudioFormat) -> Void
    ) {
        let format = recordingFormat
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
            handler(buffer, format)
        }
    }

    func start() throws {
        try audioEngine.start()
    }

    func removeTap() {
        inputNode.removeTap(onBus: 0)
    }

    func stop() {
        audioEngine.stop()
    }
}
