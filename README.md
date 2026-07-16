<p align="center">
  <img src="ZeroG_Logo.png" alt="ZeroG logo" width="140">
</p>

# 🧑‍🚀 ZeroG

**Open Source Voice Typing for macOS**

> **"The voice typing tool so good, you'll forget how to type."**

---

## 🛰️ The Manifesto

**We don't type. We transmit.**

ZeroG was born from the realization that typing is a bottleneck. It is a terrestrial limitation. We spent decades training our fingers to hit 100 Words Per Minute (WPM), only to realize that the speed of thought is infinite.

ZeroG is not just a dictation tool. It is an evolutionary step. Just as an astronaut in orbit unlearns the physics of gravity and expects a pen to float rather than fall, ZeroG users unlearn the friction of the keyboard.

We are building the "Air Gap" for your thoughts: **Private. Local. Weightless.**

---

## 🚀 Flight Systems (Features)

- **Zero Friction**: Native Swift running NVIDIA Parakeet on the **Apple Neural Engine** for near-instant transcription. 0 WPM. 100% Output.
- **Vacuum Sealed**: In space, sound doesn't travel. In ZeroG, your voice doesn't travel either. Audio and text are processed entirely on your Mac. No data leaves the ship.
- **Universal Comms**: Hold `Left Control` to transmit thought into *any* application. Release to paste.
- **Gravity Assist** (Optional): Press `⌃⌥P` to polish your last transmission with **Apple Foundation Models**, fully on-device (macOS 26 with Apple Intelligence).
- **Debris Filter**: Strips the "um"s and "uh"s from the feed before payload delivery.
- **Auto-Cut**: A silence sensor cuts the feed if the mic is left open on dead air.
- **Flight Recorder**: A native "Glass" HUD that floats above your dock.

![ZeroG HUD floating above the macOS dock](assets/zerog-hud.png)

---

## 🛠️ Pre-Flight Check (Installation)

### Prerequisites
- macOS 14+ (Apple Silicon recommended for optimal thrust)
- Xcode with a Swift 5.9+ toolchain
- [Git](https://git-scm.com/)

### 1. Board the Ship
```bash
git clone https://github.com/antonynjoro/ZeroG.git
cd ZeroG/ZeroGSwift
./build_app.sh
```

The packaged app lands at `ZeroGSwift/build/ZeroG.app`. Move it to `/Applications` and launch.

First takeoff downloads the transcription model (roughly 460 MB, one time). After that, every flight is fully offline.

### 2. Clearance Codes (Permissions)
First launch runs a guided pre-flight sequence that requests exactly two clearances:

- **Microphone**: Audio input feed.
- **Accessibility**: Detects the trigger key and injects the payload (text) into target fields.

That is the full list. No Input Monitoring. No network clearance. Nothing else.

### 3. Takeoff
Look for the microphone icon in your status bar.

- **Transmit**: Hold `Left Control`. The HUD appears. Speak. Release to paste.
- **Polished Transmission**: Press `⌃⌥P` after a transmission to clean it up and paste the refined version.

---

## 🕹️ Flight Controls (Configuration)

Everything lives in the status bar menu:

- **Trigger Key**: Default is `Left Control`. Swappable.
- **Polish Shortcut**: Default is `⌃⌥P`. Swappable.

### Flight Recorder (Logging)
The Black Box is **OFF** by default for maximum privacy. For development builds, create a `.env` with `DEBUG=true` and reboot systems.

---

## ⚠️ Turbulence (Troubleshooting)

### Payload Failure (Not Pasting)
- Check **System Settings > Privacy & Security > Accessibility**.
- If ZeroG is listed but pasting fails, remove it (-) and re-add it. Old clearance codes expire, especially after rebuilding the app.

### Dead Air (No Audio)
- Check **System Settings > Privacy & Security > Microphone**.
- Ensure we have a lock on your comms.

---

## 🧪 R&D (Development)

### Run From Source
```bash
cd ZeroGSwift
swift run
```

### Run Diagnostics
```bash
cd ZeroGSwift
swift test
```

### Blueprint
- `ZeroGSwift/ZeroG/Core`: Core physics engine (state machine, key monitor, recorder, engines, polish).
- `ZeroGSwift/ZeroG/GUI`: Visual interface (HUD, status bar, onboarding).
- `ZeroGSwift/ZeroGTests`: Simulation scenarios.

---

## 📅 Captain's Log

ZeroG's first prototype flew on Python. In 2026 the whole ship was rebuilt in native Swift.

### [The Swift Era] - 2026
- **Full Rewrite**: Python systems decommissioned. ZeroG is now a native Swift bird: lighter, faster, silent on the pad.
- **New Engine**: NVIDIA Parakeet TDT running on the Apple Neural Engine for near-instant transcription.
- **Gravity Assist 2.0**: Cloud thrusters removed. Polish now runs on-device via Apple Foundation Models. Nothing leaves the ship, ever.
- **Guided Pre-Flight**: New onboarding sequence walks both permission grants on first launch.

### [v0.10.0] - 2026-02-20
- **Parallel Chunk Transcription**: Audio chunked and transcribed in the background while you speak, cutting wait-time for long dictations.

### [v0.9.0] - 2026-01-03
- **Rebrand**: Initiated "ZeroG" protocol.
- **Brand Guide**: Published `BRANDING.md` for all contributors.

### [v0.8.1] - 2026-01-02
- **Hands-Free**: Auto-stop on silence.

### [v0.8.0] - 2026-01-02
- **Universal Injection**: Compatibility across all sectors.

---
*ZeroG: Don't let gravity hold back your thoughts.*
