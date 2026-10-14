# Auto Clicker

A small native auto clicker for Apple Silicon Macs, written in Swift and SwiftUI.

- Fixed click interval (hours / minutes / seconds / milliseconds) or a random interval range
- Left, right, or middle mouse button
- Repeat N times or until stopped
- Global start/stop hotkey (default ⇧⌘S); click the hotkey button and press a new shortcut to change it
- Clicks are skipped while the pointer is over the app's own window, so Stop is always reachable

## Building

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
scripts/build.sh              # build Release and install to /Applications
scripts/build.sh --no-install # build only
```

To work in Xcode, run `xcodegen generate` and open `AutoClicker.xcodeproj`. The project file is
generated from `project.yml`, so make project setting changes there.

## Permissions

Auto Clicker needs **Accessibility** access to send clicks to other apps
(System Settings › Privacy & Security › Accessibility). The app shows a banner with a shortcut to
that pane until access is granted.

## Code signing

macOS ties the Accessibility permission to the app's code signature. Builds are signed with a
local self-signed identity named **AutoClicker Local Signing** (kept in
`~/Library/Keychains/autoclicker-signing.keychain-db`) so the signature — and the permission —
survives rebuilds. To use your Apple ID instead, set `CODE_SIGN_IDENTITY` to `Apple Development`
and `DEVELOPMENT_TEAM` to your team ID in `project.yml`.

The app isn't sandboxed (sandboxed apps can't post mouse events), so it can't be distributed
through the Mac App Store.
