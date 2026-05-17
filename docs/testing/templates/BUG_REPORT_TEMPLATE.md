# Bug Report Template

**Purpose**: Formal bug report format for internal triage, partner-shareable defect tracking, and stakeholder reporting. Distinct from the Discord pinned-message template in `ALPHA_TESTER_ONBOARDING.md` (which is the lightweight tester intake format).
**Scope**: Reusable template — each filed bug becomes an entry in `docs/testing/DEFECTS_LOG.md` and may also produce a standalone file at `docs/testing/bug-reports/BUG-<NNN>-<slug>.md` if it warrants extended triage.

**Two-format model**:

- **Discord-template (tester)**: lightweight, fast, no jargon. See `ALPHA_TESTER_ONBOARDING.md` Discord section.
- **This template (internal/QA)**: structured, full metadata, fits triage workflow + reporting.

When a tester files a Discord report, QA promotes it to this format during triage and adds the formal entry to `DEFECTS_LOG.md`.

---

## How to use

1. Copy this template to `docs/testing/bug-reports/BUG-<NNN>-<slug>.md` (e.g., `BUG-042-pricing-survey-randomization.md`)
2. Or, for routine bugs, just add a row to `docs/testing/DEFECTS_LOG.md` table with the abbreviated fields
3. Fill all required fields (marked **REQUIRED**); leave optional fields blank if not applicable
4. Update status as the bug progresses through the lifecycle (see §Lifecycle below)

---

## BUG-`<NNN>`: `<one-line summary>`

### Header

| Field | Value | Required |
|---|---|---|
| **Bug ID** | BUG-`<NNN>` (next available from DEFECTS_LOG.md) | ✓ |
| **Title** | `<concise — under 80 chars; reads as "WHAT is broken WHERE">` | ✓ |
| **Reported By** | `<tester Discord handle / QA name>` | ✓ |
| **Reported Date** | YYYY-MM-DD | ✓ |
| **Build** | `<vX.Y.Z-alphaN.AM>` (check Settings → About) | ✓ |
| **Platform** | Windows 10/11 / macOS / Linux / Android / iOS | ✓ |
| **Game Mode** | Standard 5PFH / Bug Hunt / Planetfall / Tactics / Battle Simulator | ✓ |
| **Severity** | P0 (game-breaking) / P1 (major UX) / P2 (annoying) / P3 (cosmetic) | ✓ |
| **Priority** | Immediate / This Build / Next Build / Backlog | ✓ |
| **Component / Area** | `<e.g., Save/Load, Battle UI, DLC Toggle, Telemetry, Pricing Survey>` | ✓ |
| **Status** | New / Triaged / In Progress / Fixed / Verified / Reopened / Won't Fix / Duplicate | ✓ |
| **Assigned To** | `<engineer name / agent>` | ✓ once triaged |
| **Found in Test Case** | `TC-<area>-<NNN>` (link to test case if found via execution) | optional |
| **Related Scenario** | `<S<NN>>` from `QA_INTEGRATION_SCENARIOS.md` | optional |
| **Duplicate Of** | `BUG-<NNN>` (if status=Duplicate) | optional |
| **Resolved Date** | YYYY-MM-DD | filled when status=Fixed |
| **Verified Date** | YYYY-MM-DD | filled when status=Verified |
| **Fixed in Build** | `<vX.Y.Z-alphaN.AM>` | filled when status=Fixed |

---

### Description

`<2-4 sentences. State WHAT the bug is, WHERE it occurs, and what makes it a defect rather than a design choice. Avoid speculation about root cause — that goes in §Triage Notes.>`

### Steps to Reproduce

Numbered, atomic, observable. Anyone reading this should be able to follow the steps verbatim and reproduce the defect.

1. `<action>`
2. `<action>`
3. `<action>`
4. **Bug fires here**: `<observed defect>`

### Expected Behavior

`<What SHOULD have happened, with reference to source if possible (e.g., "Per Core Rules p.76, upkeep should be...")>`

### Actual Behavior

`<What DID happen — be specific. Quote exact text, screenshot subject, log lines.>`

### Reproducibility

| Field | Value |
|---|---|
| **Reproducibility Rate** | Always / Sometimes / Once / Cannot Reproduce |
| **Attempts** | `<X out of Y attempts produced the defect>` |
| **Conditions Required** | `<E.g., "Only on fresh user:// state — does NOT reproduce after 1 turn played">` |

### Impact

- **User-visible impact**: `<What does the tester see? "Cannot continue past Turn 3" / "Visual glitch only" / "Save loss">`
- **Workaround**: `<E.g., "Restart app and reload save"; "None known">`
- **Affected scope**: `<E.g., "All Standard 5PFH campaigns past Turn 5"; "Only when DLC flag X is ON">`
- **Frequency in cohort**: `<filled by QA: how many testers hit this — 1/15, 5/15, etc.>`

### Attachments

- **Screenshot/video**: `<filename or Discord link>`
- **Save file**: `<filename or Discord link>` — sanitize PII before sharing externally
- **Crash log**: `<path in user://crash_logs/ or attached file>`
- **Console output**: ` ``` paste relevant snippet ``` `
- **Talo telemetry session ID**: `<UUID>` (allows pulling exact session timeline from Talo dashboard)

### Triage Notes (filled by QA / engineer during triage)

- **Suspected root cause**: `<E.g., "Likely race condition in save serialization — see CampaignAnalytics autoload init order">`
- **Files / lines under suspicion**: `<E.g., src/core/state/GameState.gd:142>`
- **Effort estimate**: XS (<30 min) / S (1-2h) / M (half-day) / L (full day) / XL (multi-day)
- **Risk of fix**: Low / Med / High (chance fix introduces regression elsewhere)
- **Tests required**: `<E.g., "Add TC-SAVELOAD-014 covering empty crew array roundtrip">`

### Resolution

- **Fix description**: `<What changed in code — 1-2 sentences>`
- **Files modified**: `<paths and line numbers>`
- **PR / commit**: `<git ref>`
- **Verification steps**: `<How QA confirms the fix>`
- **Regression test added**: `<TC-<area>-<NNN> link, or N/A>`
- **Side effects considered**: `<E.g., "Tested S11 DLC toggle still works after fix">`

### Verification

- **Verified by**: `<QA name>`
- **Verified on build**: `<vX.Y.Z-alphaN.AM>`
- **Verification date**: YYYY-MM-DD
- **Verification result**: PASS / FAIL (reopened) / Partial (with notes)
- **Notes**: `<E.g., "Verified primary repro path; secondary path not yet retested">`

### Related Bugs

- **Duplicates**: `<BUG-NNN>`
- **Blocks**: `<BUG-NNN that depends on this fix>`
- **Blocked By**: `<BUG-NNN this depends on>`
- **Caused regression**: `<BUG-NNN introduced as side effect of this fix>`
- **Related context**: `<BUG-NNN with similar root cause>`

### Communication Log

For high-severity bugs (P0/P1) where multiple stakeholders are involved:

| Date | Channel | Direction | Summary |
|---|---|---|---|
| YYYY-MM-DD | Discord / Email / Sync | Inbound from `<tester>` | Initial report |
| YYYY-MM-DD | Discord | Outbound to cohort | "Investigating; thanks" |
| YYYY-MM-DD | Sync | Modiphius (Gavin) | Heads-up — fix shipping in A2 |

---

## Lifecycle

```
New ──→ Triaged ──→ In Progress ──→ Fixed ──→ Verified ──→ [end]
                          ↓
                      Reopened ──→ (back to In Progress)

Alternative endings:
Triaged ──→ Won't Fix (with rationale)
Triaged ──→ Duplicate (link the canonical bug)
```

| Status | Meaning | Owner | Action to advance |
|---|---|---|---|
| **New** | Just filed; not yet triaged | QA on intake | Triage within 24h for P0/P1, weekly for P2/P3 |
| **Triaged** | Severity + priority + owner assigned | QA | Engineer picks up |
| **In Progress** | Actively being fixed | Assigned engineer | Engineer reports fix complete |
| **Fixed** | Code change complete + merged + in next build | Engineer | QA verifies in next build |
| **Verified** | QA confirmed fix in tested build | QA | Bug closed |
| **Reopened** | Verification failed or regression discovered | QA | Re-triage; back to Triaged status |
| **Won't Fix** | Decision: not worth fixing this cycle | QA + product | Document rationale; archive |
| **Duplicate** | Same root cause as another bug | QA | Link canonical; archive this entry |

---

## Severity Definitions (canonical)

| Tier | Definition | Examples | Response SLA |
|---|---|---|---|
| **P0 — Game-Breaking** | Crash, data loss, save corruption, complete inability to continue. Blocks the build from shipping to wider audience. | App crashes on launch; saves cannot be loaded; campaign turn cannot complete; payment processed but DLC not unlocked | Same-day triage; same-week fix |
| **P1 — Major UX** | Feature does not work as documented; major visual bug; blocks an action but workaround exists. | Pricing survey questions appear in fixed order (not randomized); DLC flag toggle ON shows no visible effect; battle resolves with wrong winner | Within-build fix |
| **P2 — Annoying** | Minor visual glitch, awkward flow, typo in important text. User can play through. | Stat badge alignment off by 4 pixels; tooltip shows on click but not hover; misleading button label | Next-build fix |
| **P3 — Cosmetic** | Typo elsewhere, polish suggestion, nice-to-have. | Misspelled species description in Compendium; suggestion to reorder Settings entries | Backlog or "won't fix" |

## Priority vs Severity

These are different axes:

- **Severity** = how bad the defect is (impact)
- **Priority** = how urgent the fix is (when we do it)

A P3-severity typo on a public marketing screen might be **Immediate** priority (don't ship with it). A P0-severity crash in a deeply-niche edge case might be **Backlog** priority (we'll fix it when we get to it).

| Priority | Meaning |
|---|---|
| **Immediate** | Stop other work; fix now. |
| **This Build** | Ship in the next weekly build (Mon). |
| **Next Build** | Ship in build after next. |
| **Backlog** | Not scheduled; revisit at next sprint planning. |

---

## Authoring Guidelines

### Writing good titles

- **Subject + verb + location.** "Pricing survey questions appear in fixed order on Windows" not "Survey bug."
- **Avoid jargon.** Don't title with class names.
- **One bug per report.** If you find two, file two reports.

### Writing good repro steps

- **Numbered, atomic.** Each step is one action.
- **Start from a known state.** "Fresh `user://`" or "Existing campaign at Turn 5 with full crew" — name it.
- **Anyone could follow this verbatim.** Don't assume context.

### When to escalate

A P0 found in alpha → notify Modiphius via Gavin sync within 24h with: title, severity, scope (how many testers affected), eta-to-fix. Don't hide P0s; partnership credibility depends on transparency.

---

*Template v1, 2026-05-01. Owned by QA. Update template only if structure changes; for individual reports, copy and edit.*
