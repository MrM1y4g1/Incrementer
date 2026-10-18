# Incrementer

An incremental game about a counter inside a forgotten machine. Write software that counts faster, widen the register so the number fits, and overflow to start again stronger.

Built with **Godot 4.7.2** (GDScript, Compatibility renderer) for the Web and Windows.

![A 256-bit run](docs/screenshots/2026-10-18-m5-02-256-bit.png)

## Status

**Version 1.3.1.** The whole V1 game is done, from the first click to the ending at a full 1024-bit register (about six hours): a start screen, eight Software layers, register widths from 8 to 1024 bits, bad bits to repair or scrub, 40 upgrades, 36 achievements, Overclock, the Overflow, Carry, 26 Firmware nodes with autobuyers, settings, save export and import, Start over, and a run log. The machine only runs while the game is open. See [CHANGELOG.md](CHANGELOG.md) and the [progress log](docs/PROGRESS.md).

## Playing it

**Play in your browser:** https://mrm1y4g1.github.io/Incrementer/ (needs WebGL 2). The site updates with every release.

Or download a build from the [releases page](https://github.com/MrM1y4g1/Incrementer/releases):

- **Windows:** unzip `Incrementer-1.3.1-windows.zip` and run `Incrementer.exe`. Windows may show a SmartScreen warning because the game isn't code-signed: choose **More info → Run anyway**. Saves live in `%APPDATA%\Godot\app_userdata\Incrementer`.
- **Web:** `Incrementer-1.3.1-web.zip` is ready for itch.io. To play it locally, serve the unzipped folder with any static web server and open `index.html`; it needs a browser with WebGL 2. Browser saves can be lost with site data, so use **Save data → Copy** to keep a backup.

Click the register or press **Space** to increment. The `windows-debug` build adds a debug panel on **F3**.

**Start over** (Save data, or New game on the start screen) erases the game but first writes it to `save-before-start-over.json` in the save folder; rename that to `save.json`, with the game closed, to get it back.

**Bad bits:** from the second run on, the register's storage starts going bad. A bad bit stops the Count until you **Repair** it (half the bit's value in Count), **Scrub** it (solve a small parity puzzle, free) or wait a minute. They can be switched off in Settings.

**Run log:** the save keeps a list of what you bought and when, by play time. Nothing is sent anywhere. **Save data → Copy run log** copies it as CSV if you want to share it.

## Running it from source

Godot isn't checked in. Put a self-contained copy in `.tools/godot/` as described in [AGENTS.md](AGENTS.md), then:

```sh
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path .                       # play
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import   # first run after cloning
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd -- --no-save
```

Contributors and coding agents: start with [AGENTS.md](AGENTS.md).

## Credits

- Fonts: [Barlow Semi Condensed](https://fonts.google.com/specimen/Barlow+Semi+Condensed), [IBM Plex Mono](https://fonts.google.com/specimen/IBM+Plex+Mono) and [Oxanium](https://fonts.google.com/specimen/Oxanium), all under the SIL Open Font License (licences in `assets/fonts/`).
- Sound and music are synthesised by `tools/make_sounds.gd`.
- Built with [Godot Engine](https://godotengine.org).
