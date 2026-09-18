# Mnemosyne Island demo

Four approved states in one native iPhone Live Activity, controlled from Flutter.
This is a UI prototype: it does not record audio, connect to a ring, transcribe speech,
run agents, send push notifications or relaunch after a ring press when force-quit.

## Open it on your Mac

1. Unzip the download. Move the **mnemosyne_island_demo** folder to `~/Developer`.
   Keep your original `mnemosyne_island` folder as a backup.
2. In Terminal:

   ```sh
   cd ~/Developer/mnemosyne_island_demo
   flutter pub get
   flutter build ios --config-only --release --no-codesign
   open ios/Runner.xcworkspace
   ```

   The configuration command regenerates machine-specific Flutter files and the
   generated Swift package. Do not run `flutter create` again.
3. In Xcode, click the blue **Runner** project at the top of the left sidebar.
   Under **TARGETS**, choose **Runner → Signing & Capabilities**. Enable
   **Automatically manage signing** and select your Apple development team.
   Repeat for **MnemosyneActivityExtension**, using the same team.
   If the team list is empty, add your Apple account in Xcode Settings → Accounts.
4. Connect and unlock your iPhone 15 by cable. Accept **Trust This Computer**.
   Enable iPhone **Settings → Privacy & Security → Developer Mode** if requested;
   this requires restarting and confirming on the phone.
5. At the top of Xcode, choose the **Runner** scheme and your **physical iPhone**
   as the run destination. Return to Terminal and run:

   ```sh
   flutter run --release
   ```

   If asked to choose a device, choose your iPhone. This builds and installs the app
   plus its Live Activity extension. Release mode also allows opening the installed
   app later without a Flutter debugging session.

You do not need a simulator runtime to test on your physical phone. If your phone
is missing, inspect **Window → Devices and Simulators**. Xcode may still need
platform/device support under Settings → Components; that is distinct from choosing
a simulator. If an error appears, capture the first red build error rather than all
of the build log.

If a bundle identifier is unavailable for your team, change Runner's identifier
and make the extension identifier start with that exact identifier plus a suffix.
Example: app `one.antimattr.arnav.mnemosyne`; extension
`one.antimattr.arnav.mnemosyne.MnemosyneActivity`.
Do not change the method-channel name or the `mnemosyne` URL scheme.

## Try all four states

Choose a state in the app, then swipe up to go Home. Long-press the Island to expand
it. Reopen the app to choose the next state. iOS decides the Island's precise size,
visibility and timing; the app does not force a call-style expansion.

| State | Compact | Expanded |
| --- | --- | --- |
| Recording | Small white ring, red dot, `[rec]` | Recording and elapsed time |
| Processing | White sinusoid, `[tinkering]`, no dot | Transcribing your speech |
| Agent working | White cursor, green dot, `[working]` | Instinct |
| Needs approval | Amber exclamation, `[approve]` | Instinct and Review link |

**Review** opens the Instinct demo screen. It does not approve an action.
**End Live Activity** removes this demo's activities.
A matching card is included on the Lock Screen. The minimal presentation is also
implemented for when iOS displays multiple activities.

The four buttons update one activity, not four simultaneous activities. Starting
Recording after a different phase resets its elapsed timer; tapping Recording again
while already recording keeps the same timer.

## Animation scope

The Flutter screen includes an animated concept preview: the ring turns, the wave
moves and the cursor subtly moves. These respect Reduce Motion.
The actual system Island uses static vector glyphs and system-managed state
transitions. Its recording timer updates using Apple's system timer view.
Continuous custom ring or wave animation is **not implemented or promised** in the
system Island; widget code is not a continuously running Flutter canvas.
See [Apple's explanation of widget animation](https://developer.apple.com/videos/play/wwdc2023/10028/).

## Verification

Before delivery, Swift and Dart files passed syntax parsing; property lists and the
Xcode project parsed; the shared model's membership in both targets was checked.
A separate source review checked the channel and cold/warm Review URL routing.

**No Xcode or Flutter SDK was available in the build workspace.** Native compilation,
Flutter analysis/tests, actual device layout and tap behavior still need verification
on your Mac/iPhone. Syntax parsing is not a substitute for compiling.

On the Mac you can also run:

```sh
flutter analyze
flutter test
```

Device acceptance checks:

- All four compact and expanded states fit the iPhone 15 without clipping.
- The recording timer advances while the app is in the background.
- Switching phases does not leave duplicate Live Activities.
- Review opens Instinct from the expanded Island and the Lock Screen card.
- End removes the activity. Starting again works.
- Disabling Live Activities in iPhone Settings produces a clear disabled state;
  re-enable and refresh to recover.

This prototype does not validate the separate Bluetooth/force-quit/server research.

## Where the code lives

- `lib/main.dart`: Flutter controls, animated in-app preview and review screen.
- `ios/Runner/AppDelegate.swift`: Flutter channel and ActivityKit start/update/end.
- `ios/Runner/SceneDelegate.swift`: routes Review links on warm and cold launches.
- `ios/MnemosyneActivity/MnemosyneAttributes.swift`: shared state model, compiled into both targets.
- `ios/MnemosyneActivity/MnemosyneActivityLiveActivity.swift`: real compact, expanded, minimal and Lock Screen views.
- `ios/MnemosyneActivity/Glyphs.swift`: small native vector glyphs.

Extension embedding is placed before Flutter’s Run Script following the
[Flutter extension setup guide](https://docs.flutter.dev/platform-integration/ios/app-extensions).
The project minimum is iOS 17.2. Its current Flutter template uses the scene-based
engine lifecycle; setup follows [Flutter's migration documentation](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate).
The prototype uses a direct platform channel and adds no third-party Flutter plugin.
No App Group, microphone background mode or push entitlement is required for this
local foreground-started UI demo.
