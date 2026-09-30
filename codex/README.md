# Shared working directory

Created 2026-09-06 during Codex onboarding at the user's request. This is Codex's small project workspace, using ordinary Markdown so Claude Code and either developer can also read and maintain it.

| File | Purpose |
| --- | --- |
| [../README.md](../README.md) | The branch's front page for the developers: status, how to run it, what to test, what's next. Every branch on GitHub has one; update it with each push. |
| [HANDOFF.md](HANDOFF.md) | Current checkpoint, work completed, verification limits, and next milestone. Read first on resume. |
| [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) | Project understanding, durable decisions, source map, existing assets and tools, unresolved design details. |
| [../AGENTS.md](../AGENTS.md) | Shared working instructions for either assistant. |
| [../CLAUDE.md](../CLAUDE.md) | Claude Code entry point importing the shared instructions. |

The [original design spec](../docs/superpowers/specs/2026-09-06-steal-a-chonk-design.md) remains the detailed game design. These notes summarize it and preserve subsequent decisions; they do not replace it.

## Keeping this small and useful

- Keep durable context in `PROJECT_CONTEXT.md` and the latest checkpoint in `HANDOFF.md`.
- Record a decision's source and date, distinguish evidence from assumptions, and name outstanding acceptance or verification explicitly.
- Reference existing code, documents, and assets instead of copying them here.
- Put temporary local work in `codex/scratch/` if needed; that path is ignored. Promote useful conclusions into the Markdown notes.
- Keep production code in the intended `src/` tree when implementation starts, and art under `concepts/` or `assets/`.
- Use repository-relative paths in these files so they work on the partner's machine. Do not store credentials, personal machine paths, or raw session transcripts here.
- At handoff, check the actual checkout and describe uncommitted work accurately. No commit, push, installation, or art generation is implied by updating these notes.

These files are outside the ignored `.claude/` directory so they can be versioned and shared. They were created locally; see `HANDOFF.md` for their commit status.
