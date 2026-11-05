# CLAUDE.md

Claude Code guidance for this repository. The canonical agent instructions live in AGENTS.md.

@AGENTS.md

## Plugin Setup

Run once after cloning (also listed in `.claude/settings.json`):

```bash
claude plugin install elixir@claude-code-elixir
claude plugin install superpowers@claude-plugins-official
claude plugin install code-review@claude-plugins-official
claude plugin install elixir-scaffold
```

## Claude-specific notes

- Postgres runs via `docker compose up -d`. If 5432 is taken, prefix commands with `SHARDEX_DEMO_PGPORT=<port>`.
- Run `mix precommit` before every commit.
- Use the `superpowers` skills for non-trivial work (brainstorming before new features, test-driven-development,
  verification-before-completion).
- Use `/code-review` for review; it should not modify code.
- This repo demonstrates the `shardex` library (`~/Projects/shardex`); keep the demo's custom wiring (strategy,
  assignment, plug, on_mount) readable — it is the teaching surface.
- Keep AGENTS.md as the single source of truth; do not copy its content here.
