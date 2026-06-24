# Camera Compatibility Notes

Updated: 2026-06-24

## Architecture

Bluetooth is the primary transport because Multicam needs to control multiple cameras at the same time. Wi-Fi can be added later for single-camera live preview, media browsing, or operations that require the camera access point, but the current app avoids a design that assumes the phone can join several camera Wi-Fi networks at once.

Brand-specific protocol details live behind `BLECameraDeviceClient` implementations:

- `GoProBLEClient` uses Open GoPro BLE commands, settings, and query/status packets.
- `DJIExperimentalBLEClient` uses experimental DUML-style packets over DJI BLE services.

## GoPro HERO13 Black

Status: tested.

Implemented:

- discovery using advertised service `0xFEA6`;
- command/control, settings, query, and response characteristics;
- keepalive;
- shutter on/off;
- status registration/query;
- recording-state reads;
- hardware model detection;
- Video preset/group switching;
- explicit wake/connect/start flow from Available state.

Important behavior:

- The app avoids passive auto-connect for remembered GoPros because a BLE connection can wake or keep the camera awake.
- A GoPro can still be selected and started from Available state; that path is an explicit user command.

## DJI Osmo Action 6

Status: tested, experimental.

Implemented:

- BLE discovery and private writable characteristic selection;
- DUML route selection for Action 6;
- record start/stop while the camera is awake and in Video mode;
- Action 6 recording-state reads from the short `0x70` system-state response;
- protection against stale compact status packets that report stopped while the camera is actually recording.

Known limits:

- Sleep wake has not been observed to work over BLE. DJI Mimo also did not find the Action 6 while it was off in local testing, so this may be a camera/firmware limitation rather than an app bug.
- Mode switching is not reliable enough to expose as supported. Put the camera in Video mode on-device before recording.
- Settings control is not mapped.

## DJI Osmo Nano

Status: tested, experimental.

Implemented:

- BLE Available-state detection;
- wake/connect/start flow from Available state;
- record start/stop;
- recording-state reads from DJI camera-state notifications;
- Nano-specific state smoothing for wake/start transitions.

Known limits:

- Mode switching is not reliable enough to expose as supported. Put the camera in Video mode on-device before recording.
- Settings control is not mapped.
- Off/asleep advertisement behavior may vary by firmware and power state.

## DJI Osmo Pocket 3

Status: unverified.

Pocket 3 advertises BLE support, but this project has not yet been tested against physical Pocket 3 hardware. The app identifies Pocket-style DJI names and tries the shared experimental DJI record path. Treat all Pocket 3 behavior as a proof gate until tested.

## Next Proof Gates

1. Test Pocket 3 pairing, record start/stop, and state reads on physical hardware.
2. Capture DJI mode-switch traffic from first-party apps/accessories if reliable Video-mode switching becomes important.
3. Expand GoPro settings support after querying and rendering device-specific capabilities.
4. Decide whether Wi-Fi preview/media workflows belong in this app or a companion tool.
