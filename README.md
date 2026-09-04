# ChaiCheck

A small iOS tea timer. Infusions, not alarms.

One screen. No accounts, no network, no packages.

## What it does that a generic timer doesn't

- **Infusion ladder.** Oolong, pu-erh, and the rest remember which steep you are on and add time automatically.
- **Rinse, then steep.** Pu-erh starts with a 10s rinse you dump, then the real first infusion.
- **Chai is a simmer.** Ten minutes, a mid-pot haptic to check the milk, and "another pot" instead of a fake second steep.
- **Water temp as a reminder.** Green is 75°C on purpose. The app does not pretend to be a kettle.
- **Pocket ping.** Wall-clock timing, a local notification, and a done haptic so you can walk away. The screen stays awake while it runs if you leave it on the counter.

Teas: Chai, Black, Green, Oolong, White, Pu-erh, Herbal. Nudge −15s / +30s on any of them.

## Run it on your iPhone (no $99 program)

Apple lets a free Apple ID install apps you build, on devices you own, for 7 days at a time. Then you open Xcode and Run again.

1. Plug in the phone, unlock it, tap **Trust**.
2. On the phone: **Settings → Privacy & Security → Developer Mode** → on, then restart if it asks.
3. Open `ChaiCheck.xcodeproj` in Xcode.
4. Xcode → Settings → Accounts → add your Apple ID. Pick the **Personal Team**.
5. In the project editor, signing for the ChaiCheck target: **Automatically manage signing**, team = your Personal Team.
6. Choose your iPhone as the run destination, press Run.
7. First launch: iPhone may say the developer is untrusted. **Settings → General → VPN & Device Management** → trust your Apple ID.

That is the whole paid-developer workaround. No App Store, no TestFlight.

## Tooling notes

This repo is an iPhone-only SwiftUI app, iOS 17+, bundle id `com.zigarezar.ChaiCheck`.

Xcode 15.4 can compile it. Putting it on a phone running iOS 26 needs a newer Xcode than 15.4, and that Xcode needs a newer macOS than Sonoma. Until then, use Xcode's Run button after signing in — if Xcode refuses the device, that is the version gap, not the app.
