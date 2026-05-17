# Test Case Template

**Purpose**: Standardized format for individual test cases. Reused across alpha-1, alpha-2, beta, and post-launch QA cycles.
**Scope**: Reusable template — copy this file and rename to `TC-<area>-<NNN>.md` for each new test case (e.g., `TC-DLC-001.md`, `TC-PRICING-002.md`).
**Companion templates**: `BUG_REPORT_TEMPLATE.md`, `TEST_EXECUTION_REPORT_TEMPLATE.md`, `TEST_SUMMARY_REPORT_TEMPLATE.md`.

---

## How to use

1. Copy this file to `docs/testing/test-cases/TC-<area>-<NNN>.md`
2. Replace placeholder text in `<...>` blocks
3. Set `status: draft` until reviewed; flip to `active` once locked
4. Link from the relevant test plan + traceability matrix
5. After execution, link the result back from the Test Execution Report

---

## TC-`<AREA>`-`<NNN>`: `<Test Case Title>`

| Field | Value |
|---|---|
| **Test Case ID** | TC-`<AREA>`-`<NNN>` |
| **Title** | `<concise description of what is being verified>` |
| **Area** | `<Campaign / Battle / DLC / Telemetry / Survey / Conversion / Save-Load / Accessibility / etc.>` |
| **Priority** | P0 (critical, blocks release) / P1 (high, ships with workaround) / P2 (medium, defer 1 cycle OK) / P3 (low, cosmetic) |
| **Type** | Functional / Regression / Smoke / Integration / Performance / Usability / Accessibility / Security |
| **Method** | MCP-automated / Manual / Hybrid (MCP preconditions + manual verification) |
| **Test Plan** | Link to parent test plan (e.g., `ALPHA_1_TEST_PLAN.md` §X) |
| **Related Scenario** | Link to integration scenario (e.g., `QA_INTEGRATION_SCENARIOS.md` S11) |
| **Related Mechanic(s)** | Link to game mechanic in `GAME_MECHANICS_IMPLEMENTATION_MAP.md` (if applicable) |
| **Author** | `<name>` |
| **Created** | YYYY-MM-DD |
| **Last Updated** | YYYY-MM-DD |
| **Status** | draft / active / deferred / retired |
| **Estimated Duration** | `<X minutes>` |

---

### Objective

`<One-paragraph description of what this test case proves. State the user-visible behavior or system invariant being verified. Avoid implementation details — those go in Steps.>`

### Preconditions

- `<Preconditions that must be true before the test can run, e.g., "Fresh user:// state — no existing saves or consent file">`
- `<E.g., "Build version A1 or later installed">`
- `<E.g., "Analytics consent gate ENABLED in Settings">`

### Test Data

- `<Inputs required, e.g., specific save file, character configuration, mock data>`
- `<E.g., "save file: tests/fixtures/saves/turn_5_with_full_crew.json">`

### Environment

- **Platform**: Windows 10/11 (alpha-1 scope) / macOS / Linux / Android / iOS
- **Build**: `<vX.Y.Z-alphaN.AM>`
- **Hardware tier**: Minimum / Recommended / Wide
- **Display**: 1080p / 1440p / 4K / portrait mobile / landscape mobile
- **Configuration**: `<DLC flags, accessibility settings, etc.>`

### Steps

| Step | Action | Expected Result | Actual Result | Pass/Fail |
|---|---|---|---|---|
| 1 | `<action — be precise, no ambiguity>` | `<observable outcome>` | `<filled at execution>` | `<filled at execution>` |
| 2 | `<...>` | `<...>` | | |
| 3 | `<...>` | `<...>` | | |

### Acceptance Criteria

All of the following must hold for the test case to pass:

- [ ] `<Criterion 1 — verifiable, binary outcome>`
- [ ] `<Criterion 2>`
- [ ] `<Criterion 3>`

### Failure Conditions

If any of these occur, the test FAILS regardless of step-level results:

- `<E.g., "App crashes at any point">`
- `<E.g., "Save file is corrupted (cannot be reloaded)">`
- `<E.g., "Telemetry event fires when consent flag is OFF">`

### Cleanup / Post-conditions

- `<Steps to restore a clean state for the next test, e.g., "Delete user://saves/qa_test_*.json">`
- `<E.g., "Reset consent state via Settings → Privacy → Delete all data">`

### Notes

- `<Any non-blocking observations, e.g., "Step 5 timing varies on slow disks — allow up to 10 seconds">`
- `<Cross-references, e.g., "Related to BUG-042 fixed in Session 48">`

### MCP Automation Snippet (if Method=MCP or Hybrid)

```gdscript
# Paste the exact MCP run_script body that automates this test case.
# Should be self-contained and idempotent.
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    var checks = []
    # Step 1: <action>
    # Step 2: <action>
    # ...
    return {"status": "PASS" if checks.is_empty() else "FAIL", "details": checks}
```

### Execution History

| Date | Build | Tester | Pass/Fail | Notes / Linked Bug Report(s) |
|---|---|---|---|---|
| YYYY-MM-DD | `<vX.Y.Z-alphaN>` | `<name>` | PASS / FAIL | `<link to bug report if FAIL>` |

---

## Authoring Guidelines

### Writing good test case Objectives

- **State the invariant, not the implementation.** "Save/load roundtrip preserves character XP" not "GameState.load_campaign() restores Character.experience field."
- **Tie back to user value.** "Tester can dismiss the pricing survey" not "PricingPerceptionSurvey.cancel_button.pressed signal fires."

### Writing good Steps

- **Numbered, atomic, observable.** Each step should be one action with one observable result.
- **No conjunctions in step descriptions.** "Click Save" + "Click Load" = TWO steps, not one.
- **Use exact UI labels.** "Click 'Get the Physical Edition'" not "click the link to buy the book."
- **Reference data sources.** "Verify credits == 25 (per Core Rules p.28 starting credits formula)" not "verify credits are correct."

### Severity vs Priority

- **Priority** (P0-P3) is *test* priority — how important is it that this test runs.
- **Severity** (P0-P3 in bug reports) is *defect* priority — how bad is the bug if it fires.

A high-priority test (P0) might find a low-severity bug (P3) and vice versa.

### When to retire a test case

A test case becomes `retired` when:

- The feature it covers is removed from the product
- It's been superseded by a more comprehensive test case (link the replacement)
- The mechanic it verifies is now covered by an MCP-automated regression in `tests/`

Do not delete retired test cases — set `status: retired` and add a "Retirement reason" line. Auditability matters more than tidiness.

---

*Template v1, 2026-05-01. Owned by QA. Update template only if the structure itself changes; for individual test cases, copy and edit.*
