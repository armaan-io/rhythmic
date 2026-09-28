# Domain Docs

This repository uses a single-context domain documentation layout.

## Before exploring, read these

- Root `CONTEXT.md` for domain terminology.
- ADRs in `docs/adr/` that touch the area you are about to work in.

If these files do not exist, proceed silently. Do not flag their absence or
suggest creating them upfront. `/domain-modeling`, reached via
`/grill-with-docs` and `/improve-codebase-architecture`, creates them lazily
when terms or decisions are resolved.

## File structure

- `CONTEXT.md` — the repository's domain glossary and context.
- `docs/adr/NNNN-short-title.md` — architectural decision records.

## Use the glossary's vocabulary

When naming domain concepts in issues, proposals, hypotheses, or tests, use
the terms defined in `CONTEXT.md`. Avoid synonyms the glossary explicitly
rejects.

If a concept is missing, reconsider whether it belongs to the project's
language or note a genuine gap for `/domain-modeling`.

## Flag ADR conflicts

Surface contradictions with existing ADRs explicitly rather than silently
overriding them. Cite the ADR and explain why the decision may warrant
reopening.
