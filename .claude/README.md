# Claude Code configuration — Blue3

## Model
The model is the user's choice, picked per session with `/model`; a subagent
inherits the session's model. This repository configures none of it
(repodocs ADR-027).

## Effort
`max` + adaptive thinking disabled.

## Critical permissions
- `.env`, Passport OAuth keys, `auth.json` blocked
- `migrate:fresh`, `db:wipe` blocked — protection against data loss
- Direct `mysql`/`mariadb` blocked — Claude should generate migrations, not run SQL
