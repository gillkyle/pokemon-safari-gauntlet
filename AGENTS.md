# Agent Notes for This Repo

Before changing or verifying Safari Gauntlet emulator behavior, use the repo-local skills:

- `.codex/skills/mgba-lua-debugging/SKILL.md`
- `.codex/skills/safari-gauntlet-verification/SKILL.md`

Project-specific rule: use mGBA Lua verification scripts for emulator debugging whenever possible, and add focused regression verifiers for each behavior changed.

Speed verification rule: run Safari Gauntlet emulator verifiers in muted fast-forward mode (`tools/run_safari_gauntlet_mgba.sh --fast`, with `--fresh` only when a clean save is intended) so full-run and movement checks complete quickly without slow sleeps or manual waiting.
