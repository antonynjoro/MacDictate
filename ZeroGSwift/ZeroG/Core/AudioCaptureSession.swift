import AVFoundation

/// Testable boundary around the AVAudioEngine capture operations used per recording.
protocol AudioCaptureSession: AnyObject {
    var recordingFormat: AVAudioFormat { get }

    func installTap(
        bufferSize: AVAudioFrameCount,
        handler: @escaping (AVAudioPCMBuffer, AVAudioFormat) -> Void
    )
    func start() throws
    func removeTap()
    func stop()
}
