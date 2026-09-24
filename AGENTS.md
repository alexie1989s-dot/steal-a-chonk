# Steal a Chonk: shared project instructions

These instructions are shared by Codex and Claude Code. Follow the current user request and preserve existing work.

## Start here

1. Read [codex/HANDOFF.md](codex/HANDOFF.md) for the last verified state and next milestone.
2. Read [codex/PROJECT_CONTEXT.md](codex/PROJECT_CONTEXT.md) for decisions, source provenance, and the asset/tool map.
3. Read the relevant sections of the [design spec](docs/superpowers/specs/2026-09-06-steal-a-chonk-design.md) before changing a system. Read the full spec when first onboarding.
4. Check `git status --short --branch`, `git log -3 --oneline`, and relevant diffs before editing. The checkout may have changed since the handoff.

## Decisions to preserve

- This is **Steal a Chonk**, an original, mobile-first Roblox game about ultra-round animals, field acquisition, Zoomies, a safe Vault, and an opt-in raidable Showcase. Humor is affectionate.
- The recorded hero-art direction is **Meshy image-to-3D from the partner's concepts**. Primitive hero models were rejected, and the user stopped the Blender markings/fur finishing approach. Do not resume that approach unless the user asks.
- **Current scoped exception, 2026-09-07:** the user explicitly requested another corgi redesign using Blender and its MCP server. That attempt is saved under `assets/chonks/corgi/codex_redesign/`; it awaits visual review and Studio validation. This request authorizes the Blender retry without establishing a permanent pipeline change or art acceptance.
- The existing corgi model is a rejected prototype. A file in Git is not evidence of partner acceptance. Preserve the original concepts and prototype outputs.
- The saved art milestone is one partner-accepted corgi, then a second Chonk to prove repeatability. On 2026-09-24 the user started the spec §23 vertical-slice prototype ahead of art acceptance, so the two tracks now run in parallel. The current request determines which work to carry out.
- Use the developers' confirmed play experience for reference-game mechanics. Do not replace it with assumptions or fan-wiki claims. Distinguish proposed mechanics from observed mechanics.
- The spec still says draft; later Claude notes call the design settled. Preserve this discrepancy and the open issues in `codex/PROJECT_CONTEXT.md` rather than silently deciding them.

## Implementation and evidence

- The game stack is Rojo/Rokit/Luau with server-authoritative state. A greybox vertical-slice prototype exists in `src/`, with Lune unit tests in `tests/`. See `codex/HANDOFF.md` for how to run it and what has been verified. Pure rules live in `src/shared` behind string requires, so `lune run tests/run` can test them headlessly. Studio behaviour is checked through the Studio MCP and the Studio-only `ServerStorage.DevHooks`.
- Scripts change only as repository files; Rojo overwrites edits made to synced scripts inside Studio. Rojo does not live-apply property changes in `default.project.json` to an open place, so rebuild the place or patch the open copy to match.
- Keep changes scoped. Label proposed work, generated artifacts, accepted art, and verified behavior accurately.
- Read legacy scripts before running them: they can replace Blender objects and overwrite outputs. Their defaults are not a recipe for reproducing the saved corgi.
- Check current service/tool availability and costs when needed. Historical Meshy research is not a current setup check or price guarantee.

## Repository hygiene

- Never add a `Co-Authored-By` commit trailer. Preserve the repository's noreply author identity.
- Before every commit and every push, scan tracked text and files being added for secrets, tokens, environment/key files, and machine paths containing personal usernames; report the result. Do not print secret values.
- Keep credentials out of the repository. Preserve `.gitignore` exclusions for `.claude/`, intermediate work, FBX exports, and secrets. FBX files were excluded because they embed machine paths.

## Handoff maintenance

Use the plain Markdown files in [codex/](codex/README.md) for durable, shared working notes. Update `HANDOFF.md` after meaningful work with the date, changes, actual verification, unresolved items, and next step. Update `PROJECT_CONTEXT.md` when a decision changes. Keep one shared account of the project; avoid parallel Codex and Claude versions. Local `.claude/` notes may add history when present, but a fresh clone must not require them.
