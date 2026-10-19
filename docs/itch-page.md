# itch.io page

Everything needed to publish Incrementer 1.3.3 on itch.io. Copy the text, upload the files, set the options.

## Upload

| File (from `builds/1.3.3/`) | itch.io setting |
|---|---|
| `Incrementer-1.3.3-web.zip` | Kind: HTML. Tick **"This file will be played in the browser"**. |
| `Incrementer-1.3.3-windows.zip` | Platform: Windows. |

**Embed options:** viewport **1280 × 720**, tick **Fullscreen button**, leave **SharedArrayBuffer support** off (the Web build is single-threaded and doesn't need it). Mobile friendly: no.

**Classification:** Game · Released · Genre: Simulation · Tags: `incremental`, `idle`, `clicker`, `sci-fi`, `minimalist`, `singleplayer`.

**Pricing:** decide before publishing: free, or "No payments" or "Donate" for pay-what-you-want.

## Title and short description

**Incrementer**

> Count. Widen the register. Overflow. An incremental game about a counter inside a forgotten machine.

## Description

You are a counter inside a forgotten machine. Every tick adds one.

Write software that counts for you: Incrementers add to the Count, Loops write Incrementers, Routines write Loops, all the way up to Hypervisors. Widen the register so the number fits: 8 bits, then 16, 32, 64, up to 1024. When a 64-bit register is full, **Overflow**: start again with Carry, and spend it on Firmware that stays forever.

Fill a 1024-bit register, 1.80 × 10^308 (the largest number a 64-bit float can hold), and the machine is complete.

**What's in it**
- Eight layers of software that produce each other, drawn as a living schematic
- A register from 8 to 1024 bits, shown bit by bit
- A click charge: click fast and every click is worth more. Just don't fly too close to the sun
- Worn bits: the machine's storage wears out as you play. When a bit goes bad, repair it, scrub it with a parity puzzle, or wait
- A short tutorial that pauses the game to explain the first steps
- 40 upgrades, 37 achievements and Overclock
- The Overflow, Carry and 26 Firmware nodes, including autobuyers
- About six hours to the ending. The machine runs while the game is open
- Synthesised sound and music, reduced-motion and number-format settings

**Controls:** mouse. Press **Increment** or **Space** to increment.

**Saves:** the game saves automatically. Save data can copy your save as text, start over, or copy a run log of what you bought and when; nothing is ever sent anywhere.
- In the browser, saves live in your browser's storage. Private windows, or clearing site data, can lose them, so use **Save data → Copy** now and then to keep a backup.
- On Windows, saves live in `%APPDATA%\Godot\app_userdata\Incrementer`.
- Windows may show a SmartScreen warning because the game isn't code-signed: choose **More info → Run anyway**.

**Credits:** fonts are Barlow Semi Condensed, IBM Plex Mono and Oxanium (SIL Open Font License). Sound and music are synthesised by the game's own tools. Made with Godot Engine.

## Screenshots

Upload these from `docs/screenshots/`, in this order:

1. `2026-10-18-m5-02-256-bit.png`: a 256-bit run (use as the cover too)
2. `2026-10-18-m5-01-six-minutes.png`: early game
3. `2026-10-18-m5-03-overflow-effect.png`: the Overflow
4. `2026-10-18-m6-01-firmware.png`: Firmware
5. `2026-10-18-m6-03-ending.png`: the ending
6. `2026-10-19-v140-04-worn-bits.png`: bits wearing out
7. `2026-10-19-v140-07-scrub-256-bit.png`: scrubbing a bad bit
8. `2026-10-19-v150-01-click-charge.png`: the click charge
9. `2026-10-19-v140-01-tutorial-count.png`: the tutorial
10. `2026-10-18-v110-01-start-screen.png`: the start screen

## Launch checklist

- [ ] Publish the page (it can start as Draft or Restricted to test the embed).
- [ ] Play the browser version once on the page: start, save, refresh, check the save is still there.
- [ ] Post a devlog ("Incrementer 1.0") with the changelog from `CHANGELOG.md`.
- [ ] Share in r/incremental_games' weekly Feedback Friday thread for playtest round 2.
- [ ] Collect feedback for 1.0.x in GitHub issues.
