import AVFoundation
import Testing
@testable import ZeroG

@Suite
struct AudioRecorderRecoveryTests {
    @Test("Recorder rebuilds a stale audio route instead of reporting no microphone")
    func staleRouteIsRebuilt() throws {
        let staleSession = MockAudioCaptureSession(recordingFormat: AVAudioFormat())
        let healthyFormat = try #require(
            AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)
        )
        let healthySession = MockAudioCaptureSession(recordingFormat: healthyFormat)
        var sessions: [MockAudioCaptureSession] = [staleSession, healthySession]
        var factoryCallCount = 0
        let device = AudioInputDevice(
            deviceID: 1,
            uid: "built-in",
            name: "MacBook Pro Microphone",
            isBuiltIn: true
        )

        let recorder = AudioRecorder(
            stateMachine: AppStateMachine(),
            transcriptionEngine: MockTranscriber(),
            inputDeviceProvider: { device },
            captureSessionFactory: { _ in
                factoryCallCount += 1
                return sessions.removeFirst()
            }
        )

        recorder.startRecording()

        #expect(factoryCallCount == 2)
        #expect(staleSession.startCallCount == 0)
        #expect(healthySession.installTapCallCount == 1)
        #expect(healthySession.startCallCount == 1)
    }
}

private final class MockAudioCaptureSession: AudioCaptureSession {
    let recordingFormat: AVAudioFormat
    private(set) var installTapCallCount = 0
    private(set) var startCallCount = 0

    init(recordingFormat: AVAudioFormat) {
        self.recordingFormat = recordingFormat
    }

    func installTap(
        bufferSize: AVAudioFrameCount,
        handler: @escaping (AVAudioPCMBuffer, AVAudioFormat) -> Void
    ) {
        installTapCallCount += 1
    }

    func start() throws {
        startCallCount += 1
    }

    func removeTap() {}
    func stop() {}
}
