# Incrementer

An incremental game about a counter inside a forgotten machine. Write software that counts faster, widen the register so the number fits, and overflow to start again stronger.

Built with **Godot 4.7.2** (GDScript, Compatibility renderer) for the Web and Windows.

![The game after six minutes of play](docs/screenshots/2026-10-18-m1-02-six-minutes.png)

## Status

Milestone **M1 (core loop)** is in: clicking, eight Software layers that produce each other, buying in ×1, ×10 or Max, register widths from 8 to 64 bits, saves with offline progress, and a balance simulator. See [docs/PROGRESS.md](docs/PROGRESS.md) for screenshots and notes from each step.

## Running it

Godot isn't checked in. Put a self-contained copy in `.tools/godot/` as described in [AGENTS.md](AGENTS.md), then:

```sh
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path .                       # play
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import   # first run after cloning
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd -- --no-save
```

Contributors and coding agents: start with [AGENTS.md](AGENTS.md).
