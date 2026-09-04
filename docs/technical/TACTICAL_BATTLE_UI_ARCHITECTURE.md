# TacticalBattleUI — Architecture

**Last verified**: 2026-09-03, against `TacticalBattleUI.tscn` and `.gd` as they
stand. **Engine**: Godot 4.6.

> **This document was rewritten from the files.** The previous version described a
> screen with `LeftTabs` / `CenterTabs` / `RightTabs` TabContainers, a
> `BattlefieldGridPanel`, a `ContactMarkerPanel` and a `BattleJournal`. None of
> those exist: the tab layout was replaced by the map-primary drawer frame in May
> 2026, `BattlefieldGridPanel` was deleted, `ContactMarkerPanel` was deleted in
> `5125a0e4`, and `BattleJournal` was superseded by `FPCM_UnifiedBattleLog` and its own files were then DELETED 2026-09-04 (orphaned: zero instantiations, no scene embed, no preload). A long
> stale document is worse than a short accurate one, so this is the short one.

## The scene is a shell; the screen is code

`TacticalBattleUI.tscn` is ~287 lines and contains no battle content at all:

```
TacticalBattleUI (Control)
└── EdgeMargin (MarginContainer)
    └── MainContainer (VBoxContainer)
        ├── TopBar        Title · %TierBadge (Button) · %PhaseBreadcrumb · %ReturnButton · %AutoResolveButton
        ├── ContentArea (HBox)
        │   ├── %CrewRailPanel  → %CrewRail      (glance mini-cards, left)
        │   ├── %MapHost        → BattlefieldMapView, built in code
        │   └── %InfoRailPanel  → %InfoRail      (objective, battlefield, enemies)
        ├── %FeedStrip          → %FeedHost      (the one FPCM_UnifiedBattleLog)
        └── BottomBar
            └── BottomContent   %PhaseHUD/%TurnIndicator · ActionBar(%PhaseButtonsContainer, %EndTurnButton)
├── DrawerLayer   (CanvasLayer, layer 92)  — SlideOverDrawers
└── OverlayLayer  (CanvasLayer, layer 10)  — %OverlayBackground, %OverlayCenter/%OverlayContent
```

Everything else — the map, the rails, the drawers, the phase banner, the mobile app
bar — is constructed by `_build_redesign_frame()`. Several legacy script variables
are permanently `null` shims (`right_tabs`, `phase_content_panel`); the `if
right_tabs:` guards scattered through the file are therefore dead branches, kept
only because removing ~30 of them is churn without benefit.

## Seven drawers, one modal layer

`_make_drawer()` builds `crew`, `enemies`, `intel`, `dice`, `reference`, `tracking`
and `mission`. The legacy content hosts point at drawer bodies:

| Script var | Drawer body |
|---|---|
| `phase_content`, `setup_content` | `tracking` |
| `tools_content` | `dice` |
| `reference_content` | `reference` |

The toolbar is tier-filtered — `crew/enemies/intel/dice/reference` always, plus
`tracking` at ASSISTED+. **`mission` is gated on MISSION TYPE, not tier**: a player
running the whole fight by hand needs the salvage/stealth/street-fight procedure
more than an assisted one, not less. **Record Result is appended after the
tier-filtered loop, so it exists at every tier.**

There is deliberately no `oracle` drawer. The AI oracle is an intent layer that
reparents to the top of the `enemies` drawer.

`OverlayLayer` carries every modal: the tier picker, the pre-battle modal, the
Seize the Initiative calculator, the Hit resolution sheet, the enemy-generation
wizard and the casualty confirm. Nothing on this screen uses a `Window`.

## The entry sequence (fixed 2026-09-03)

```
CampaignTurnController._on_deployment_confirmed()
  stamps selected_tier + representation_mode onto mission_data
    → initialize_battle(crew, enemies, mission_data)
        _reset_battle_state()                  ← the screen is REUSED, not re-created
        _on_tier_selected(tier, defer_checklist = true)
        …Compendium mission panels, No-Minis, story markers…
        _prepare_battle_context()              ← objective tracker BEFORE the card
        _try_restore_battle_checkpoint()  ──┬── true  → straight into COMBAT
                                            └── false → _show_pre_battle_checklist()
                                                          (Battle Card + checklist
                                                           + p.110 deployment card)
                                                          ↓ Begin Battle
                                                        _on_checklist_dismissed()
                                                          → _begin_combat()   ← THE ONLY STARTER
```

`_begin_combat()` guards on `round_tracker.get_current_round() > 0`, so no second
caller can restart round 1. `_on_auto_deploy_clicked()` is a thin alias to it.

## The round machine

`BattleRoundTracker` owns round and phase (`REACTION_ROLL, QUICK_ACTIONS,
ENEMY_ACTIONS, SLOW_ACTIONS, END_PHASE`, Core Rules p.113). It also has
`restore(round, phase)`, which is deliberately **silent** — emitting `round_started`
would reset the very bookkeeping a resume exists to bring back.

**One control advances a phase.** `_on_primary_phase_action()` is the single entry
point; the HUD's Next Phase and Mark Done both route through it, and `End Turn` is
hidden during COMBAT. At REACTION_ROLL it rolls rather than skipping, so no
affordance can advance past the roll. The HUD's five phase chips are inert
indicators (`MOUSE_FILTER_IGNORE`) — they used to emit a `phase_clicked` nothing
consumed.

**The Reaction Roll is made once per round, by the player.** `_show_reaction_roll_ui`
offers "Roll Reactions"; after rolling, the same button becomes "Continue to Quick
Actions".

**Seize the Initiative is offered once, before round 1** (p.112), from
`_on_tracker_battle_started` → `_show_seize_initiative_prompt()`.

## Per-figure model

`TacticalUnit` (inner class) is the SSOT. Cards, rails and the tracking drawer are
views. There are **no hit points** — Core Rules p.46 resolves a Hit as a casualty
or a Stun, nothing in between:

| Field | Meaning |
|---|---|
| `stun_markers` | stackable; removed only after the figure acts (p.40/p.118) |
| `is_knocked_out` | 3 Stun markers — removed from play, but **not** a casualty (p.121: no injury roll) |
| `is_dead` | off the table |
| `is_activated` | acts once per round, reset each round |
| `react_slot` | 0 none / 1 QUICK / 2 SLOW / 3 ENEMY |
| `luck_remaining` | p.46 Luck, per battle only ("regained automatically after each battle") |
| `killed_by` | crew figure credited, feeds the p.123 XP keys |
| `health` | internal liveness flag only. Never shown. |

`HitResolutionSheet` resolves a Hit through `BattleCalculations.resolve_hit_outcome()`.
`_mark_casualty()` remains the single idempotent casualty chokepoint, and it feeds
End-Phase Morale and `_sync_objective_enemy_count()`.

## Results

`BattleResultsInputForm` (the Record Result drawer) is the live result producer for a
played battle at every tier, seeded by `_build_results_prefill()` from the live
table state. `_resolve_battle()` still exists and produces the same contract, but is
reachable only from `battle_ended`, which nothing emits — see the note in the Phase 7
section of the battle-UX sprint log before wiring or deleting it.

## Persistence

`FPCM_BattleCheckpoint` writes the fight to
`campaign.progress_data["active_battle"]` via `GameState.set_active_battle()`.
Requested from `_refresh_unit_rails()` (the chokepoint every per-figure mutation
already funnels through) and the phase handler, debounced to one write per frame.
`CampaignTurnController._resume_battle_if_checkpointed()` runs before any generator,
so a relaunch does not re-roll the encounter.

## Verification

`tests/tools/verify_battle_ui.gd` — 134 live-state rows. It asserts on component
state after driving the real entry points; asserting on a label or a return value is
what let this family of defects hide in the first place.
