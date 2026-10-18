# Progress log

Newest first. Screenshots are captured from the real game at 1280 × 720. The `--autoplay` flag fast-forwards a scripted player, so the later shots show a run in progress.

## 18 Oct 2026 · M0 and M1: project set up, core loop playable

**What's in**

- Godot 4.7.2 project with the Compatibility renderer, strict static typing, and the folder layout from the plan.
- The core loop: the Increment button, eight Software layers that each produce the layer below, buying in ×1, ×10 or Max, and register widths 8 → 16 → 32 → 64 bits with the hard cap and the Widen button. 128-bit waits for Firmware (M3).
- The register display shows the Count in binary, one cell per bit, and turns amber when full.
- Saves: JSON in `user://`, autosave every 30 seconds and on quit or focus loss, a backup file, a version number for future migrations, and offline progress for up to 8 hours with a "While you were away" report.
- 37 automated tests (formulas, number formatting, economy, saves, content) and a GitHub Actions workflow that runs them.
- `tools/sim.gd`, the first balance simulator, plus `--autoplay` and `--capture` flags for screenshots.

**Fresh start.** Eight empty register cells, two layers to buy, the rest revealed as the register grows.

![Fresh start](screenshots/2026-10-18-m1-01-start.png)

**Six minutes in.** A 16-bit register showing 7.80 K in binary; Routines just unlocked.

![Six minutes in](screenshots/2026-10-18-m1-02-six-minutes.png)

**25 minutes in.** A 64-bit register and five layers running.

![25 minutes in](screenshots/2026-10-18-m1-03-25-minutes.png)

**One hour in.** The 64-bit register is full, every cell lit in amber. This is where the first Overflow will go in M3.

![One hour in](screenshots/2026-10-18-m1-04-one-hour.png)

**Balance changes from the plan's starting values.** The plan's first numbers (×2 output every 10 bought, price growth 1.12–1.20) let the simulator fill a 64-bit register in 2 minutes 19 seconds. The current values double output every **20** bought and raise prices by **1.20–1.45** per unit. Simulated pacing now:

| Milestone | Simulated | Plan target |
|---|---|---|
| 16-bit | 0:44 | 1:00 |
| 32-bit | 6:56 | 6:00 |
| 64-bit | 23:15 | 20:00 |
| 64-bit full (first Overflow) | 58:09 | 50:00 (40–60) |

**Next (M2):** upgrades and achievements as data files, Clock upgrades, a stats screen, and a debug panel. Web and Windows export presets are in place; building them needs Godot's export templates, which aren't downloaded yet.
