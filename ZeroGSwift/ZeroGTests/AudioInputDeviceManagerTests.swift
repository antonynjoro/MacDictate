import Foundation
import Testing
@testable import ZeroG

@Suite(.serialized)
struct AudioInputDeviceManagerTests {
    private let builtIn = AudioInputDevice(
        deviceID: 1,
        uid: "built-in",
        name: "MacBook Pro Microphone",
        isBuiltIn: true
    )

    private let external = AudioInputDevice(
        deviceID: 2,
        uid: "external",
        name: "Studio Microphone",
        isBuiltIn: false
    )

    @Test("Built-in microphone is preferred when no selection is stored")
    func builtInIsTheDefault() {
        let defaults = makeDefaults()
        let manager = AudioInputDeviceManager(
            defaults: defaults,
            deviceProvider: { [external, builtIn] }
        )

        #expect(manager.selectedDevice == builtIn)
    }

    @Test("An external microphone can be selected and remembered")
    func externalSelectionIsRemembered() {
        let defaults = makeDefaults()
        let manager = AudioInputDeviceManager(
            defaults: defaults,
            deviceProvider: { [builtIn, external] }
        )

        manager.select(external)

        #expect(manager.selectedDevice == external)
    }

    @Test("Missing selected microphone falls back to the built-in microphone")
    func missingSelectionFallsBackToBuiltIn() {
        var devices = [builtIn, external]
        let defaults = makeDefaults()
        let manager = AudioInputDeviceManager(
            defaults: defaults,
            deviceProvider: { devices }
        )
        manager.select(external)

        devices = [builtIn]

        #expect(manager.selectedDevice == builtIn)
    }

    @Test("Choosing the built-in microphone restores automatic built-in preference")
    func choosingBuiltInRestoresDefault() {
        let defaults = makeDefaults()
        let manager = AudioInputDeviceManager(
            defaults: defaults,
            deviceProvider: { [builtIn, external] }
        )
        manager.select(external)

        manager.select(builtIn)

        #expect(manager.selectedDevice == builtIn)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AudioInputDeviceManagerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
