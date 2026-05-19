# Battle Screen UI Redesign — Map-Primary + Drawers

**Status**: Shipped (Phase 0 prototype + Phase 1 frame port + Phase 2 per-figure
bookkeeping all runtime-verified). **Engine**: Godot 4.6 GDScript.
**Owner file**: `src/ui/screens/battle/TacticalBattleUI.gd` (+ `.tscn`).
**Keeper widget**: `src/ui/components/common/SlideOverDrawer.gd` (gdUnit 10/10).

This is the durable QA/UX reference for the shared tactical battle screen. It
records WHAT the screen presents, WHERE each thing lives, and WHICH tier gates
it — so QA can verify against intent rather than re-deriving it.

## Why this exists

`TacticalBattleUI` is the one battle screen shared by all four entry points
(Battle Simulator, Bug Hunt, Planetfall, Tactics). The pre-redesign screen
flattened the Core Rules' 5 sequential round-phases and 7+ tracking panels into
one always-on stack, tier gating was inert, and LOG_ONLY instanced ~13 combat
tools it never used. The redesign surfaces the 7 glance categories a player
wants — **crew, map, enemies, objectives, feed, dice, reference** — without
overwhelm, scaling content by tier on one constant frame.

## Frame (identical across all tiers)

```
TopBar:  Title  [TIER]  ‹ROUND n · PHASE›                 Return
┌─ CrewRail (left, glance) ── MAP (BattlefieldMapView) ──┐
│  per-figure mini-cards                                  │  InfoRail (right)
│  Q/S chip · stun pips · HP                              │  Objective + Battlefield
│  ACTIVATED a/M · Q q · S s · ↺ Round                    │  Enemies n/n · casualties
└── FeedStrip (bottom, collapsible — UnifiedBattleLog) ───┘
Toolbar: [Crew][Enemies][Dice][Reference] (+[Tracking] A+ , +[Oracle] ORACLE)
         + journey-spine primary button
DrawerLayer (CanvasLayer L92): one SlideOverDrawer open at a time, scrim,
                                non-blocking, ESC / scrim-tap closes
OverlayLayer (modal L10): tier select, pre-battle checklist, enemy-gen wizard
```

- **Rails are glance summaries; drawers are detail.** The Crew and Enemy
  SlideOverDrawers ARE the per-figure battle tracker (one
  `CharacterStatusCard` + a "Mark Down" eliminate button per `TacticalUnit`).
- **Map zone** is the bare `BattlefieldMapView` (rules-accurate ruler + A1-D4
  sectors + deployment bands), NOT the full `BattlefieldGridPanel` chrome.
- **Layout is container-tiled** (VBox: content row / feed / toolbar; HBox:
  crew | map | info) — regions are disjoint by construction, all persistent
  chrome is opaque, only the drawer scrim is translucent.

## Element → zone → tier map (QA checklist)

| Element | Zone | LOG_ONLY | ASSISTED | FULL_ORACLE |
|---|---|---|---|---|
| Crew mini-cards (HP, stats, Q/S chip, stun pips, activated-recede) | CrewRail | ✅ | ✅ | ✅ |
| Crew per-figure cards (HP/stun/action/Mark Down) | Crew drawer | ✅ | ✅ | ✅ |
| Enemy per-figure cards | Enemy drawer | ✅ | ✅ | ✅ |
| Objective + Battlefield (visibility / hazard / terrain key) | InfoRail | ✅ | ✅ | ✅ |
| Enemy roster + this-round casualties | InfoRail | ✅ | ✅ | ✅ |
| Feed (single `UnifiedBattleLog`) | FeedStrip | ✅ | ✅ | ✅ |
| Dice (`DiceDashboard` + calculators) | Dice drawer | ✅ | ✅ | ✅ |
| Reference (p.119 card + `CheatSheetPanel` + `WeaponTableDisplay`) | Reference drawer | ✅ | ✅ | ✅ |
| Round-phase journey spine + TopBar `ROUND n · PHASE` | Toolbar/TopBar | ✗ (no phase machine) | ✅ | ✅ |
| Tracking (`MoralePanicTracker` / `ActivationTrackerPanel` / `ReactionDicePanel` / `VictoryProgressPanel` / `DeploymentConditionsPanel`) | Tracking drawer | ✗ | ✅ | ✅ |
| Oracle (`EnemyIntentPanel`, overlaid on the enemy tracker) | Oracle drawer / Enemy drawer | ✗ | ✗ | ✅ |
| Result entry | `BattleResultsInputForm` in a drawer | (Record Result) | normal resolution | normal resolution |

## Core Rules anchoring (PyPDF2-verified)

- **Battle Round (p.113)**: 5 phases — Reaction Roll → Quick → Enemy → Slow →
  End Phase. TopBar shows `ROUND n · PHASE`; every round walks the identical
  sequence (no special-case round 1).
- **Reaction Roll (p.114)**: D6 per crew figure vs its Reactions — ≤ Reactions
  → QUICK slot, > → SLOW; enemies always ENEMY. Populates the rail's Q/S
  chips (`_assign_crew_reaction_slots`, ASSISTED+).
- **Activation (p.114)**: each figure acts once per round; reset every round.
  Activated figures recede (dim, no accent border) so the eye lands on who
  still has to act.
- **Stun (pp.116-118)**: stackable; a marker is removed only **after** the
  stunned figure acts — so Stun **persists across rounds** (the round reset
  deliberately does NOT clear it).
- **End Phase Morale (pp.114-115)**: ONLY if the enemy lost figures that
  round. 1D6 per casualty within Bail Range = 1 enemy Bails. The player never
  tests morale. Enemy "Down" feeds `casualties_this_round`; End Phase rolls
  and removes bailed enemies.
- **Seize Initiative (p.112)**: once, before round 1 only — surfaced one-time
  from the pre-computed `_battle_context["seize_initiative_result"]`.

## Per-figure bookkeeping wiring (Phase 2, SSOT)

`TacticalUnit` (inner class) is the single source of truth — it holds
`stun_markers`, `is_activated`, `react_slot` plus `reset_for_new_round()`.
Views (cards, rails, `ActivationTrackerPanel`) signal mutations up; the parent
calls down. Chain:

- `CharacterStatusCard` Stun/Damage/Action buttons → `_on_card_stun` /
  `_on_card_damage` / `_on_card_action` → mutate the bound `TacticalUnit` +
  `UnifiedBattleLog` + `ActivationTrackerPanel`, then rebuild rails.
- `_mark_casualty` is the single casualty chokepoint (idempotent): sets
  `is_dead`, marks the activation tracker defeated, and — for enemies —
  increments `casualties_this_round` (the iter-3 morale bridge). A
  `feed_morale=false` path removes Bailed enemies without re-feeding morale.
- Round machine: `_reset_all_unit_reactions` (round start) clears activation +
  reaction slot, keeps Stun, resyncs the ASSISTED trackers; `_on_round_phase_
  changed` assigns reaction slots at REACTION_ROLL and resolves Morale at
  END_PHASE; the rail "↺ Round" affordance calls `_on_manual_round_reset`.
- **Ordering**: `_on_tier_selected` rebuilds the drawers after instancing the
  ASSISTED engines, so the `ActivationTrackerPanel` is populated (the cards
  were first built during `initialize_battle`, before a tier was chosen).

## Verification status (2026-05-18)

- Parse-clean (`load()` of the script returns non-null; all Phase 2 symbols
  present).
- Empirical MCP `run_script` on a bug_hunt context, LOG_ONLY: drawers
  populated (crew/enemy `CharacterStatusCard`s), card→model SSOT for
  stun/damage/action, Reaction Roll assigns valid Q/S, round reset keeps Stun
  and clears activation + crew slot, enemy slot stays ENEMY.
- ASSISTED: iter-3 morale bridge (`casualties_this_round++`), End Phase
  `perform_morale_check()` + bail removal, no-casualty → no morale,
  `ActivationTrackerPanel` holds all figures.
- Screenshot: Crew drawer visually populated (per-figure cards + live Stun
  status + Mark Down).
- All 4 entry-point `battle_mode` branches load and populate.
- gdUnit battle regression: 50/51 (activation_tracker 12/12,
  battle_objective_tracker, post_battle_success_cascade 4/4,
  battle_tier_controller 13/13 all pass).

### Follow-up fixes (2026-05-19, post-review)

- **Wide drawers**: `SlideOverDrawer` gained an opt-in `min_panel_width`
  (`@export`, default 0.0 = unchanged tight column, keeper test stays 10/10).
  Crew / Enemy / Dice / Tracking / Oracle / Results drawers set it to 480 via
  `_make_drawer(..., wide=true)` so a full `CharacterStatusCard` (5-button
  action row + status line) fits without a horizontal scrollbar or clipped
  controls. Width is CONTENT-sized (`minf(min_panel_width, vp.x*0.5)`), NOT a
  viewport fraction — it does not balloon into a screen takeover on wide
  monitors; the map stays visible (non-blocking intent preserved). Host also
  autowraps the reused card's `status_label`/`stats_label` (no edit to the
  shared `CharacterStatusCard.gd`).
- **Rules-faithful crew injury routing (user-confirmed)**: a crew figure that
  goes Out of Action now ALWAYS routes to `crew_injuries_data` in
  `_resolve_battle()` → the standard post-battle Injury Table decides
  dead/injured/recovered (Core Rules p.122). Previously `is_dead` pre-
  classified Mark-Down crew into the harsher `crew_casualties_data` "Roll
  Severity" sub-path (no "no effect" outcome). `is_dead` is retained only as
  the clean in-battle "off the table" flag (rail styling, Down button,
  morale idempotency, enemy-at-0-HP correctness); the rules split happens at
  the single resolve-time classification point. Enemies are unaffected (they
  die outright in battle and feed End-Phase Morale; they never roll the crew
  Injury Table). Verified: 2 Mark-Down crew → `crew_casualties=0`,
  `crew_injuries=2`. Regression: keeper drawer 10/10, post-battle cascade
  4/4, objective tracker 14/14.

### Post-battle + turn-rollover consistency (verified 2026-05-19)

The rules-faithful crew routing was verified consistent end-to-end:
`_resolve_battle()` only changes which display bucket downed crew enter
(all → "Roll Injury"); the persist/rollover mechanism is unchanged.
`InjurySystemService.determine_injury()` takes only the d100 roll (one
table, no is_casualty branch), so a downed crew member can still die
(empirical sweep: 15/100 fatal, e.g. roll 1 = GRUESOME_FATE) or get
recovery (50/100, feeds `CampaignPhaseManager._process_sick_bay_recovery`
turn decrement). Bitter Day (Core Rules p.67) reads the PROCESSED
`battle_result["casualties"]` by `type`, not the pre-roll count, so it
still fires on an injury-roll fatality. No downstream consumer requires
`crew_casualties > 0`. Regression: injury determination 13/13, injury
recovery 15/15, post-battle subsystems 10/10, success cascade 4/4.

**Pre-existing bug found & fixed during this verification**
(`InjurySystemService.gd:63`, untouched since 2026-04-02 — NOT a Phase 2
regression): `result.description = range_data.description` accessed a key
that `InjurySystemConstants.INJURY_ROLL_RANGES` never carries (entries are
`{min, max}` only). Every post-battle injury roll logged a `SCRIPT ERROR`
and returned a blank description (not a hard crash — Godot continues past
the error; `is_fatal`/`recovery_turns` were still correct). Fixed to read
the canonical `InjurySystemConstants.get_injury_description(injury_type)`,
mirroring the adjacent `type_name` lookup. Surfaced because the rules-
faithful routing now sends 100% of downed crew through this path.

### Known pre-existing (out of scope)

`tests/unit/test_battle_round_tracker.gd::test_battle_event_triggers_on_round_2`
fails: it expects bare `advance_phase()×5` to auto-emit `battle_event_
triggered`, but `BattleRoundTracker` (line ~186) requires the UI to call
`check_battle_event()` after overlay dismissal to avoid double-firing while a
modal is up. `BattleRoundTracker.gd` is unchanged by this redesign (commit
`dbf9980d`); the test encodes a stale expectation. Track separately.
