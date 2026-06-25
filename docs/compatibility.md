# Camera Compatibility Notes

Updated: 2026-06-25

## Architecture

Bluetooth is the primary transport because Multicam needs to control multiple cameras at the same time. Wi-Fi can be added later for single-camera live preview, media browsing, or operations that require the camera access point, but the current app avoids a design that assumes the phone can join several camera Wi-Fi networks at once.

Brand-specific protocol details live behind `BLECameraDeviceClient` implementations:

- `GoProBLEClient` uses Open GoPro BLE commands, settings, and query/status packets.
- `DJIExperimentalBLEClient` uses experimental DUML-style packets over DJI BLE services for supported Action/Nano cameras.

The app uses an allowlist for camera control. GoPro models listed by the public Open GoPro BLE API are enabled through the shared GoPro client, with HERO13 Black tested directly. DJI models are enabled only after direct hardware testing because DJI does not publish an equivalent Action/Nano BLE control API.

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

## Other Open GoPro BLE Cameras

Status: compatible, untested.

The public Open GoPro BLE API lists these additional compatible cameras:

- GoPro LIT HERO;
- GoPro MAX 2;
- GoPro HERO12 Black;
- GoPro HERO11 Black Mini;
- GoPro HERO11 Black;
- GoPro HERO10 Black;
- GoPro HERO9 Black.

Implemented:

- model detection from documented advertisement model IDs and common model-code/name strings;
- the same Open GoPro BLE pair/connect, shutter, status, setting, and query client used by HERO13 Black.

Known limits:

- These models have not been verified locally with hardware.
- Wake-from-off, pairing UX, mode switching, and setting/status labels may vary by firmware or model.
- MAX/MAX 2 behavior may require additional camera-specific mode handling because 360 camera settings differ from HERO cameras.

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

Status: not supported.

Pocket 3 is recognized by name/model so it can be shown clearly in the app, but pairing, selection, and record controls are disabled.

What local testing found:

- Pocket 3 advertises BLE and can send status-like traffic.
- Physical record-button presses produced incoming notifications, but replaying those packets and sending the known DJI Action/Nano record command families did not start or stop recording.
- DJI's public Pocket 3 docs describe phone control through Bluetooth plus Wi-Fi, and LightCut/Mimo-style flows appear to use Bluetooth for discovery/handshake before joining the camera Wi-Fi network.

Current decision:

- Do not claim Pocket 3 BLE-only recording support.
- Do not include Pocket 3 in multicam selection or automatic reconnect.
- Revisit only if a reproducible BLE command path or official API becomes available.

## Other Cameras

Status: not supported.

Any camera outside the documented Open GoPro BLE list, DJI Osmo Action 6, and DJI Osmo Nano is shown as Unsupported. Future GoPro models, older unsupported GoPro models, and other DJI models stay disabled until their BLE behavior is tested or documented clearly enough to map explicitly.

## Next Proof Gates

1. Capture DJI mode-switch traffic from first-party apps/accessories if reliable Video-mode switching becomes important.
2. Expand GoPro settings support after querying and rendering device-specific capabilities.
3. Decide whether Wi-Fi preview/media workflows belong in this app or a companion tool.
4. Revisit Pocket 3 only if a BLE-only control route is found or the app grows a deliberate single-camera Wi-Fi control mode.
