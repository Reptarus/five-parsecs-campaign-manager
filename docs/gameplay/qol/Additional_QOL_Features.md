# Additional QOL Features

**Priority**: P3-P4 | **Effort**: Variable | **Phase**: 3

## Feature List

### 1. Undo/Redo System (P2 - 2 days)
Limited undo stack for sensitive actions (crew deletion, wrong purchases).

```gdscript
# QOLUtilities.gd
func push_undo_state(action_type: String, state_data: Dictionary)
func undo_last_action() -> bool
func redo_action() -> bool
func clear_undo_stack()
```

**Stack**: Last 5-10 actions  
**Scope**: Crew edits, purchases, phase advancement

### 2. Dice Statistics (P3 - 1 day)
Track roll results over campaign, luck analysis, hot/cold streak detection.

```gdscript
func record_dice_roll(result: int, context: String)
func get_dice_statistics() -> Dictionary  # avg, distribution, streaks
func is_on_hot_streak() -> bool
func is_on_cold_streak() -> bool
```

**UI**: Statistics panel showing roll distribution, average results

### 3. Voice Notes (P4 - 2-3 days, Mobile Only)
Quick voice-to-text for battle reports.

```gdscript
func start_voice_recording() -> void
func stop_voice_recording() -> String  # Transcribed text
func attach_voice_note_to_journal(entry_id: String, audio_path: String)
```

**Platform**: Mobile only (uses native speech-to-text)

### 4. Mission Success Calculator (P3 - 1 day)
Risk assessment before accepting jobs.

```gdscript
func calculate_mission_difficulty(mission: Mission, crew: Array[Character]) -> float
func get_historical_success_rate(mission_type: String) -> float
func recommend_mission_acceptance(mission: Mission) -> bool
```

**Display**:
```
Mission: Patrol Sector 7
Difficulty: 4/10
Your Crew Strength: 6/10
Success Probability: 75%
Recommendation: ACCEPT ✓
```

### 5. Share Battle Reports (P4 - 2 days)
Generate formatted battle reports for social media.

```gdscript
func generate_battle_report_image(battle_result: Dictionary) -> Image
func export_to_social_media(platform: String)  # Twitter, Discord-friendly
```

**Output**: Image with crew portrait, enemy faced, outcome, stats

### 6. Bulk Actions (P2 - 1 day)
Batch operations for common tasks.

```gdscript
func bulk_sell_items(items: Array[Variant]) -> int  # Returns credits
func apply_healing_to_crew(healing_amount: int)
func equip_crew_loadout(loadout_id: String)
```

**UI**: Multi-select in inventory, "Apply to All" buttons

### 7. Difficulty Adjustment (P3 - 1 day)
Mid-campaign rebalancing.

```gdscript
func adjust_difficulty(new_level: int, apply_retroactively: bool = false)
func enable_mercy_mode()  # Easier encounters if struggling
func enable_hard_mode()   # Harder encounters if winning easily
```

**Tracking**: Difficulty changes logged in campaign history

### 8. Colorblind Modes (P2 - 1 day)
Multiple palette options, shape+color indicators.

```gdscript
const COLORBLIND_PALETTES = {
    "deuteranopia": {...},  # Red-green
    "protanopia": {...},    # Red-green (different)
    "tritanopia": {...}     # Blue-yellow
}
```

**Integration**: Extends existing AccessibilityManager

### 9. Tutorial Tooltips (P1 - 1 day)
Context-sensitive help on first use.

```gdscript
func show_tutorial(tutorial_id: String, trigger_control: Control)
func mark_tutorial_seen(tutorial_id: String)
func reset_tutorials()  # For replay
```

**Display**: Persistent "?" icons, progressive onboarding

### 10. Auto-Save Improvements (P1 - 1 day)
Never lose progress with checkpoint system.

```gdscript
func auto_save_at_phase_end(phase: GamePhase)
func create_manual_checkpoint(name: String)
func rewind_to_checkpoint(checkpoint_id: String) -> bool
```

**Storage**: Keep last 10 auto-saves, unlimited manual checkpoints

---

## Implementation Priority
1. **Beta**: Undo system, Tutorial tooltips, Auto-save improvements
2. **v1.1**: Dice statistics, Mission calculator, Colorblind modes
3. **v1.2+**: Voice notes, Share reports, Bulk actions, Difficulty adjustment

## File Organization
All utilities in: `src/qol/QOLUtilities.gd` (single file for small features)

---
**Status**: Incremental additions post-launch
