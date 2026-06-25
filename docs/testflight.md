# TestFlight

This project is set up for TestFlight through App Store Connect. Xcode Cloud can build on pushes to GitHub; local archive/upload commands are kept here as a fallback.

Public TestFlight link: https://testflight.apple.com/join/ecxSpXZX

## Current App Metadata

- App Store Connect name: `Action Multicam Remote`
- App display name: `Multicam`
- Bundle ID: `com.ds.ActionCamRemote`
- Version: `0.1`
- Next build: `2`
- App Store Connect app ID: `6784017391`
- Team ID: `2WX2Z9452K`

## App Store Connect Status

The App Store Connect app record exists:

- Platform: iOS
- Name: `Action Multicam Remote`
- Bundle ID: `com.ds.ActionCamRemote`
- SKU: `action-multicam-ios`
- Primary language: English (U.S.)

Build `0.1 (1)` was uploaded from Xcode and is visible in TestFlight. Build `0.1 (2)` includes the release-only diagnostics cleanup, `Multicam` in-app title, and `ITSAppUsesNonExemptEncryption=false`.

## Xcode Cloud

Push to GitHub to trigger the configured Xcode Cloud workflow. After the build finishes processing in App Store Connect:

1. Open the app in App Store Connect.
2. Go to TestFlight > iOS.
3. Confirm the latest build is available.
4. Add it to the external beta group.
5. Submit the first external build for Beta App Review.

## Local Archive Fallback

```sh
xcodebuild \
  -project ActionCamRemote.xcodeproj \
  -scheme ActionCamRemote \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/action-multicam-0.1-2.xcarchive \
  DEVELOPMENT_TEAM=2WX2Z9452K \
  -allowProvisioningUpdates \
  clean archive
```

## Local Upload Fallback

```sh
xcodebuild \
  -exportArchive \
  -archivePath /tmp/action-multicam-0.1-2.xcarchive \
  -exportPath /tmp/action-multicam-testflight-export \
  -exportOptionsPlist ci/TestFlightExportOptions.plist \
  -allowProvisioningUpdates
```

If Xcode cannot create distribution signing assets automatically, open Xcode, sign in under Settings > Accounts, and retry the upload from Organizer or with the same command.

## Public TestFlight Link

The public TestFlight beta is available at https://testflight.apple.com/join/ecxSpXZX.
