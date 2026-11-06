# PewPew

PewPew is an Apple Vision Pro arcade game. You hit targets and beat the clock in a mixed-reality arena. This milestone is the project skeleton: a launcher window, a mixed immersive space, and the empty `PewPewCore` package.

## Requirements

- Xcode 26
- visionOS 2 or later
- An Apple Vision Pro simulator, or Gary's Vision Pro for device runs

## Open the project

Open `pew/PewPew.xcodeproj`. The app target is `PewPew`. Game rules will live in `pew/Packages/PewPewCore` (Swift 6). The app target stays on Swift 5.

## Run in the simulator

1. Select the **PewPew** scheme.
2. Choose an Apple Vision Pro simulator.
3. Run. The launcher shows **PewPew** and **ENTER ARENA**.
4. Enter the arena to see a red cube 1.5 m ahead and an **Exit Arena** button. Exit returns to the launcher.

Hand tracking and world sensing are unavailable in the simulator. The app still requests authorization; the simulator logs the result.

## Deploy to a device

Signing uses a personal team (`com.garywu.pewpew`) with automatic signing.

1. On the Mac: Xcode → Settings → Accounts → add the Apple ID, then set the PewPew target's team.
2. On the Vision Pro: Settings → General → Remote Devices. Keep the Mac and headset on the same Wi-Fi.
3. On the Mac: Xcode → Window → Devices and Simulators → pair with the code shown on the headset.
4. On the Vision Pro: Settings → Privacy & Security → Developer Mode, then restart. Trust the developer profile if prompted (Settings → General → VPN & Device Management).
5. Select the paired Vision Pro as the run destination and run. Entering the arena asks for hand tracking and world sensing permission.

Free provisioning profiles expire 7 days after install, so redeploy at least every Tuesday and before a demo.

## Package tests

From `pew/Packages/PewPewCore`:

```bash
swift test
```
