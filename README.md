# Incrementer

An incremental game about a counter inside a forgotten machine. Write software that counts faster, widen the register so the number fits, and overflow to start again stronger.

Built with **Godot 4.7.2** (GDScript, Compatibility renderer) for the Web and Windows.

![A 256-bit run](docs/screenshots/2026-10-18-m5-02-256-bit.png)

## Status

Milestones M1 to M5 are done: the core loop, progression, the Overflow and Firmware, the balance pass, and the look, sound and feel. The game is playable from the first click to the V1 ending (about six hours): eight Software layers, register widths from 8 to 1024 bits, 40 upgrades, 34 achievements, Overclock, the Overflow, Carry, 23 Firmware nodes with autobuyers, settings, save export and import, and offline progress. Next is M6, release preparation.

## Running it

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
