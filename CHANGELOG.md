# Changelog

## 1.3.2 · 18 October 2026

- Fixed a memory leak in the browser. The machine schematic redrew all its shapes 60 times a second, and the browser kept memory for each one, so the tab grew by about 2 MB a second until it froze. The shapes now redraw only when they change, and the browser's memory stays level.

## 1.3.1 · 18 October 2026

- The screen stays at 1280 × 720. It's drawn at its real size in the middle of the window and never enlarged; it only shrinks when the window is too small to hold it. 1.2.1 scaled it to fit, which zoomed it in on large screens.
- The Widen and Overclock buttons say "TO" instead of an arrow the game's font couldn't draw. On Windows the arrow came from a different font, and in the browser it showed as an empty box.
- The Overflow flash covers the whole window, not just the game.

## 1.3.0 · 18 October 2026

- **New music.** A dark, slow synth piece in F minor at 88 BPM, about two minutes long. It opens with a filtered pad over deep bass, builds with a bass line, an echoing arpeggio and half-time drums, brings in a soft lead, breaks down and returns, then loops. Like the rest of the game's audio, it's synthesised in code.
- The music now loops over the whole track. Before, the loop was set from the size of the compressed audio and cut off after a few seconds.

## 1.2.2 · 18 October 2026

- Sound works in the browser. The browser version was silent: the Music and Sound effects channels were created while the game started, which works on Windows, but browsers only play through channels that exist from the start. They're now set up before the game starts.

## 1.2.1 · 18 October 2026

- The screen keeps the layout of the screenshots. It scales evenly to fit the window or browser and fills any spare space with the background colour, instead of stretching the panels to fill a wider or taller window.

## 1.2.0 · 18 October 2026

**New: bad bits.** From the second run on, the machine's storage starts going bad.
- Each time you widen the register, bad bits can appear among the new bits. There are more as the machine ages, Overflow by Overflow, up to three per widening. Each run places them differently.
- The Count can't pass a bad bit. Clear it in one of three ways:
  - **Repair:** costs half the bit's value in Count.
  - **Scrub:** solve a small parity puzzle. One bit in a word has flipped, and the odd row and odd column show where. It's free.
  - **Wait:** the bit scrubs itself after a minute of holding the Count.
- Three new Firmware nodes: ECC memory (bad bits scrub themselves in 20 seconds), Spare rows (half as many bad bits) and Self-healing memory (3 seconds).
- Two new achievements: Parity check (scrub a bad bit) and Fault tolerant (clear 25 bad bits).
- Bad bits are red, a new colour that means damage. The one holding the Count pulses and fills with cyan as it scrubs. Repair and Scrub appear under the register, a sound plays when a bad bit blocks the Count, and the first one explains itself. Bad bits can be switched off in Settings.
- The run log records when each bad bit blocked the Count and how it was cleared.
- In the simulator, a whole game meets about 33 bad bits. The ending stays at about 6 h 14 min whichever way you clear them, because the layers above keep producing while the Count waits.

**Fixed**
- Firmware nodes and upgrades with the same price now always appear in the same order.
- Pop-ups wrap long text instead of running off the screen.
- Saves move to format 5. Like 1.1.0's format 4, older builds can't read it, so don't go back to an older build after playing this one.

## 1.1.0 · 18 October 2026

**New**
- **A start screen**, with the game's name over a ticking 16-bit counter. Continue shows your register width, Overflows and play time; a new save shows Start. New game, Settings and Quit (not in the browser) sit below.
- **Start over**, in Save data and as New game on the start screen. The amber confirmation offers Copy save first. The old game is also written to `save-before-start-over.json` in the save folder.
- **A run log.** The save keeps a list of what you did and when, by play time: sessions, the first unit of each layer per run, upgrades, widening, Overflows, Firmware, achievements, autobuyer switches and the ending. Nothing is sent anywhere. **Save data → Copy run log** copies it as CSV if you want to share it.

**Changed**
- **The machine only runs while the game is open.** There's no offline progress and no "While you were away" report. A minimised window or a background browser tab still counts as open.
- The Watchdog timer Firmware node, which used to extend offline progress, now gives Count per second ×2 at the same price. The simulated ending moves from 6 h 19 min to 6 h 14 min.

**Fixed**
- After the ending, the lifetime "Total counted" stat could pass the largest number the game can hold and be saved as infinity. It now stops at 1.80e308, and saves that already hold infinity load as 1.80e308.
- The game no longer saves over a save from a newer version that it can't read. It keeps saving off and says so in the status bar. Saves move to format 4, which 1.0.x can't read, so don't open a 1.0.x build after playing 1.1.0: it would start a new game and save over yours.

## 1.0.3 · 18 October 2026

Balance from the second playtest: the game could be finished in under 2 hours.

- **A smaller Carry bonus that ripples in over 40 minutes.** The bonus is now Count per second × (1 + Carry earned)^7, down from ^12.5, and it ripples in over 40 minutes instead of 10. In 1.0.2, a player who Overflowed whenever a run slowed down reached each run at twice the bits of the run before, in about 10 minutes, and finished in under 2 hours. Now each run gets about a third further than the last and lasts about 40 minutes. The fastest strategies tried reach the ending in 6 to 7 hours.
- The Overflow button shows the next run's Carry bonus, to compare with this run's in the Count panel. The Overflow confirmation suggests Overflowing when a run slows down: waiting for a full register at the widest width is now far slower.
- Existing saves keep their Carry and Firmware, but the Carry bonus they give is smaller.

## 1.0.2 · 18 October 2026

- The Count panel keeps its width. Once numbers reached e-notation, the line under Count per second grew too long and the panel kept changing width, pushing the register panel left and right. The Carry details now have their own line, in violet, and any text too long for the panel ends in "…" instead of widening it.
- Long lines in the parts list end in "…" instead of being cut off mid-character.

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
