<div align="center">

<img src="assets/icon/icon.png" width="112" alt="Blackjack app icon" />

# Blackjack

**A single-player blackjack table for Android that scores every decision you make against basic strategy, and keeps the record.**

[![CI](../../actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)
[![Release](../../actions/workflows/release.yml/badge.svg)](../../actions/workflows/release.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-blue?logo=flutter)](https://flutter.dev)

</div>

---

## What it is

Most blackjack apps are slot machines wearing a card-table costume. This one is
a practice table. You sit down with a bankroll, pick a table whose rules you
want to practise against, and play. Behind every hand, the app is running basic
strategy in parallel with you and recording where the two of you disagreed.

The point is the record, not the chips:

- **A coach that stays out of the way.** Optional. It rings the button basic
  strategy would press, or says nothing and flags the mistake afterwards, or
  does neither.
- **Leak-finding.** Every decision point — `16 v 10`, `A,7 v 9`, `8,8 v A` — is
  tracked separately. The stats screen surfaces the spots you misplay most
  often, not just an overall percentage.
- **Real rules that actually change the maths.** Deck count, dealer on soft 17,
  6:5 versus 3:2, double-after-split, resplit aces, late surrender. The house
  edge shown on the rules screen is computed from what you have selected, and
  the strategy chart the coach uses changes with it.
- **A calendar of every day you have played.** Not a total — a day-by-day
  ledger that goes back as far as you have been playing, including what you did
  on this date in previous years.
- **Save files that hold all of it.** Export to a file, move it to another
  phone, import it. Years of history included.

Nothing is uploaded anywhere. There is no account, no network call, and no
analytics. The only way data leaves the device is a file you export yourself.

## Screens

| Table | Stats | Days | Rules |
| --- | --- | --- | --- |
| The felt. Bet, deal, play, with the coach on or off. | Session and lifetime records, the leak list, the bankroll curve. | Month grid and year heatmap, with per-day, per-month and per-year totals. | Table selection, house rules, the strategy chart, import and export. |

## Install

Grab an APK from the [latest release](../../releases/latest):

- **`blackjack-vX.Y-arm64-v8a.apk`** — any phone from roughly the last decade.
- **`blackjack-vX.Y-universal.apk`** — bigger, works everywhere, take this if
  you are not sure.
- `blackjack-vX.Y.aab` — an app bundle, for uploading to Play. Not installable
  directly.

`SHA256SUMS.txt` on each release has the checksums.

Android will warn you about installing outside the Play Store. That is expected
for a sideloaded APK.

---

## The calendar

The calendar is its own ledger, separate from the lifetime totals, and it is
built to stay cheap as it grows.

Days are stored **one year per key** (`days.2026`), and a year is only parsed
when something asks for it. Opening September 2026 reads one year's worth of
days; it does not touch the nine years behind it. Each day is serialised as a
list of counters rather than a keyed object, with trailing zeros trimmed, which
is roughly a third of the size of the obvious JSON.

What you get out of it:

- **Month view** — a grid tinted jade for days up and clay for days down, with
  the intensity scaled against the biggest swing that month, so the shape reads
  the same whether you bet 5 a hand or 5,000.
- **Year view** — the whole year as a heatmap, plus a month-by-month bar chart
  and the all-time totals.
- **Tap any day** for the full breakdown, and underneath it, the same date in
  every earlier year you have played. Month view does the same thing one level
  up: September 2026 shows September 2025 and September 2024 next to it.
- **Streaks** — how many consecutive days you have played, counted back from
  today.

## Save files

Export writes a `.bjsave`: **gzipped newline-delimited JSON**, one record per
line, one line per year of calendar history.

```text
{"t":"bj","v":2,"app":"blackjack-save","saved":"2026-09-20T22:14:03.221"}
{"t":"core","bankroll":4200,"bet":25}
{"t":"settings","d":{…}}
{"t":"stats","d":{…}}
{"t":"days","y":2025,"d":{"0101":[…],"0102":[…]}}
{"t":"days","y":2026,"d":{…}}
```

The line-per-year shape is the whole trick. Writing, previewing and restoring
all stream: the app never holds more than one year in memory at a time, in
either direction. Ten years of daily play — about 3,650 days — lands somewhere
in the low hundreds of kilobytes, and imports in the same fixed footprint as a
single week would.

Previewing is a separate pass from applying, so the confirmation dialog can
tell you exactly what is in a file before anything is overwritten.

**Importing gives you two choices:**

- **Merge days** — keeps the calendar already on this device and folds the
  file's days in on top. The right answer when you have played on two devices.
  A day recorded on both is summed, except the session count, which takes the
  larger of the two rather than double-counting one evening.
- **Replace everything** — the file wins outright.

Your bankroll, rules and lifetime record are replaced either way; there is no
sensible way to average two of them.

There is also a **short code** — the same save minus the calendar, small enough
to paste into a message, for hopping between two devices in one sitting.

---

## Building it yourself

### What you need

| | |
| --- | --- |
| Flutter | 3.47.0 (stable) |
| Dart | 3.13 — comes with Flutter |
| JDK | 17 (Temurin recommended) |
| Android SDK | via Android Studio, or `sdkmanager` |
| Python | 3.9+, only if you want to regenerate the app icon |

### Get it running

```bash
git clone https://github.com/<you>/blackjack.git
cd blackjack
flutter pub get
flutter run
```

`flutter doctor` will tell you what is missing if the Android toolchain is not
set up yet.

### The checks CI runs

```bash
flutter analyze
flutter test
```

Both must pass before anything is released — the release workflow gates on
them. The suite covers the shoe and the dealer, basic strategy against the
chart, the money arithmetic of a settled round, the calendar's storage and
aggregation, and save-file round trips including a ten-year history.

### Regenerating the app icon

The icon is generated from a script rather than checked in as an opaque binary,
so it stays in step with the palette in `lib/design/tokens.dart`:

```bash
pip install pillow
python tool/make_icons.py
```

That writes `assets/icon/icon.png` and every Android mipmap — the legacy square
icons plus the adaptive foreground/background pair used from API 26 on.

---

## Signing

Release builds are signed with a key held outside the repository. Two files
carry it, and **neither is in version control**:

| File | What it is |
| --- | --- |
| `upload-keystore.jks` | The key itself. PKCS12, RSA 4096, valid until 2054. |
| `key.properties` | The passwords and alias that unlock it. |

Both are in `.gitignore`. Losing them means you can no longer publish an update
that installs over an existing copy of the app — Android will refuse it as a
different app. **Back them up somewhere you trust**, such as a password manager
or an encrypted drive.

Without these files everything still works: `flutter build apk --release`
falls back to the debug key, so a fresh clone builds and runs with no setup.
The resulting APK just cannot install over a properly signed one.

### Moving the key to another machine

Copy both files into the repository root on the new machine:

```text
your-checkout/
├── upload-keystore.jks
├── key.properties
├── pubspec.yaml
└── …
```

`key.properties` looks like this — `storeFile` is relative to the repository
root:

```properties
storePassword=<your store password>
keyPassword=<your key password>
keyAlias=upload
storeFile=upload-keystore.jks
```

Then confirm it took:

```bash
flutter build apk --release
```

To check which key an APK actually carries:

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

The SHA-256 fingerprint should match your keystore:

```bash
keytool -list -v -keystore upload-keystore.jks -alias upload
```

If they differ, the release build fell back to the debug key — usually because
`key.properties` is missing, points at the wrong path, or has the wrong
password.

### Creating a fresh key

Only if you are starting a new app, or the original key is gone for good.

```bash
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -storetype PKCS12 \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias upload \
  -dname "CN=Blackjack, OU=Development, O=your.org, L=City, ST=State, C=XX"
```

Then write `key.properties` with the passwords you chose.

---

## Releasing

### How it works

Every push to `main` publishes a release. There is nothing to run by hand.

1. **`verify`** runs `flutter analyze` and `flutter test`. A failure here stops
   the release; nothing is tagged, nothing is pushed.
2. **`release`** reads the version from `pubspec.yaml` and **bumps the minor
   component until it finds a tag that is genuinely free** — checked against
   both the git tags and the GitHub releases. A release can never overwrite
   another one, even if two pushes land close together, and a tag you created
   by hand is stepped over rather than clobbered.
3. It builds split-ABI APKs, a universal APK and an app bundle, signs them,
   and writes `SHA256SUMS.txt`.
4. The version bump is committed back to `main` as
   `chore: release vX.Y [skip ci]`.
5. The release is published as **`Blackjack vX.Y`** on tag **`vX.Y`**, with
   auto-generated notes from the commits since the last one.

Because the bump is conditional, the first push ships the `1.0.0+1` already in
`pubspec.yaml` as **`Blackjack v1.0`**; the next gives `1.1.0+2` as
`Blackjack v1.1`, then `v1.2`, and so on. `pubspec.yaml` always names the
version that was last released rather than sitting one ahead of it, and the
build number climbs monotonically so Android always sees an upgrade.

**This cannot loop.** GitHub does not re-trigger workflows for pushes made with
`GITHUB_TOKEN`, and a `concurrency: release` group means two runs cannot race
for the same tag.

### Repository secrets

For signed releases, set these under **Settings → Secrets and variables →
Actions → New repository secret**:

| Secret | Value |
| --- | --- |
| `KEYSTORE_BASE64` | `upload-keystore.jks`, base64-encoded |
| `KEYSTORE_PASSWORD` | `storePassword` from `key.properties` |
| `KEY_PASSWORD` | `keyPassword` from `key.properties` |
| `KEY_ALIAS` | `upload` |

To produce the base64 blob:

```bash
# macOS / Linux
base64 -w0 upload-keystore.jks > keystore.b64

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Content keystore.b64 -NoNewline

# Git Bash on Windows
base64 -w0 upload-keystore.jks > keystore.b64
```

Paste the contents of `keystore.b64` as the secret value, then delete the file.

If `KEYSTORE_BASE64` is unset the workflow still runs — it warns, builds with
the debug key, and says so in the release notes. The workflow deletes the
restored key and `key.properties` from the runner whether the build succeeds or
fails.

### Kicking off a release without a code change

**Actions → Release → Run workflow.**

---

## Contributing

Pull requests are welcome. CI runs `flutter analyze`, `flutter test` and a
debug build on every PR.

A few things worth knowing before you start:

- **Design tokens live in one place.** `lib/design/tokens.dart` holds every
  colour, type style and spacing step. Nothing should hard-code a colour.
- **Rules drive strategy, not the other way round.** If you add a rule
  variation to `lib/model/rules.dart`, `lib/engine/basic_strategy.dart` has to
  answer to it, and the house-edge estimate on the rules screen should move.
- **Stats are recorded in exactly one place.** `StatsStore` fans a round out to
  the session total, the lifetime total and the calendar. Do not record
  directly from the game controller.
- **Day storage is append-only.** `DayStats.toList()` has a fixed field order;
  new counters go on the end. A shorter list is an older save and reads as
  zeros, a longer one came from a newer build and the tail is ignored. Never
  reorder it.
- **Tests before features.** `test/` has no mocking framework and no golden
  files — it plays thousands of real rounds and asserts the money balances.
  New behaviour should be testable the same way.

### Layout

```text
lib/
├── design/        tokens, theme, number formatting
├── engine/        basic strategy
├── model/         cards, hands, shoe, rules, tables, stats, day stats
├── state/         controllers and stores, save file format and transfer
└── ui/
    ├── calendar/  month grid, year heatmap, day sheet
    ├── common/    shared controls
    ├── settings/  rules, tables, strategy chart, import and export
    ├── stats/     session and lifetime records
    └── table/     the felt
tool/              icon generation
test/              engine, game, progression, calendar, save files, widgets
```

## Licence

Not yet chosen. Until one is added, all rights are reserved — ask before
redistributing.
