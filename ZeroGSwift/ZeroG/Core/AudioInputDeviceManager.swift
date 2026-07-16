import CoreAudio
import Foundation

/// Discovers macOS input devices and persists an explicit external-microphone choice.
/// With no explicit choice, the Mac's built-in microphone always wins over the
/// current system default so calls and newly connected devices cannot reroute ZeroG.
final class AudioInputDeviceManager {
    private static let selectedUIDDefaultsKey = "AudioInputDeviceUID"

    private let defaults: UserDefaults
    private let deviceProvider: () -> [AudioInputDevice]

    init(
        defaults: UserDefaults = .standard,
        deviceProvider: @escaping () -> [AudioInputDevice] = AudioInputDeviceManager.discoverDevices
    ) {
        self.defaults = defaults
        self.deviceProvider = deviceProvider
    }

    var availableDevices: [AudioInputDevice] {
        deviceProvider().sorted { left, right in
            if left.isBuiltIn != right.isBuiltIn {
                return left.isBuiltIn
            }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
    }

    var selectedDevice: AudioInputDevice? {
        let devices = availableDevices
        if let selectedUID = defaults.string(forKey: Self.selectedUIDDefaultsKey),
           let selected = devices.first(where: { $0.uid == selectedUID }) {
            return selected
        }
        return devices.first(where: \.isBuiltIn) ?? devices.first
    }

    /// Built-in is the durable default, so selecting it clears any external override.
    func select(_ device: AudioInputDevice) {
        if device.isBuiltIn {
            defaults.removeObject(forKey: Self.selectedUIDDefaultsKey)
        } else {
            defaults.set(device.uid, forKey: Self.selectedUIDDefaultsKey)
        }
    }

    private static func discoverDevices() -> [AudioInputDevice] {
        allDeviceIDs().compactMap { deviceID in
            guard hasInputStreams(deviceID),
                  let uid = stringProperty(
                    kAudioDevicePropertyDeviceUID,
                    deviceID: deviceID
                  ),
                  let name = stringProperty(
                    kAudioObjectPropertyName,
                    deviceID: deviceID
                  ) else {
                return nil
            }

            return AudioInputDevice(
                deviceID: deviceID,
                uid: uid,
                name: name,
                isBuiltIn: transportType(deviceID) == kAudioDeviceTransportTypeBuiltIn
            )
        }
    }

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        ) == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.stride
        guard count > 0 else { return [] }
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        let status = deviceIDs.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return OSStatus(-50) }
            return AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &dataSize,
                baseAddress
            )
        }
        return status == noErr ? deviceIDs : []
    }

    private static func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        return AudioObjectGetPropertyDataSize(
            deviceID,
            &address,
            0,
            nil,
            &dataSize
        ) == noErr && dataSize >= MemoryLayout<AudioStreamID>.stride
    }

    private static func stringProperty(
        _ selector: AudioObjectPropertySelector,
        deviceID: AudioDeviceID
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &value
        ) == noErr, let value else {
            return nil
        }
        return value.takeRetainedValue() as String
    }

    private static func transportType(_ deviceID: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &value
        ) == noErr else {
            return 0
        }
        return value
    }
}
