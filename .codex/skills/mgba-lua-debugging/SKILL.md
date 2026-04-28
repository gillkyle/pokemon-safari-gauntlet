# mGBA Lua Debugging

Use this skill whenever work in this repo requires opening, driving, or inspecting the ROM in mGBA.

## Rules

- Prefer mGBA Lua scripts for emulator debugging and verification.
- Do not use `osascript` to drive gameplay unless mGBA Lua or Computer Use cannot perform the step.
- Keep mGBA muted when launching verification runs.
- Run verification at fast-forward speed by default. Use `tools/run_safari_gauntlet_mgba.sh --fast` or `tools/run_safari_gauntlet_mgba.sh --fresh --fast` when a clean save is intended.
- Avoid slow `sleep`-driven workflows. Prefer Lua frame advancement (`emu:runFrame`) and fast-forward mGBA settings so movement, menu, and full-run tests complete quickly.
- Treat screenshots and visible emulator behavior as the source of truth.
- Do not claim a behavior is verified from Lua log strings alone.

## Standard Launch

Use the repo helper for normal/manual runs:

```sh
tools/run_safari_gauntlet_mgba.sh --fresh
```

This copies the current ROM into a hash-specific `/tmp/mgba-safari-gauntlet-*` run directory and launches mGBA muted.

Use fast mode for automated verification:

```sh
tools/run_safari_gauntlet_mgba.sh --fresh --fast
```

This launches muted mGBA with fast-forward enabled. For preserved-save verification, omit `--fresh` but keep `--fast`.

For save-persistence tests, do not use `--fresh` unless the test explicitly needs a clean save.

## Loading Lua

Use mGBA's scripting console:

1. Open `Tools -> Scripting...`.
2. Run:

```lua
dofile('/Users/kyle/dev/pokecrystal/tools/<script>.lua')
```

Do not paste a bare file path into the console; Lua will parse it as invalid syntax.

## Script Requirements

Each Lua debugger script should:

- Write a log to `/tmp/<specific-name>.log`.
- Write at least one screenshot to `/tmp/<specific-name>.png`.
- Emit explicit `FAILED_*` lines for crashes, timeouts, wrong maps, wrong menus, or missing visible state.
- Avoid false-positive `VERIFIED_*` lines unless the script has reached the intended visible state.
- Include enough state in logs to debug failure: map, x/y, direction, crash code, relevant script/menu state, party count, and frame.
- Use concrete paths and scripted button timing instead of manual emulator poking.

## Memory Caveats

mGBA memory APIs can expose stale or bank-dependent WRAM values while the title/menu is still visible. A verifier must not decide it is in the hub from WRAM alone if the visible screen is still title/menu.

When possible, combine:

- concrete input sequence,
- current map and player state,
- crash-code check,
- screenshot inspection,
- and a visible menu/text check.

## Acceptable Fallbacks

Use Computer Use to open mGBA menus or type `dofile(...)` into the scripting console.

Use `osascript` only as a fallback for window focus or one-off local automation when Lua and Computer Use are insufficient. If used, note why it was necessary.
