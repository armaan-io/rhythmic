## Agent skills

### Issue tracker

Issues and PRDs live in GitHub Issues for `armaan-io/rhythmic`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five default canonical triage labels. See `docs/agents/triage-labels.md`.

### Domain docs

Use a single-context layout: root `CONTEXT.md` and `docs/adr/`. See `docs/agents/domain.md`.

## Active product interview

Before continuing product planning or implementation, read
`docs/planning/rhythm-trainer-interview.md`. It preserves the user's answers
through question 48, superseded decisions, and unresolved topics. Then read
`docs/planning/practice-version.md` for decisions 49–61, then
`docs/planning/ui-redesign.md` for the approved Q62–106 redesign and current
authorization: https://github.com/armaan-io/rhythmic/issues/3.

The full-app interview is incomplete. Ask one question at a time, recommend an
answer, and wait for the user's decision. The user subsequently confirmed shared
understanding, tested the timing build, and subsequently authorized the
**four-exercise practice version** in `docs/planning/practice-version.md`.
The approved UI redesign supersedes its earlier visual styling, scoring formula,
and always-accessible diagnostics decisions. It also authorizes persisted
appearance/volume preferences and optional pad haptics (default off). Tempos
remain session-only; Diagnostics is DEBUG-only. Consult
`docs/practice-version-validation.md` for current checks and pending device validation.
The full 24-exercise curriculum and persistent history remain deferred. Do not
expand scope without further confirmation. Permission to save the original
interview was not implementation approval.

The original interview record remains a historical checkpoint. Subsequent scope
authorizations are recorded in the linked planning documents; approved PRDs and
issues still belong in the configured GitHub tracker.
