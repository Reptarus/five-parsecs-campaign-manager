# Campaign Systems Engineer — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Link to separate topic files for detailed notes. -->

## ABSOLUTE RULE: Core Rules & Compendium Are Word of God

The Core Rules and Compendium PDFs at `docs/rules/` are the canonical authority for ALL game mechanics. If code disagrees with the book, the code is wrong.

---

## Critical Gotchas — Must Remember

1. **FiveParsecsCampaignCore is Resource**: `campaign["key"] = val` **silently fails**. Use `progress_data["key"]` for runtime state. Use `"key" in campaign` instead of `.has("key")`.
2. **GameStateManager dual-sync**: ALL setters that modify campaign state MUST also write to `progress_data`. The canonical pattern: update campaign property → sync to progress_data → emit signal.
3. **Godot 4.6 type inference**: `var x := dict["key"]` will NOT compile. Always use `var x: Type = dict["key"]`. Zero exceptions.

---

## PDF Rulebooks & Python Extraction Tools

Source PDFs for verifying campaign rules — use these instead of guessing values:
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Text extractions**: `docs/rules/core_rulebook.txt` and `docs/rules/compendium_source.txt`
- **Python**: `py` launcher (NOT `python`), PyMuPDF installed. Example: `py -c "import fitz; doc = fitz.open('path'); print(doc[PAGE].get_text())"`

---

## Session 52: Strange Characters + Upkeep Fix (Apr 8, 2026)

### CampaignPhaseManager Turn Rollover Sequence (Updated)

`_process_turn_rollover()` now has 9 steps in order:
1. **`_clear_upkeep_lockouts()`** — Clear previous turn's locked_out_this_turn flags (NEW)
2. `_restore_crew_luck()` — Core Rules p.91
3. `_process_sick_bay_recovery()` — Core Rules p.99
4. `_process_character_event_effects()` — Core Rules pp.128-130
5. `_process_patron_expiration()` — Core Rules pp.81-88
6. Story Points reset + auto-award — Core Rules pp.66-67
7. Planet effects expiry
8. **`_process_unity_agent_favor()`** — Unity Agent 2D6 per turn (Core Rules p.20) (NEW)
9. Victory condition check — Core Rules p.64

### Upkeep Failure System (Session 52)

`UpkeepSystem.handle_upkeep_failure()` was DEFINED but NEVER CALLED. Now wired:
- UpkeepPhaseComponent `_handle_insufficient_funds()` → offers sell dialog → applies lockout
- `locked_out_this_turn` set as Dictionary key (not just Resource meta) for CrewTaskComponent compatibility
- CrewTaskComponent `_get_eligible_crew()` enforces lockout check
- Lockout cleared at turn rollover by `_clear_upkeep_lockouts()`
- Sick Bay crew excluded from upkeep count (both UpkeepSystem and UpkeepPhaseComponent)

### Unity Agent "Call in a Favor" (Session 52)

New methods on CampaignPhaseManager:
- `_process_unity_agent_favor(campaign)` — 2D6 each turn, 10-12 success / 2-4 forced travel
- `resolve_unity_agent_favor(choice)` — PUBLIC API for UI callback
- `mark_unity_agent_trait_lost(member)` — permanent disable

## Session 51: Character Events Turn Rollover (Apr 8, 2026)

Step 3 decrements `status_effects[].duration` for all crew (dual Resource + Dictionary path). Expired effects trigger `_on_character_event_expired()` — handles Business Elsewhere XP return and item recovery D6+Savvy check.

### GameStateManager.get_deployable_crew() (NEW)

Filters out DEAD/RETIRED/DEPARTED/MISSING crew. BattlePhase._get_deployed_crew() calls this (previously the has_method check failed silently and fell through to _generate_default_crew).

---

## Session 47: Equipment Pipeline — Campaign Domain (Apr 8, 2026)

### CampaignPhaseManager PostBattlePhase Rewiring

- Rewired to correct orchestrator: `phases/PostBattlePhase.gd` (not `core/campaign/PostBattlePhase.gd`)
- Constructor changed: `.new()` + `set_campaign()` instead of `.new(game_state)`
- Signal: `post_battle_phase_completed` instead of `phase_completed`
- Entry: `start_post_battle_phase(battle_data)` instead of `process_post_battle()`
- Campaign reference updated in `_connect_to_campaign()`
- 3 deprecated files identified: `src/core/campaign/PostBattlePhase.gd`, `src/game/campaign/FiveParsecsPostBattlePhase.gd`, `src/base/campaign/BasePostBattlePhase.gd`

### PostBattleCompletion — Consumed Items Pipeline

- `process_consumed_items()` added — removes battle-consumed items from character equipment
- `items_consumed_in_battle` signal wired from PostBattlePhase orchestrator

### TravelPhase.gd

- `attempt_forge_license()` method added for Red Zone license forging during travel

---

## Session 43: Story Points Full Integration (Apr 7, 2026)

### CampaignPhaseManager Turn Rollover — Now Routes Through StoryPointSystem

Previously `_process_turn_rollover()` wrote directly to `campaign.story_points` and `campaign.story_point_turn_state` flags. Now creates transient `StoryPointSystem.new(campaign)`, loads state via `from_dict()`, calls `reset_turn_limits()` + `check_turn_earning()`, persists back via `to_dict()`. This ensures:
- Insanity mode check applies (was bypassed before)
- `story_points_earned` signal fires (was silent before)
- Per-turn flags route through system (was direct dict manipulation)

### PostBattlePhase — "A Bitter Day" Battle Earning (Core Rules p.67)

New `_check_bitter_day_story_point()` in `_complete_post_battle_phase()` after manipulator bonus:
- Reads `battle_result.get("held_field", false)` + scans `casualties` for `type == "killed"/"fatal"`
- If both true AND not Insanity: `campaign.story_points += 1`
- Journal entry via `_log_bitter_day_sp()` (follows `_log_manipulator_bonus` pattern)
- `_is_story_points_disabled()` helper checks campaign difficulty == INSANITY
- New signal: `bitter_day_sp_earned`

### Dashboard _sync_sp_system() Pattern

Dashboard's `_sp_system` is created once at `_ready()` and can go stale when CampaignPhaseManager modifies campaign directly. New `_sync_sp_system()` method reloads from `campaign.story_point_turn_state`. Called from:
- `_on_phase_event()` — after turn rollover
- `_on_phase_completed()` — after phase finishes
- `_toggle_sp_popover()` — safety net before showing popover

---

## Session 40b: Legal Stack + Compendium Library + Modiphius Ask List (Apr 7, 2026)

### Legal Stack (14 new files)
- `EULAScreen.gd` + `.tscn` — First-launch blocking EULA acceptance screen (scroll + privacy checkbox + DECLINE/ACCEPT)
- `LegalConsentManager.gd` — Autoload, persists to `user://legal_consent.cfg` (version + timestamp), re-triggers on version change
- `LegalTextViewer.gd` — Reusable Markdown-to-BBCode viewer for EULA/Privacy/Licenses/Credits
- `data/legal/eula.md`, `privacy_policy.md`, `third_party_licenses.md`, `credits.md` — Legal documents
- `docs/legal/gh-pages/` — GitHub Pages versions (privacy.html, eula.html, index.html)
- `docs/legal/STORE_SUBMISSION_CHECKLIST.md` — Pre-filled Data Safety + Nutrition Label answers
- Settings → Legal & Privacy section: document links, analytics toggle, export/delete buttons
- Privacy: default OFF analytics consent (GDPR opt-in), data export (JSON manifest), data deletion (wipes user://)
- **3 `[PENDING MODIPHIUS REVIEW]` markers** in EULA need legal sign-off before release

### Compendium Library System
- 10 categories, 340+ items, game-icons.net icon SOP
- Extensible architecture for Planetfall/Tactics expansions

### Modiphius Partnership Ask List
- `docs/MODIPHIUS_ASK_LIST.md` — 7 legal blockers, 6 publishing blockers, 6 monetization decisions, art assets, multi-IP vision
- Structured as pitch meeting agenda (must-discuss / should-discuss / can-mention tiers)

---

## Session 40: Difficulty Settings Audit (Apr 7, 2026)

### Difficulty Enum Cleanup

- HARD(3)/NIGHTMARE(5)/ELITE(7) are **DEPRECATED** — not in Core Rules or Compendium
- Aliased to NORMAL/INSANITY/INSANITY in `difficulty_modifiers.json` for save compat
- Fabricated JSON keys removed: `enemy_strength_multiplier`, `loot_modifier`, `credit_modifier`, `rival_resistance_modifier`
- Only 5 real modes: Easy, Normal, Challenging, Hardcore, Insanity (Core Rules pp.64-65)

### Progressive Difficulty Wiring (Compendium pp.30-31)

- `ProgressiveDifficultyTracker.gd` + `progressive_difficulty.json` already existed
- NEW: ExpandedConfigPanel has two DLC-gated checkboxes (Option 1 + Option 2, combinable)
- Persisted as `campaign.progress_data["progressive_difficulty_options"]` (Array of ints)
- BattlePhase reads from progress_data instead of hardcoding `ProgressionType.BASIC`
- Old saves default to `[]` (no progressive difficulty)

### Dead Code Deleted (10 files)

ConfigPanel, CampaignSetupScreen, CampaignSetupDialog, DifficultyOption, gameplay_options_menu, QuickStartDialog, CampaignLoadDialog, CampaignSummaryPanel, CampaignCreationManager — all confirmed zero active references.

### Ship Component System (Session 45)

- `ShipComponentQuery.gd` (NEW) — static helper, queries `GameStateManager.get_ship_data()["components"]`
- **Old saves missing `"components"` key** — ShipComponentQuery handles gracefully (returns []), but all component effects silently no-op. New campaigns include it via `ShipPanel._initialize_ship_data()`. Needs migration in `GameState.load_campaign()`.
- `UpkeepSystem.gd` — Suspension Pod must gate on `has_component("suspension_pod")` before using `suspended_crew` list
- `UpkeepPhaseComponent.gd` — UI layer also calculates upkeep independently (dual calculation risk)
- Travel cost formula duplicated in `TravelPhase.gd` AND `ShipManager.gd` — extract to shared helper eventually

### TransitionManager Scene Init Timing (Session 45)

`TransitionManager.fade_to_scene()` instantiates scenes before adding to tree. `_ready()` fires before node is accessible via `/root/` paths. Any scene loaded via SceneRouter that uses `get_node_or_null("/root/...")` in `_ready()` MUST defer: `call_deferred("_initialize")`.

### Elite Rank Cap

- `PlayerProfile.MAX_ELITE_RANKS = 17` — guard in `award_elite_rank()` (Core Rules p.65)

---

## Session 39-39c: Crew Size Scaling Audit (Apr 7, 2026)

Full audit of crew-size-dependent rules from Core Rules PDF (pp.63-64, 70, 92-93, 99, 118) + Compendium (pp.124, 141).

### Key Architectural Change: `campaign_crew_size` vs `get_crew_size()`
- **`get_crew_size()`** = fluctuating roster count (for upkeep, travel costs)
- **`get_campaign_crew_size()`** = fixed 4/5/6 chosen at creation (for enemy dice, deployment, reaction dice)
- New `campaign_crew_size` @export on `FiveParsecsCampaignCore` with full serialization + legacy fallback (default 6)
- Accessor chain: `FiveParsecsCampaignCore.get_campaign_crew_size()` → `GameState` → `GameStateManager`

### Files Modified (Session 39)
- `FiveParsecsCampaignCore.gd` — `campaign_crew_size` property + serialization
- `EnemyGenerator.gd` — Numbers modifier applied (+0/+1/+2/+3), quest reroll (Core Rules p.99), order of operations fix (enemy type FIRST, then dice), `calculate_raided_enemy_count()` (3D6/2D6/1D6 per p.70)
- `BattlePhase.gd` — campaign crew size + fielding-fewer reduction (Core Rules p.93: -1 enemy if deploying 2+ below setting)
- `FiveParsecsCombatSystem.gd` — reaction dice use campaign setting, not living crew count
- `ExpandedConfigPanel.gd` — CREW SIZE card (OptionButton 4/5/6 with descriptions)
- `PreBattleUI.gd` — deployment cap enforcement + "Deploying X / Y max" label
- `CampaignCreationCoordinator.gd` + `CampaignFinalizationService.gd` — wiring
- `BattleSetupWizard.gd` — fabricated formula replaced with EnemyGenerator delegation

### Files Modified (Session 39c — continuation)
- `StealthMissionGenerator.gd` — added `campaign_crew_size` param, sentries = setting + 1 (Compendium p.124)
- `SalvageJobGenerator` caller in `WorldPhase.gd` — changed from `get_crew_size()` to `get_campaign_crew_size()`
- `test_crew_size_enemy_calc.gd` — 13 new tests (Numbers modifier, quest reroll, roster-vs-setting, Raided formula)
- `CLAUDE.md` — Data Ownership table + Gotcha entry

---

## Session 38-39b: Intro Campaign + Story Track — Reconciled & Runtime-Verified (Apr 7, 2026)

Two narrative overlay systems reconciled into sequential pipeline, runtime-tested end-to-end.

- **IntroductoryCampaignManager.gd** (NEW): `src/core/campaign/IntroductoryCampaignManager.gd` — extends Resource, mirrors StoryTrackSystem pattern. Turn restrictions from Compendium pp.105-109. Signals: `intro_turn_started`, `intro_completed`, `intro_phase_unlocked`.
- **CampaignPhaseManager** integration: `_init_intro_campaign()` mirrors `_init_story_track()`. `start_new_turn()` checks intro FIRST — story track only fires if intro NOT active. `_init_story_track()` delays `start_story_track()` when intro active.
- **Sequencing rule**: Intro always runs before Story Track. Story clock FROZEN during intro. On intro completion: +2 SP + story track activates (Compendium p.109).
- **PostBattlePhase**: `_advance_story_track()` returns early if intro active; calls `advance_intro_turn()` instead.
- **Save/load**: `progress_data["intro_campaign_state"]` for intro, `progress_data["story_track"]` for story. Both init methods persist state immediately via `save_*_state()`.
- **Config keys**: `story_track_enabled` (bool, campaign property) + `introductory_campaign` (bool, progress_data).
- **DLC gate**: Uses `dlc.ContentFlag.INTRODUCTORY_CAMPAIGN` (enum, not hardcoded int). Checkbox visibility uses `is_feature_available()` (not `is_feature_enabled()`).
- **CampaignFinalizationService**: Sets `campaign.story_track_enabled` directly (not via GameStateManager — campaign not on GameState yet during creation).
- **World Phase skip**: `_can_advance_to_next_step()` + `_should_skip_intro_step()` auto-complete restricted steps (same pattern as Black Zone).
- **Dashboard**: Queries live `CampaignPhaseManager.get_intro_status()`, falls back to progress_data.
- **Loading screen**: `SceneRouter.navigate_to_with_loading()` wired for campaign creation, continue, load, import transitions.

---

## Session 35: Red & Black Zone Jobs Full Integration (Apr 7, 2026)

Zone selection UI added to World Phase Step 0 (UpkeepPhaseComponent). Key data flow:

- `UpkeepPhaseComponent.get_selected_zone()` → 0=normal, 1=red, 2=black
- `WorldPhaseController._complete_world_phase()` injects `is_red_zone`/`is_black_zone` into mission_dict
- `_refresh_mission_prep()` also injects zone flags so MissionPrepComponent can show zone info cards
- Black Zone auto-skips JOB_OFFERS + RESOLVE_RUMORS steps, waives upkeep
- `red_zone_turns_completed` incremented in `_complete_world_phase()` for both RZ and BZ turns
- License purchase: `RedZoneSystem.purchase_license()` + milestone journal entry
- PostBattle: PaymentProcessor.process_black_zone_rewards(), ExperienceTrainingProcessor BZ +1 XP, GalacticWarProcessor RZ -1 modifier
- CampaignJournal enriched with zone_type tags, threat/time details, BZ reward milestones

---

## Session 34: Strange Characters Wired to Post-Battle + Creation (Apr 6, 2026)

Post-battle subsystems updated for Strange Character rules:

- `PostBattleCompletion.gd` — new `check_traveler_disappearance(ctx)` (2D6: 2=disappear+2SP, 11-12=quest) and `check_manipulator_bonus(ctx)` (1D6 per Manipulator, 6=+1 SP)
- `PostBattleContext.gd` — `is_character_bot_or_soulless()` now also excludes Assault Bot via `species_id` check
- `InjuryProcessor.gd` — Assault Bot routed to bot injury table (added to origin check + species_id fallback)
- `ExperienceTrainingProcessor.gd` — Hopeful Rookie +1 XP when not casualty
- `CharacterCreator.gd` — Strange Characters in dropdown, `_enforce_species_constraints()` locks forced motivation/background/no-tables, creation bonuses adjusted per species

Key pattern: gameplay systems check `species_id` field (String) on crew members. Both Object and Dictionary access paths supported.

---

## Session 33: DLC Save Dependency Tracking (Apr 6, 2026)

- **`required_dlc_packs: Array[String]`** added to FiveParsecsCampaignCore — one-way stamp, serialized at top level, backwards-compat via `.get("required_dlc_packs", [])`
- **Signal-based stamping**: `DLCManager.dlc_pack_required` signal → GameState._on_dlc_pack_required() → campaign.require_dlc_pack(). Loose coupling per Godot best practices
- **`GameState.peek_required_dlc(path)`** — static method, peeks JSON without full load (pattern from `_detect_campaign_type()`)
- **Load-time DLC check**: MainMenu._load_and_go_to_dashboard() now intercepts load, shows DLCRequirementDialog if missing packs
- **Save list badges**: `[DLC]` amber tag shown on saves requiring unowned packs
- **ExpandedConfigPanel**: Two DLC sections replaced with unified `ExpansionFeatureSection` (campaign_creation mode)
- **DLCContentDisclaimer**: One-time warning on first feature enable per pack during campaign creation
- **StoreManager bundle**: `"compendium_bundle"` purchase sets all 3 packs owned

---

## Session 30: Creation Pipeline Refactor (Apr 3, 2026)

- **creation_bonuses single source of truth**: `Character.creation_bonuses` dict holds all rolled creation resources. Set once by `CharacterCreator._roll_and_store_creation_bonuses()`. Coordinator `_generate_crew_extras()` rewritten to aggregate FROM these stored values (no more `CharacterGeneration.roll_character_tables()` random re-rolls).
- **Engine.has_singleton bug fixed**: `Character._get_validated_enum_string()` now uses scene tree access for autoloads.
- **Finalization data loss fixed**: `_aggregate_all_phase_data()` was destroying equipment credits key. `CampaignFinalizationService` now reads bonus_credits/story_points/quest_rumors from crew_data as fallback.
- **Upkeep formula**: All 6 calculators now match Core Rules p.76 (1 credit for 4-6 crew, +1 per member past 6).
- **FinalPanel**: Equipment items listed individually, patron/rival source attribution shown, credits breakdown.

---

## Session 18: TravelPhase Rules Fixes (Mar 30, 2026)

Two Core Rules p.72 bugs fixed in `_process_world_arrival()`:
- **Rival following**: Was `follow_roll <= 3` (50%). Book says "On a 5+, they opt to follow." Now `follow_roll >= 5` (33%).
- **License costs**: Was single roll with fabricated tiers (3-4=10cr, 5-6=20cr). Book says D6 5-6 = license required, then roll further D6 for cost. Now two separate rolls.

Also: 3 Compendium mission generators (Stealth/Street/Salvage) unified onto `Compendium*` canonical data classes. Generators no longer have duplicate const tables.

---

## Phase 31 QA Bug Fix Sprint (Mar 16, 2026)

10 bugs + 3 UX issues fixed across 14 files, 0 compile errors. Key campaign-domain fixes below.

### GameStateManager Dual-Sync Pattern (BUG-031 — FIXED)

**Root cause**: `set_credits()` was the ONLY setter properly syncing to both campaign properties AND `progress_data`. Three other setters were missing the sync:
- `set_supplies()` — missing `progress_data["supplies"]` write
- `set_reputation()` — missing `progress_data["reputation"]` write
- `set_story_progress()` — missing `progress_data["story_progress"]` write

**Additional bypasses fixed**:
- `_on_campaign_loaded()` directly assigned variables instead of using setters — now routed through setters
- `add_story_points()` directly mutated values instead of calling `set_story_progress()` — now uses setter

**Pattern going forward**: ALL GameStateManager setters that modify campaign state MUST also write to `progress_data`. The canonical pattern:
```gdscript
func set_X(value):
    # Update campaign property
    campaign.X = value
    # Sync to progress_data
    campaign.progress_data["X"] = value
    # Emit signal
    X_changed.emit(value)
```

**FiveParsecsCampaignCore change**: Expanded `progress_data` defaults to include `supplies`, `reputation`, `story_progress`, `missions_completed`, `battles_won`, `battles_lost` (were missing, caused null on reload).

### Equipment Restoration (BUG-035 — FIXED)

Equipment restoration code existed in `@tool`-marked `GameSystemManager` but was unreachable at runtime. The active load path in `GameState.load_campaign()` had no equipment restoration.

**Fix**: Added `_restore_equipment_from_campaign()` in `GameState.gd` with deferred call for `_init` timing. Also added `_enrich_crew_equipment()` in `WorldPhaseController.gd` to ensure crew have equipment references before Mission Prep.

### Trading Credits Persistence (BUG-039 — FIXED)

`PurchaseItemsComponent._on_sell_pressed()` added credits locally but never synced to `GameStateManager`. The purchase refund path correctly called `GameStateManager.add_credits()` but the sell path did not. Fixed by adding `GameStateManager.add_credits()` call to sell handler.

### Campaign Creation UX Fixes

- **UX-060/070**: Added `_style_navigation_buttons()` with Deep Space theme in `CampaignCreationUI.gd` — Next/Start Campaign buttons were plain unstyled text
- **UX-074**: `FinalPanel.gd` `_update_crew_preview()` now handles Dictionary crew members (not just Character objects) for Final Review display
- **CaptainPanel.gd**: Typed `current_captain: Character` to prevent BaseCharacterResource type mismatch crash (BUG-036)
- **CrewPanel.gd**: Typed `crew_members: Array[Character]` to prevent same latent type issue

### Save File Location

Saves go to `user://campaigns/` (NOT `user://saves/`). Format is `.fpcs` JSON with `.backup` copy.

### Story/Travel Phase Auto-Skip

New campaigns jump directly to World Phase (Upkeep) — Story and Travel phases auto-complete. `StoryPhasePanel` warns "EventManager not found" and uses fallback generation.

## Session 11-12: BattlePhase Payment Fix (Mar 26, 2026)

BattlePhase.gd had fabricated payment formula (`base_payment=100 + difficulty*25 + success_bonus=50`) in both tactical and auto-resolve paths. `battle_setup_data` rebuilt at line 323 without `base_payment` key, so fallback always triggered → 150-200 credits per battle. Fixed: `combat_results["payment"]` and `["credits_earned"]` now 0. Real payment handled by PostBattlePaymentProcessor (1D6 credits, Core Rules p.120). PostBattleSummarySheet will show 0 for credits — real payment goes through `payment_received` signal. Future UI pass could wire summary to show actual PostBattle payment.

## Session 13: Post-Battle XP JSON Wiring (Mar 26, 2026)

ExperienceTrainingProcessor._calculate_crew_xp() now loads XP values from `data/injury_results.json` instead of hardcoded 1/2/3/1/1. Static lazy loader with fallback defaults. Same JSON also wired into PostBattleProcessor (XP awards + data-driven injury tables) and BattleCalculations (derived XP constants). All values verified against Core Rules p.123.

---

## Mar 20-21 Runtime Verification

### PostBattlePhase Decomposition — Runtime Verified

Phase 33 Sprint 8 decomposed PostBattlePhase (4,240 lines to 296-line orchestrator + 10 subsystems in `src/core/campaign/phases/post_battle/`). Runtime verification results:

- **19/19 signals verified** — 0 dead signals, 100% emission isolation in orchestrator
- Event bus auto-cleanup working: clean subscribe/unsubscribe cycles each turn
- All 10 subsystems (`InjuryProcessor`, `LootDistributor`, `GalacticWarTracker`, etc.) function correctly

### WorldPhaseComponent Inheritance — Runtime Verified

Phase 33 Sprint 9 refactored 9 world phase components to extend `WorldPhaseComponent` base class with auto-cleanup event bus pattern.

- **9/9 components extend correctly** after fixes
- **Fix required**: `UpkeepPhaseComponent.gd` and `CrewTaskComponent.gd` had duplicate `_help_dialog` var and `_show_help_dialog()` method — collided with base class. Removed duplicates
- **Fix required**: `WorldPhaseComponent.gd` needed `TOUCH_TARGET_MIN := 48` constant added so child components (e.g., JobOfferComponent) could inherit it

### Upkeep Formula — Confirmed Correct

Upkeep auto-calculation verified through 5-turn playthrough. Counters consistent: turns=5, missions=5, battles_won=4, battles_lost=1, credits=1,575.

### Equipment Save/Reload — 9-Stage Chain Verified E2E

Full equipment persistence pipeline confirmed working: creation -> assignment -> save -> reload -> Mission Prep display -> battle -> post-battle -> next turn -> save again.

---

## Phase 29 QA Runtime Findings (Mar 16, 2026)

Full 2-turn demo playthrough completed. Campaign creation through Turn End works end-to-end with zero crashes.

### Campaign Creation Bugs Found (All Fixed in Phase 30-31)

- **BUG-029 (FIXED)**: Victory Condition cards — mouse_filter blocked gui_input
- **BUG-030 (FIXED)**: CharacterCreator default OptionButton (index 0) doesn't fire `item_selected` — added explicit handler calls
- **BUG-032 (FIXED)**: `get_campaign_config_data()` crash on partial dict — `.get()` defaults + `.merge()`

### Session 36: Story Track Integration (Apr 7, 2026)

- StoryTrackSystem cached on CampaignPhaseManager (not re-instantiated per call)
- 5 signals wired: story_track_started/event_triggered/clock_advanced/evidence_discovered/completed
- Story state persisted in `campaign.progress_data["story_track"]`
- Clock: Won=−1, Not-won=D6(1:0,2-5:1,6:2). Events loaded from 7 JSONs
- CampaignJournal best practices: ~30 dot-access → .get(), ~15 untyped → typed

### Session 37: UX Enhancement Sprint (Apr 7, 2026)

Dashboard-relevant changes from UX enhancement sprint (Fallout companion app patterns):
- `CampaignDashboard.gd` — 6 empty state Labels replaced with `EmptyStateWidget` (themed icon + flavor text + optional action)
- `TransitionManager.gd` — New `fade_to_scene_with_loading()` method with itemized `LoadingScreen` (CanvasLayer L99)
- `PersistentResourceBar` — CanvasLayer L80 overlay showing Credits/StoryPts/Patrons/Rivals during phase screens. Call `show_bar()`/`hide_bar()` from phase panels
- `CrewTaskEventDialog.gd` — Card draw/discard animations (slide from left, drop+fade dismiss)
- 14 new reusable widgets in `src/ui/components/common/` — see CLAUDE.md widget library table
