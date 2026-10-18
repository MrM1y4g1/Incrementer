# AGENTS.md

Guidance for coding agents (and people) working on **Incrementer**, an incremental game built in Godot.
Read this before changing anything.

## The game in one paragraph

You are a counter inside a machine. Eight layers of Software produce each other (Hypervisor → Kernel → … → Loop → Incrementer → Count). The Count lives in a register that caps it at 2^bits − 1; widening the register (8 → 16 → … → 1024 bits) costs 75% of a full register. Once a 64-bit register is full the player can Overflow (prestige, milestone M3) and spend Carry on permanent Firmware. V1 ends when a 1024-bit register is full, which is exactly the largest 64-bit float, so plain `float` covers the whole game.

The full project plan (concept, pacing targets, architecture, roadmap M0–M6, art direction) is a private claude.ai artifact owned by the repo owner: https://claude.ai/artifact/32PD2UFSmYYU396bF2eytm

## Tools and versions

- **Godot 4.7.2 stable**, GDScript only. C# can't export to the Web, and the Web build is a first-class target.
- **Renderer:** Compatibility (`gl_compatibility`), because it's the renderer the Web export runs on.
- Godot is not installed system-wide. A self-contained copy lives in `.tools/godot/` (git-ignored). The `._sc_` file next to the executable keeps editor settings, caches and `user://` data inside `.tools/godot/editor_data/`. **Don't write outside the repository folder.**

To set it up on a new machine (Git Bash):

```sh
mkdir -p .tools/godot && cd .tools/godot
curl -sSfLO https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip
curl -sSfLO https://github.com/godotengine/godot/releases/download/4.7.2-stable/SHA512-SUMS.txt
grep 'Godot_v4.7.2-stable_win64.exe.zip' SHA512-SUMS.txt | sha512sum -c -
unzip -q Godot_v4.7.2-stable_win64.exe.zip && touch ._sc_
```

## Commands

Run from the repository root. `G=.tools/godot/Godot_v4.7.2-stable_win64_console.exe`

| What | Command |
|---|---|
| Import (after a fresh clone or new `class_name`) | `$G --headless --path . --import` |
| Run all tests | `$G --headless --path . --script res://tests/run_tests.gd -- --no-save` |
| Pacing check (first Overflow) | `$G --headless --path . --script res://tools/sim.gd -- --no-save --minutes=90` |
| Pacing check (whole game) | `$G --headless --path . --script res://tools/sim.gd -- --no-save --until=ending --minutes=720` |
| Windows build | `$G --headless --path . --export-release "Windows Desktop" builds/<version>/windows/Incrementer.exe` (one folder per version, so a build someone is playing is never overwritten; templates go in `.tools/godot/editor_data/export_templates/4.7.2.stable/`) |
| Windows debug build (F3 debug panel) | `$G --headless --path . --export-debug "Windows Desktop" builds/<version>/windows-debug/Incrementer.exe` |
| Web build | `$G --headless --path . --export-release "Web" builds/<version>/web/index.html` |
| Play the game | `$G --path .` |
| Screenshot | `$G --path . --resolution 1280x720 -- --no-save --autoplay=<seconds> --capture=docs/screenshots/<name>.png` |
| Open the editor | `.tools/godot/Godot_v4.7.2-stable_win64.exe --path . --editor` |

Dev flags go after `--`: `--no-save` (never read or write the save or settings), `--mute` (no sound; captures and headless runs are silent anyway), `--autoplay=<seconds>` (fast-forward the scripted player before the first frame), `--open=<views>` (comma-separated: `upgrades`, `stats`, `firmware`, `settings`, `save`, `overflow`, `overflow-fx`, `ending`, `debug`, `toast`), `--capture=<png>` (save a screenshot after a few frames, then quit). Captures need a real window, so they don't work with `--headless`. In debug builds, **F3** toggles the debug panel.

## Layout

```
autoload/          EventBus (signals), Settings (preferences in user://settings.cfg), ContentDB (loads and checks data),
                   Game (state + 20 Hz tick), SaveManager (JSON saves), Audio (sound effects and music)
core/              Pure logic: Formulas, Economy, GameState, Content, Achievements, SaveCodec, NumberFormat, AutoPlayer
data/defs/         Resource classes: LayerDef, UpgradeDef, AchievementDef, FirmwareDef
data/layers/       One .tres per Software layer: most balance numbers live here
data/upgrades/     One .tres per upgrade
data/achievements/ One .tres per achievement
data/firmware/     One .tres per Firmware node (column = position in the tree)
ui/                main.tscn + main.gd (screen built in code), SchematicView, RegisterDisplay, LayerRow, UpgradeCard,
                   TierIcon, FramePanel, FxLayer, Stats/Firmware/Settings/Ending/Save/Debug panels,
                   Palette, Fonts, Shapes, ThemeFactory
tests/             run_tests.gd (runner), lib/ (TestCase, Fixtures), test_*.gd
tools/             sim.gd (balance simulator), make_sounds.gd (synthesises assets/audio)
assets/            fonts/ (OFL fonts and licences), audio/ (generated WAVs)
docs/              PROGRESS.md (progress log), itch-page.md (store page text), screenshots/
builds/            Exports, one folder per version (git-ignored)
```

`docs/` and `builds/` each hold a `.gdignore`, so Godot never imports the screenshots or exported files and they can't end up in a build.

## Rules that keep the architecture honest

1. **`Economy` is the only code that changes the numbers.** Live play, offline catch-up, the autoplayer, the simulator and the tests all call the same functions. Never add Count or units anywhere else.
2. **`core/` never touches autoloads, nodes or files** (except `ContentLoader`, which only reads `res://`). That keeps it testable headless.
3. **Content is data.** New layers, upgrades or Firmware nodes are `.tres` files with a Resource class in `data/defs/`. Balance changes are data changes; afterwards run `tools/sim.gd -- --no-save --until=ending --check`. It fails if the first Overflow leaves 40–60 min, the longest first-hour wait passes 90 s, or the ending leaves 5–8 h. CI runs the same check.
4. **Saves are versioned.** Any change to `GameState.to_dict()` bumps `SaveCodec.VERSION` and adds a migration step plus a test that loads the old format.
5. **The UI only asks and listens.** It calls `Game.click()`, `Game.buy()`, `Game.widen()`, reads `Game.state`, and listens to `EventBus`. It refreshes at 10 Hz, not every frame.
6. **Floats stay finite.** Everything is capped by the register; the 1024-bit cap is `Formulas.MAX_FLOAT`. Test anything near 1e308.
7. **Global boosts multiply the Count per second only.** Layers produce each other in a chain, so a multiplier on every layer compounds: ×2 on six active layers is roughly ×64. The clock, achievements and `ALL_MULTIPLIER` upgrades therefore apply to layer 1 only; `LAYER_MULTIPLIER` upgrades apply to their own layer.
8. **Run state versus save state.** Fields in the "This run" block of `GameState` reset on an Overflow; everything else lasts the whole save. Firmware and Carry are permanent.
9. **Multipliers stay finite.** `Formulas.MAX_MULTIPLIER` caps every multiplier and layer amounts stop at `MAX_FLOAT`, because INF × 0 is NaN and NaN would corrupt a save.
10. **Content is validated at startup.** `Content.validate()` lists problems (duplicate ids, missing layers, bad costs); `ContentDB` stops debug builds on any. `tests/test_content.gd` runs the same check.

## Code style

- Static typing everywhere. `debug/gdscript/warnings/untyped_declaration` is set to **Error**, so untyped variables, parameters, returns and loop variables fail to compile. Use `:=` or explicit types, and `for i: int in …`.
- Tabs for indentation, `snake_case` for files, functions and variables, `PascalCase` for `class_name`.
- `##` doc comments on classes and on public functions whose purpose isn't obvious from the name. Explain *why*, not what.
- Keep warnings at zero. Use `@warning_ignore` only with a reason.

## Tests

- Every change to `core/` comes with tests in `tests/test_*.gd`. A test file extends `TestCase`; methods named `test_*` run automatically. Use `check`, `check_eq` and `check_near`.
- Tests build their own content with `Fixtures` (`tests/lib/fixtures.gd`) so balance changes in `data/` don't break them; `tests/test_content.gd` checks the real data for structural mistakes.
- CI (`.github/workflows/tests.yml`) imports the project and runs the suite on every push and pull request. Keep it green.

## Screenshots and the progress log

The repo owner follows progress through screenshots. After any visible change:

1. Capture fresh screenshots with `--autoplay` at a few points in a run (start, about 6 minutes, 25 minutes, one hour).
2. Save them as `docs/screenshots/YYYY-MM-DD-<milestone>-<nn>-<moment>.png`.
3. Add an entry at the top of `docs/PROGRESS.md` with the images and a short note on what changed and what's next.

## Art direction

Clean-lined sci-fi: thin glowing lines on a deep blue-black background, panels with corner brackets (`FramePanel`). Colours have fixed meanings (see `ui/palette.gd`): cyan = producing now, violet = survives an Overflow, amber = needs attention, magenta = the Overflow only. Software tiers are polygons where tier *n* has *n* + 2 sides (`Shapes.polygon`). Fonts come from `Fonts`: `body()` for labels, `heading()` for spaced capitals, `mono()` for numbers, `readout()` for big numbers. Everything is drawn in code; there are no sprites. Every effect must respect `Settings.reduced_motion`. Content is locked as of M5: only balance numbers change.

## Releases

1. Bump `config/version` in `project.godot` and add the version to the top of `CHANGELOG.md`.
2. Run the tests and the whole-game pacing check with `--check`.
3. Export Web, Windows and Windows debug into `builds/<version>/` (commands above). If an export can't replace a file, someone is playing that build: export to a new folder instead of closing it.
4. Zip each folder's contents as `builds/<version>/Incrementer-<version>-web.zip`, `-windows.zip` and `-windows-debug.zip`. The Web zip has `index.html` at its root, which is what itch.io expects.
5. Tag `v<version>`, push the tag, and create the GitHub release as a **draft** with the three zips and the changelog section. The repo owner publishes it and the itch.io page (`docs/itch-page.md`).

## Git

- Small commits with messages in the imperative ("Add offline catch-up"). Run the tests before every commit.
- `main` is the working branch for now. Don't commit `.tools/`, `.godot/` or `builds/`.
