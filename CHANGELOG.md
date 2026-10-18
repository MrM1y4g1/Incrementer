# Changelog

## 1.0.1 · 18 October 2026

Balance and clarity fixes from the first playtest of 1.0.0.

- **The Carry ripple.** The Carry bonus now starts at ×1 when a run begins and reaches full strength over the first 10 minutes. In 1.0.0 the whole bonus applied at once: after the first Overflow, one Incrementer made hundreds of millions per second and the old register widths went by in seconds. Now the second run gets back to 64 bits in about 4½ minutes, and the new width still gets the full bonus.
- The ripple carries on while you're away, so offline progress right after an Overflow still gets the bonus. The run time in the status bar and the run history now includes time away; play time doesn't.
- The Carry bonus is shown next to the clock, with how long until it's complete. The Overflow confirmation and pop-up say what the next run's bonus will be.
- Pacing: the simulated ending moves from 5 h 52 min to 6 h 23 min. The last run now takes about 9 minutes instead of ending the moment it starts.

## 1.0.0 · 18 October 2026

The first release: the whole V1 game, from the first click to a full 1024-bit register.

**The game**
- An Increment button, and eight Software layers that write each other: Hypervisor → Kernel → Service → Process → Thread → Routine → Loop → Incrementer → Count.
- A register from 8 to 1024 bits that caps the Count. Widening it costs 75% of a full register.
- 40 upgrades, 34 achievements (+1% Count per second each) and Overclock.
- The Overflow: reset the run for Carry (2 for a full 64-bit register, doubling every 16 bits). Carry earned boosts Count per second, so every run starts faster.
- 23 Firmware nodes bought with Carry: Wide bus I–IV (128 to 1024-bit registers), Boot ROMs, multipliers, faster milestones, a 24-hour offline cap, and autobuyers you can switch on and off.
- The V1 ending at a full 1024-bit register (1.80e308, the largest 64-bit float), with your run history. The save stays playable.
- About six hours to the ending for a steady player.

**Look and sound**
- Clean-lined sci-fi interface: a schematic of the machine, a register display that fills up, framed panels, and an Overflow flash and shockwave.
- Synthesised sound effects and an ambient music loop.

**Saves and settings**
- Autosave (every 15 seconds to 2 minutes), plus saves on quit and when the window loses focus, with a backup file.
- Up to 8 hours of offline progress (24 with Firmware) and a "While you were away" report.
- Save export and import as text. Browser players get a warning when the browser won't keep their save.
- Settings for number format (standard, scientific, engineering or bits), music and effect volumes, reduced motion and autosave interval.
