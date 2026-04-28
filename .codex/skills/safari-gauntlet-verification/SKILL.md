# Safari Gauntlet Verification

Use this skill whenever changing Safari Gauntlet maps, scripts, inventory, trainer flow, PC/box behavior, mGBA launch behavior, or save/persistence behavior.

## Core Rule

Every behavior change needs a concrete verifier. Do not rely on "it built" or a broad smoke test when a specific interaction was changed.

## Required Workflow

1. Inspect the current source and the affected map/script/data tables.
2. Make the smallest source change that addresses the behavior.
3. Add or update a focused verifier under `tools/safari_gauntlet_verify_<behavior>.lua`.
4. Build the ROM:

```sh
make -j8
```

5. Sync or launch the exact rebuilt ROM path used by the user.
6. Run the focused Lua verifier in muted mGBA fast-forward mode.
7. Open the verifier screenshot and inspect it before reporting success.

Use fast launch for automated checks:

```sh
tools/run_safari_gauntlet_mgba.sh --fresh --fast
```

For preserved-save checks, omit `--fresh` but keep `--fast`. Do not wait through gameplay at normal speed unless the behavior specifically depends on real-time pacing.

## Verifier Standards

A verifier should prove one behavior at a time. Examples:

- boot reaches Battle Factory 1F without auto-starting a run,
- walking around the hub does not crash,
- nurse is visually placed and reachable,
- native PC opens with the expected party/box state,
- settings NPC opens and persists settings,
- receptionist starts the expected run phase,
- TM merchant opens a readable menu and does not freeze,
- move tutor reaches the Pokemon/move-selection flow and does not freeze,
- Safari draft encounters use the expected level/rate rules,
- victory keep selection is readable and stores the chosen Pokemon,
- save/reload preserves stats, BP, box state, and settings.

Each verifier must:

- use a fresh temp log and screenshot path,
- advance frames directly through Lua and complete at fast-forward speed,
- fail fast on crash code,
- fail on timeout,
- fail when it reaches the wrong map or wrong UI,
- avoid stale screenshots,
- name the exact behavior in its `VERIFIED_*` line.

## Regression Discipline

When moving an NPC or adding an object:

- verify all nearby interactions, not just the new one,
- check reachability from the player start position,
- check that existing NPCs did not move onto counters or behind blockers,
- check object coordinates against the visible map,
- and avoid placing objects on top of BG events unless the interaction is intentionally a counter/table interaction.

When editing menu scripts:

- prefer native menu systems where practical,
- keep text boxes short enough for GBC windows,
- verify Cancel is visible,
- verify A and B both exit safely,
- verify the screen redraws correctly after closing the menu.

When editing persistence:

- test with a preserved save and a clean save separately,
- never delete or overwrite the user's save unless explicitly asked,
- verify stats/settings/box values after reload, not just before saving.

## Reporting Standard

Final reports should state:

- source files changed,
- exact build command,
- exact ROM hash/path tested,
- verifier scripts run,
- screenshot evidence inspected,
- and any unverified risk that remains.

If a verifier fails, report the failure directly and keep debugging before claiming the fix is complete.
