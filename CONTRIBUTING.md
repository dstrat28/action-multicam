# Contributing

Thanks for helping make Multicam better.

## Development

Use Xcode 15 or newer and build the `ActionCamRemote` scheme. Simulator builds are useful for UI work, but hardware features require a physical iPhone or iPad because iOS Simulator cannot connect to real Bluetooth cameras.

```sh
xcodebuild \
  -project ActionCamRemote.xcodeproj \
  -scheme ActionCamRemote \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Hardware Reports

Camera behavior varies by model, firmware, and power state. Good reports include:

- camera model and firmware version;
- iOS/iPadOS version;
- whether the camera was on, asleep, or off;
- whether the app showed Connected, Available, or Not Connected;
- what command was sent;
- what happened on the physical camera;
- copied diagnostics if you are comfortable sharing them.

Review diagnostics before posting publicly. They may contain Bluetooth identifiers, camera names, service UUIDs, and raw command bytes.

## Protocol Work

GoPro changes should prefer public Open GoPro behavior and docs. DJI changes should stay model-scoped when possible because the app currently relies on experimental DUML-style BLE behavior that can differ across cameras.

Keep public docs honest: mark hardware as tested only after physical-device verification.
