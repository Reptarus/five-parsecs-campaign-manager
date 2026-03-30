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
