# Phase 41 — Deferred Items (out of scope)

Discovered during execution of 41-01 (ACT-01). These are NOT caused by 41-01 changes and are
out of the plan's scope boundary. Logged, not fixed.

## Pre-existing test-target compile failures (block `xcodebuild build-for-testing`)

The WorkloadAppTests target uses a `PBXFileSystemSynchronizedRootGroup` (auto-discovers every
`.swift` under `WorkloadAppTests/`). Four UNTRACKED test files reference engines/services/types that
were removed during the v1.5.2 "self-coached strength reset" (stripped coach / RED-S / invite
surfaces — see MEMORY.md). They fail to compile, which prevents the whole test bundle from linking:

- `WorkloadAppTests/REDSRiskEngineTests.swift:17` — `cannot find type 'REDSRiskEngine' in scope`
- `WorkloadAppTests/CoachRelationshipModelTests.swift:24,25` — `cannot find 'AppMode' in scope`
- `WorkloadAppTests/CoachRosterViewModelTests.swift:34,52,76` — `cannot find 'CoachRosterViewModel' in scope`
- `WorkloadAppTests/InviteServiceTests.swift` — references removed `InviteService` (untracked)

All four are UNTRACKED (`git status` shows `??`) — never committed — and correspond to the
`?? WorkloadAppTests/...` entries present at the start of this phase. They belong to the
"dead inert code purge (migration-aware)" cleanup already tracked in MEMORY.md, not to ACT-01.

**Impact on 41-01:** The unit suite cannot be RUN as a whole until these dead test files are
removed/restored. 41-01's own new test file `VerdictSurfaceActivationTests.swift` compiles cleanly
(produces zero errors). Per CONTEXT.md / the plan's font-assert-blocker clause, 41-01 relies on
`xcodebuild build` green (app target) + targeted logic review for verification, and flags this.

**Recommended fix (separate task):** Delete or repair the four untracked dead test files (they test
features intentionally removed), then the full suite — including the three named flag-off fences and
the new VerdictSurfaceActivationTests — can run green.
