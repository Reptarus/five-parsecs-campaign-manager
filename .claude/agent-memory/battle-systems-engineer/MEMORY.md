# Battle Systems Engineer — Agent Memory

<!-- Loaded into your system prompt. KEEP UNDER 200 LINES. -->
<!-- Durable rules only. Dated session logs were archived 2026-08-06 to -->
<!-- docs/archive/agent-memory-logs/battle-systems-engineer-MEMORY-2026-08-06.md -->

## ABSOLUTE RULE

The Core Rules and Compendium PDFs at `docs/rules/` are canonical for ALL combat mechanics, weapon
stats, and battle rules. If code disagrees with the book, the code is wrong. Extraction commands and
the source-authority hierarchy live in `CLAUDE.md` — don't duplicate them here.

---

## Critical Gotchas — Must Remember

1. **`BattleResolver` is static** (RefCounted) — call `BattleResolver.resolve_battle()`, never
   instantiate as a Node.
2. **`TacticalBattleUI` is shared** by Standard, Bug Hunt, Planetfall and Battle Simulator. A change
   must not break any of them.
3. **Godot 4.6 type inference**: `var x := dict["key"]` will NOT compile — Dictionary values are
   Variant. Always `var x: Type = dict["key"]`. Zero exceptions.
4. **Per-figure SSOT**: `TacticalUnit` is the model — `stun_markers` / `is_activated` / `react_slot`
   live there; `CharacterStatusCard`, the rails and `ActivationTrackerPanel` are views. Parent calls
   down, child signals up via `_on_card_*`. `_mark_casualty` is the single idempotent casualty
   chokepoint (guarded by `is_dead`); `feed_morale=false` is for bail-removal only.
5. **Crew "Mark Down" = Out of Action, NOT confirmed dead.** `_resolve_battle()` routes ALL downed
   crew (`health <= 0`) into `crew_injuries_data` → the post-battle Injury Table (Core Rules p.122)
   decides dead/injured/recovered. The table is the arbiter, not the in-battle button. Enemies die
   outright (they feed End-Phase Morale and don't roll injury). **Do NOT re-split by `is_dead` at
   resolve time.**
6. **`SlideOverDrawer` wide-drawer contract**: opt-in `@export var min_panel_width: float = 0.0`
   (0 = unchanged tight column). Wide drawers (Crew/Enemies/Dice/Tracking/Oracle/Results) request
   ~480px **content**-sized via `minf(min_panel_width, vp.x * 0.5)`. **Never size a content panel as
   a viewport fraction** — `vp.x * 0.42` balloons to 828px on a wide monitor and becomes a
   half-screen takeover.
7. **`BattleRoundTracker.battle_event_triggered` requires the UI to call `check_battle_event()`**
   after the overlay (~L186) to avoid a modal double-fire. A bare `advance_phase()` ×5 does NOT
   auto-emit. The pre-existing `test_battle_event_triggers_on_round_2` encodes the wrong
   expectation — known, out of scope.
8. **DLC-gated MECHANICS must wire at BOTH the setup UI AND the runtime resolver.** Adjusted Shooting
   had a clean `if attacker.get("dramatic_combat", false)` branch in
   `BattleCalculations.resolve_ranged_attack` with **no resolver setting the flag** — pure dead code,
   while "DRAMATIC COMBAT ACTIVE" showed on the setup screen. Pattern: at the top of `resolve_battle`
   call `CompendiumDifficultyToggles.get_adjusted_shooting_thresholds()` (self-gating, returns `{}`
   when off), stash on `battlefield_data`, inject into the attacker dict before each
   `resolve_ranged_attack`. **`BattleResolver` AND `NoMinisResolver` both need it — separate code
   paths.** Applies to any future DLC mechanic touching per-shot math.

---

## 🛑 The dominant defect in this domain: the rule is right, the CALL is missing

When something looks missing, the first move is **not** "write it" — it is:

> **Check whether a function implementing it already exists with no caller.**

That was the answer five times in one day (Aug 6 2026): an early return above four setup calls, a
call made before its target existed, a drawer with no opener, and two zero-caller producers
(`find_salvage_job`, the ungated `build_*` grid functions).

**No key census can find this class.** The key is written AND read; producer and consumer both exist
and are correct. Only tracing **execution order on the path a real campaign takes** finds it.

- `CampaignTurnController` stamps `selected_tier` on **every** campaign battle — any branch keyed on
  it is the NORMAL path, not an edge case.
- Ask "which container does this get added to, and does that container have an opener **at the
  default tier**?" LOG_ONLY (0) is the default, not ASSISTED.
- A `has_method()` guard on a method with **zero definitions repo-wide** is a permanently-false
  branch, not a safety net. `grep "func <name>"` before trusting it.
- Grepping a **wrapper** and finding zero callers says nothing about the rule — follow it to what it
  delegates to. `get_deployable_crew()` has no callers; the gate it wraps (`filter_deployable`) is
  live at four sites.
- `queue_free()` **defers** to end of frame — `remove_child()` FIRST when rebuilding a container in
  place, or old and new children coexist for a frame (a toolbar rebuild returned 14 buttons, not 7).
- A **containment assertion is blind to duplication** — asserting a button is present passes even
  when the set is duplicated.

**Anything the post-battle sequence needs about the scenario must be stamped onto `mission_data`
BEFORE the battle** and pass through `BattleResultNormalizer` — the one chokepoint all four exit
paths cross (played, LOG_ONLY, in-battle auto-resolve, map auto-resolve). Adding a consumer read
without a producer write is the bug, not the feature.

---

## Combat is a TWO-axis model

Representation (full-minis / grid / no-minis / auto-resolve) × Dramatic-Combat flavor toggle.
These are orthogonal — do not collapse them.

- **Per-battle representation picker** is live in `PreBattleUI`: 3 radios →
  `selected_representation_mode` ∈ `{play_on_table, no_minis, auto_resolve}`. `no_minis` is gated on
  `dlc.is_feature_available(NO_MINIS_COMBAT)`; `auto_resolve` is ungated and greys the
  LOG/ASSISTED/FULL_ORACLE tracking radios. `CampaignTurnController._on_deployment_confirmed()`
  routes `auto_resolve` → `_on_auto_resolve_completed({})`, else injects
  `md["representation_mode"]` before `initialize_battle`. `TacticalBattleUI._setup_no_minis_panel`
  honors the per-battle choice over the global toggle.
- **No-Minis** (`NoMinisResolver.gd`) is book-faithful round/firefight/morale-bail with a Salvage
  fallback.
- **Grid Movement (pp.90-93) SHIPPED Aug 6 2026** — the three previously-zero-caller `build_*`
  functions are now wired to the per-battle choice. (Older notes calling B4 "not started" are stale.)

## Played-battle END path + objective authority

- A PLAYED battle at any tier once had **no reachable control to end it or declare the objective**:
  `BattleRoundTracker.end_battle()` had zero callers, LOG_ONLY has no victory check
  (VictoryProgressPanel is ASSISTED+), and `_mark_casualty` never ends the battle.
- Fix: an always-reachable emerald **✔ Record Result** button in `_rebuild_drawer_toolbar`
  (landscape) and `_rebuild_panels_menu` (portrait). `_on_record_result_pressed()` →
  `_ensure_results_form_drawer()` (idempotent, prefilled by `_build_results_prefill()` from
  `_objective_tracker`) → `_open_drawer("results")` → submit → `tactical_battle_completed` →
  PostBattle. The tier-0 skip in `_on_checklist_dismissed` was removed — all tiers get the full
  companion.
- **`BattleResultsInputForm` is objective-aware**: mission `success` = the declared objective outcome
  (p.90), **NOT** the Won/Lost proxy.
- **`fled_early` means the p.123 XP rule** ("flees in the first 2 rounds") — NOT the p.91 Rival
  item-loss window ("before 4 rounds"). Different windows; conflating them denies XP the book pays.
- **"Enemy Morale +1" (p.88 Bitter Struggle) means the Panic range goes DOWN.** Compendium p.49's
  Leadership table settles the direction.
- Regression: `test_battle_results_input_form.gd` (6), `test_tactical_downed_unit_row.gd` (3).
  Harnesses: `verify_battle_ui` 79/79, `verify_post_battle` 46/46.

## Return-value discipline

A red harness row is a **lead, not a verdict** — all three long-standing `verify_post_battle`
failures turned out to be TEST defects. Widen the observation, never relax the assertion, then prove
the test can still fail.
