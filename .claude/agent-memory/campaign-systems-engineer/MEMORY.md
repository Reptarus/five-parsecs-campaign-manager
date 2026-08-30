# Campaign Systems Engineer — Agent Memory

<!-- Loaded into your system prompt. KEEP UNDER 200 LINES. -->
<!-- Durable rules only. Dated session logs were archived 2026-08-06 to -->
<!-- docs/archive/agent-memory-logs/campaign-systems-engineer-MEMORY-2026-08-06.md -->

## ABSOLUTE RULE

The Core Rules and Compendium PDFs at `docs/rules/` are canonical for ALL game mechanics. If code
disagrees with the book, the code is wrong. Extraction commands and the source-authority hierarchy
live in `CLAUDE.md` — don't duplicate them here.

---

## Critical Gotchas — Must Remember

1. **`FiveParsecsCampaignCore` is a Resource.** `campaign["key"] = val` **silently fails**. Use
   `progress_data["key"]` for runtime state, and `"key" in campaign` rather than `.has("key")`.
2. **`GameStateManager` dual-sync**: every setter that modifies campaign state MUST also write to
   `progress_data`. Canonical order: update campaign property → sync to `progress_data` → emit signal.
3. **Godot 4.6 type inference**: `var x := dict["key"]` will NOT compile. Always
   `var x: Type = dict["key"]`. Zero exceptions.
4. **Godot's JSON parser returns every number as FLOAT**, so `value is int` is ALWAYS false on loaded
   data. `StoryEvent.load_from_json()` had `next_clock_ticks = clock_val if clock_val is int else 0`,
   which silently zeroed the next-clock for all seven Story Events. Use `int(value)` with an explicit
   `== null` guard — never an `is int` test — on anything from `JSON.parse`.
5. **2-arg `Dictionary.get(key, default)` silently ABORTS on a Resource.** `Object.get()` takes ONE
   arg, so the 2-arg form is an invalid call that unwinds the function (the app survives; the feature
   silently does nothing). A FRESH campaign held Character **Resources** in `crew_data["members"]`,
   so `CrewTaskComponent` aborted → empty crew list → World Phase Step 2 soft-lock. NEW-CAMPAIGN-ONLY
   (loaded saves are dicts). **Crew members are canonically Dictionaries** — normalize at the boundary
   via `to_dictionary()`. `CampaignFinalizationService._transform_crew_data_for_turn_system()` does this.
6. **`user://options.cfg` is owned by the `SettingsManager` autoload, NOT GameState.**
   `GameState.game_options` / `load_options` / `save_options` / `default_options` / `OPTIONS_PATH` are
   deleted. `GameState.auto_save()` reads `/root/SettingsManager.is_auto_save_enabled()` with a
   null-guard. Sectioned format `[audio]/[display]/[gameplay]/[mobile]` — never write a flat
   `[options]` section, the migrator folds it away on next boot. `user://settings.cfg` (campaign meta)
   IS still GameState-owned.
7. **Forward the full dict at boundaries; never hand-list keys.** `update_captain_state()` hand-copied
   stats and omitted `luck`, so every captain reviewed with Luck 0. Forward
   `to_dictionary()` / `get_panel_data()` wholesale.
8. **A dead-code sweep can remove the seam instead of the corpse.** `c8fd7e07c` deleted
   `is_story_event_turn()` / `get_story_turn_mods()` / `get_story_battle_config()` as "redundant
   zero-caller methods". They were zero-caller only because their one consumer, `phases/BattlePhase.gd`,
   had been deleted six weeks earlier. **Before deleting a zero-caller provider, ask what used to call
   it** — a missing consumer and genuine dead code look identical. Dead consumers are dangerous; dead
   providers are usually a missing wire.
9. **A fix ordered against SOME callers is not a fix.** `initialize_job_offers()` has THREE callers
   (`_fetch_campaign_data()`; `_show_current_step() -> _refresh_job_offers()` at :1177;
   `initialize_world_phase()` at :961). T9-50 was "fixed" twice by ordering the restore against the
   first two — both passed every desk gate and **failed on hardware**. `grep` the callee and COUNT the
   sites before choosing where to insert, or make the fix order-independent by guarding the callee.

---

## ⚠ WorldPhaseController is REUSED between turns — `_ready()` is not the whole init

`CampaignTurnController` **shows** `WorldPhaseController` each turn rather than re-instantiating it
(its own comment, `WorldPhaseController.gd:900-902`). So `_ready()` fires **once per app session** and
`initialize_world_phase()` — the orchestrator entry point — runs AFTER it, re-running
`_initialize_components_with_data()` unconditionally (:961). That clears `job_accepted`
(`JobOfferComponent.gd:200`) and re-inits MissionPrep with `world_phase_data.get("mission", {})`, a key
that does not exist because the mission lives in `job_offer_component.get_accepted_job()`. Its
`if not has_checkpoint()` guard then skips `_show_current_step()`, so nothing re-renders and the
resumed briefing stays blank.

**When a screen is reused rather than re-created, find the orchestrator entry point and read it BEFORE
reasoning about ordering at all.**

Related traps in the same area:

- `save_checkpoint()` builds `_checkpoint_data` from a **fixed key literal** — a key it does not name
  is simply not in the checkpoint. Use the component's own `get_step_results()` /
  `restore_step_results()` pair rather than re-listing fields.
- `has_checkpoint()` **ERASES `_checkpoint_data`** as a side effect when `turn_number` differs from
  `_current_campaign_turn()`. A hardcoded fixture turn silently empties it and the test fails WITH the
  fix in — derive the turn at runtime.
- The checkpoint stamps `turns_played` (a **completed** count) while the UI shows `turns_played + 1`.
  Two different numbers both called "turn"; diffing a checkpoint against a screenshot is off by one.
- A `_refresh_*()` called from a step-entry hook runs on **BACK**-navigation too. `_refresh_rumors()`
  already guards on "already resolved"; `_refresh_job_offers()` did not, so accept → forward → Back
  silently re-rolled the acceptance away. **When one sibling refresher guards and another doesn't, the
  unguarded one is the bug.**

**Cheap disproof for any such diagnosis:** pick a state where the suspected cause CANNOT fire (here,
MISSION_PREP, where `_refresh_job_offers()` is unreachable) and see whether the symptom survives.

---

## Creation invariants (read before editing the wizard)

The creation tables were byte-correct against the book; the **wiring** was where it broke.

- **One grant site per rule.** Credits (p.28) = the `EquipmentPanel` total, consumed by
  `CampaignFinalizationService.compute_starting_credits()` — never added to. Motivation / background /
  class dice + WEALTH's 1D6 + FAME's +1SP are rolled ONCE into `Character.creation_bonuses`. Story
  points (p.66) = `roll_starting_story_points()` (`1D6+1`); difficulty modifiers stay in
  `DifficultyModifiers`. Per-character equipment is distributed by finalization only.
- **Shapes that destroy data.** `member["equipment"]` is `Array[String]` (from `to_dictionary()`);
  appending an item Dictionary is rejected and the item is LOST. Store names, or `.assign()`. One
  item, one home — stash XOR character sheet. `origin` / `motivation` / `background` /
  `character_class` are validated STRING properties with setters that silently default when handed an
  int **from a detached Resource** — convert enum ints at the caller (Node context) via
  `GlobalEnums.to_string_value()`. `origin_bonuses` JSON keys are `GlobalEnums.Origin` ordinals
  (append to that enum, never insert).
- **Two navigation gates, in series.** `Coordinator.can_advance_to_next_phase()` reads
  `phase_completion_status` (must be written in BOTH directions or completion is monotonic);
  `StateManager.advance_to_next_phase()` reads only `_validate_phase_with_warnings()` — the strict
  `_validate_*_phase()` functions are NOT on that path, so a check added there alone blocks nothing.
- **Do NOT wire `get_validation_summary()["has_critical_errors"]`** to `_validate_final_phase()`. It
  is hard-coded false on purpose: the strict crew check compares members against the TOTAL crew size
  while the panel excludes the captain, so it reports legal campaigns as short by one. Both consumers
  append to lists that BLOCK creation.
- **Crew size SSOT** = `campaign_config.campaign_crew_size`, consumed by `CrewPanel` via
  `apply_campaign_crew_size()`. `get_crew_size()` is the fluctuating roster count —
  `get_campaign_crew_size()` is the fixed 4/5/6 setting. Never substitute one for the other.
- Victory conditions are **single-select and optional** (p.64); Easy allows exactly
  `turns_20` / `battles_20`.

---

## Cross-Mode Character Transfer — campaign-domain touchpoints

Canonical-hub design in `src/core/character/CharacterTransferService.gd` (owned by
character-data-engineer). Direct file-drop at `user://transfers/<id>.json` (v2 envelope), NOT a
persistent barracks. You own:

- `GameState.load_campaign()` emits `pending_character_transfers(count)` on a 5PFH load.
- **Mode-generic pickup** in `src/ui/screens/campaign/CampaignScreenBase.gd`:
  `_check_pending_transfers` / `_apply_pending_transfers` / `_add_character_to_mode` /
  `_on_transfers_applied` virtual hook / `_campaign_mode`. Every dashboard calls
  `_check_pending_transfers.call_deferred()` in `_setup_screen` and overrides `_on_transfers_applied()`.
  Dispatch: `add_crew_member` (5PFH) · `add_main_character` (BH) · `add_roster_character` (PF) ·
  `add_veteran_character` (Tactics).
- **`FiveParsecsCampaignCore.add_crew_member(member_dict)` is the 5PFH crew-addition chokepoint** —
  appends to `crew_data["members"]`, forces `is_captain=false`, rebuilds `_crew_id_index`. Use it for
  ANY crew added after creation; never append directly.
- `apply_transfer_rewards(campaign, transfer_data)` applies rewards and DELETES the file (prevents
  double-import). Rewards attach only when `target_mode == "five_parsecs"`.
- 24/24 gdUnit4 transfer tests. Full procedure: `docs/sop/cross-mode-transfer.md`.

## Narrative bridge (auto-resolved battles)

`CampaignTurnController._on_battle_completed` routes auto-resolved battles through `NarrativeScreen`
BEFORE `POST_MISSION`. Gate: `results.get("auto_resolved", false) and _narrative_events_enabled()`.
Played-out tactical battles skip the bridge. The producer dict in `_battle_result_to_narrative_dict`
MUST use consumer-side keys — **`briefing_text` (not `briefing`), `held_field` (not `held_the_field`)**.
When defaulting a missing key, default to the SAFEST value (false), not the convenient one. The helper
is `static` so tests can call it without instantiating the Control. Pinned by
`tests/unit/test_b2_narrative_bridge.gd` (8 bug-pin tests) — KEEP GREEN.

## Story Track drive shaft

`PostBattlePhase._advance_narrative_progression()` is the ONLY caller of
`advance_clock_end_of_turn()` / `apply_post_battle()` / `intro_campaign.advance_turn()`. Delete it and
the Story Clock stops ticking and the Introductory Campaign freezes on turn 0 — silently, no error.
That is exactly what happened between Apr 8 and Aug 1. Pinned by `tests/tools/verify_story_track.gd`.

## Dead files hold live rules hostage

`phases/TravelPhase.gd` and `phases/WorldPhase.gd` have ZERO instantiations (travel really happens in
`UpkeepPhaseComponent`, the World Phase upkeep step). Between them they held the ONLY callers of
`record_invaded_planet()`, `repair_hull()` and the `fuel_credits` consumer — so the p.126 Galactic War
table had never rolled, the p.59 free repair never happened, and p.79 fuel was unspendable. All three
now live in the upkeep step. **A rule "fixed" inside a dead file is not fixed.**
