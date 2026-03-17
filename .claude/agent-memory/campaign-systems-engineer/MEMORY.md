# Campaign Systems Engineer — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Link to separate topic files for detailed notes. -->

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

## Phase 29 QA Runtime Findings (Mar 16, 2026)

Full 2-turn demo playthrough completed. Campaign creation through Turn End works end-to-end with zero crashes.

### Campaign Creation Bugs Found (All Fixed in Phase 30-31)

- **BUG-029 (FIXED)**: Victory Condition cards — mouse_filter blocked gui_input
- **BUG-030 (FIXED)**: CharacterCreator default OptionButton (index 0) doesn't fire `item_selected` — added explicit handler calls
- **BUG-032 (FIXED)**: `get_campaign_config_data()` crash on partial dict — `.get()` defaults + `.merge()`
