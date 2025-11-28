# Galactic War System - Integration Documentation

**Version**: 1.0  
**Status**: Ready for Integration  
**Created**: 2025-11-27

## Overview

The Galactic War system tracks multiple concurrent faction conflicts that dynamically affect campaign gameplay. War tracks progress through dice rolls and player actions, creating an evolving strategic environment.

## System Components

### 1. Data Layer

**File**: `data/galactic_war/war_progress_tracks.json`

Defines 4 war tracks:
- **Unity Expansion** - K'Erin Unity military expansion (20 progress levels)
- **Corporate War** - Megacorporation territorial conflict (20 levels)
- **Alien Incursion** - Converted (cybernetic zealots) invasion (20 levels)
- **Pirate Uprising** - Pirate coalition formation (15 levels)

Each track contains:
- Progress thresholds with effects
- Narrative descriptions
- Game mechanic modifiers (travel costs, encounter rates, equipment prices)
- Campaign ending conditions

### 2. Backend System

**File**: `src/core/campaign/GalacticWarManager.gd`

**Key Features**:
- Singleton autoload manager
- Dice-based progression (D6 roll of 5+ advances track each turn)
- Threshold detection and effect application
- Player influence methods (mission success/failure affects progress)
- Save/load support

**Signals**:
```gdscript
signal war_track_advanced(track_id: String, new_value: int, old_value: int)
signal war_threshold_reached(track_id: String, threshold: int, event_data: Dictionary)
signal war_effect_triggered(track_id: String, effect_id: String, description: String)
signal war_track_activated(track_id: String)
signal campaign_ending_triggered(track_id: String, ending_type: String)
```

**Public API**:
```gdscript
# Turn processing
process_turn_war_progression() -> Array[Dictionary]

# Manual manipulation
advance_war_track(track_id: String, amount: int = 1) -> Array[Dictionary]
reduce_war_track(track_id: String, amount: int = 1) -> void

# Player influence
player_mission_success(track_id: String, mission_type: String = "defense") -> void
player_mission_failure(track_id: String) -> void
player_sabotage_success(track_id: String) -> void

# Queries
get_war_track(track_id: String) -> Dictionary
get_active_war_tracks() -> Array[Dictionary]
has_effect(effect_id: String) -> bool
get_effect_modifier(effect_id: String, default_value: float = 0.0) -> float
```

### 3. UI Component

**File**: `src/ui/components/campaign/GalacticWarProgressPanel.gd`

**Design Specifications**:
- Mobile-first (360px base width)
- 48dp minimum touch targets (fully compliant)
- 8px grid spacing system
- Deep space color theme
- Progressive disclosure (expand/collapse per track)

**Layout**:
```
┌─────────────────────────────────────────────┐
│ Galactic War Status                    [?]  │ ← 18pt header
├─────────────────────────────────────────────┤
│                                             │
│ Unity Expansion               [8/20]        │ ← Track name
│ ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░                │ ← 8px progress bar
│ Next: Trade Route Occupation (10)          │ ← Next threshold
│                                             │
│ ┌─────────────────────────────────────┐    │
│ │ ⚠️ Border Skirmishes                │    │ ← Active effects
│ │ Unity patrols increase in border   │    │   (warning style)
│ │ systems                             │    │
│ └─────────────────────────────────────┘    │
│                                             │
└─────────────────────────────────────────────┘
```

**Usage**:
```gdscript
var war_panel = GalacticWarProgressPanel.new()
war_panel.refresh_display()  # Updates from GalacticWarManager
```

## Integration Steps

### Step 1: Add Autoload (project.godot)

```ini
[autoload]

GalacticWarManager="*res://src/core/campaign/GalacticWarManager.gd"
```

**Priority**: Add after GameState, before UI initialization

### Step 2: Campaign Turn Integration

**File**: `src/ui/screens/campaign/CampaignTurnController.gd`

Add to `_process_campaign_turn()`:

```gdscript
func _process_campaign_turn() -> void:
	# Existing turn logic...
	
	# Process galactic war progression
	var war_manager = get_node_or_null("/root/GalacticWarManager")
	if war_manager:
		var war_events = war_manager.process_turn_war_progression()
		
		# Display war events to player
		for event in war_events:
			if event.type == "war_threshold":
				_show_war_event_notification(event)
			elif event.type == "war_track_activated":
				_show_new_war_notification(event)
	
	# Continue with existing logic...
```

### Step 3: Add to Campaign Dashboard

**File**: `src/ui/screens/campaign/CampaignDashboard.tscn` or `.gd`

Add GalacticWarProgressPanel to dashboard layout:

```gdscript
# In _ready() or _setup_ui()
var war_panel = GalacticWarProgressPanel.new()
war_panel.custom_minimum_size = Vector2(0, 200)
war_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
$VBoxContainer.add_child(war_panel)  # Adjust path to your layout
war_panel.refresh_display()
```

**Recommended Position**: Between Victory Progress and World Info panels

### Step 4: Mission Integration

**File**: Mission generation/resolution scripts

Add war track checks for mission modifiers:

```gdscript
# In mission generation
func _apply_war_modifiers() -> void:
	var war_manager = get_node_or_null("/root/GalacticWarManager")
	if not war_manager:
		return
	
	# Check for travel cost modifiers
	if war_manager.has_effect("travel_cost_modifier"):
		var modifier = war_manager.get_effect_modifier("travel_cost_modifier", 0.0)
		travel_cost *= (1.0 + modifier)
	
	# Check for encounter rate modifiers
	if war_manager.has_effect("encounter_rate_modifier"):
		var modifier = war_manager.get_effect_modifier("encounter_rate_modifier", 0.0)
		encounter_chance += modifier
	
	# Check for equipment price modifiers
	if war_manager.has_effect("equipment_price_modifier"):
		var modifier = war_manager.get_effect_modifier("equipment_price_modifier", 1.0)
		equipment_prices *= modifier
```

### Step 5: Save/Load Integration

**File**: `src/core/state/GameState.gd` or save system

Add to save data:

```gdscript
func get_save_data() -> Dictionary:
	var data = {
		# ... existing save data
	}
	
	var war_manager = get_node_or_null("/root/GalacticWarManager")
	if war_manager:
		data["galactic_war"] = war_manager.get_save_data()
	
	return data

func load_save_data(data: Dictionary) -> void:
	# ... existing load logic
	
	if "galactic_war" in data:
		var war_manager = get_node_or_null("/root/GalacticWarManager")
		if war_manager:
			war_manager.load_save_data(data.galactic_war)
```

## Effect Reference

### Common Effect IDs

| Effect ID | Type | Description |
|-----------|------|-------------|
| `increased_patrols` | Boolean | More enemy encounters |
| `travel_cost_modifier` | Float | Multiplier for travel costs (0.2 = +20%) |
| `encounter_rate_modifier` | Float | Additive encounter chance (0.15 = +15%) |
| `equipment_price_modifier` | Float | Equipment price multiplier (1.3 = 30% more expensive) |
| `combat_deployment_chance` | Float | Chance of forced combat missions |
| `black_market_activity` | Boolean | Black market availability increased |
| `refugee_missions_available` | Boolean | Refugee escort missions appear |
| `salvage_opportunities` | Boolean | More battlefield salvage |
| `campaign_ending` | Boolean | Triggers campaign ending |

### Using Effects in Code

```gdscript
var war_manager = get_node_or_null("/root/GalacticWarManager")

# Check boolean effect
if war_manager.has_effect("increased_patrols"):
	enemy_count += 2

# Get numeric modifier
var price_mod = war_manager.get_effect_modifier("equipment_price_modifier", 1.0)
item_cost = base_cost * price_mod

# Get travel cost increase
var travel_mod = war_manager.get_effect_modifier("travel_cost_modifier", 0.0)
travel_cost = base_travel_cost * (1.0 + travel_mod)
```

## Player Influence Example

```gdscript
# After mission completion
func _on_mission_completed(mission_type: String, success: bool) -> void:
	if mission_type == "defense_against_unity":
		var war_manager = get_node_or_null("/root/GalacticWarManager")
		if war_manager:
			if success:
				war_manager.player_mission_success("unity_expansion")
				# Unity expansion slows down
			else:
				war_manager.player_mission_failure("unity_expansion")
				# Unity expansion accelerates
```

## Testing Checklist

### Unit Tests
- [ ] War track advancement (normal progression)
- [ ] Threshold detection and effect application
- [ ] Player influence (success/failure)
- [ ] Save/load preservation
- [ ] Multiple tracks progressing simultaneously

### Integration Tests
- [ ] Turn processing calls war manager
- [ ] Effects modify mission parameters correctly
- [ ] UI updates on war progression
- [ ] Campaign endings trigger properly

### UI Tests
- [ ] Panel displays correctly on mobile (360px)
- [ ] Touch targets meet 48dp minimum
- [ ] Progress bars render properly
- [ ] Effects display with correct styling
- [ ] Help button functional

## Performance Considerations

- War progression happens **once per turn** (low frequency)
- UI refresh only on war events (signal-driven)
- JSON loaded once at initialization
- Save data footprint: ~2-5KB per campaign

## Future Enhancements

### Phase 2 (Post-Beta)
- [ ] Player-triggered war track events
- [ ] Custom war tracks from mods
- [ ] Detailed war event log/history
- [ ] War-specific missions and rewards
- [ ] Victory conditions tied to war outcomes

### UI Improvements
- [ ] Animated progress bar transitions
- [ ] War event notification popups
- [ ] Detailed threshold timeline view
- [ ] War statistics/analytics screen

## FAQ

**Q: When should I call `process_turn_war_progression()`?**  
A: Once per campaign turn, after all other turn processing but before displaying turn summary to player.

**Q: Can players prevent campaign endings?**  
A: Yes - by successfully completing defense missions, players can reduce war track progress and delay/prevent endings.

**Q: How many war tracks should be active?**  
A: Recommended 2 active tracks at campaign start. More tracks = more chaos (intentional design).

**Q: Do effects stack across tracks?**  
A: Yes - if both Unity Expansion and Corporate War increase travel costs, both modifiers apply.

**Q: Can I modify war track data at runtime?**  
A: Yes - use `war_manager.advance_war_track()` or `reduce_war_track()` for dynamic events.

## Files Created

### Data Files
- `data/galactic_war/war_progress_tracks.json` (314 lines)
- `data/loot/battlefield_finds.json` (75 lines)
- `data/campaign_tables/unique_individuals.json` (312 lines)

### Code Files
- `src/core/campaign/GalacticWarManager.gd` (400 lines)
- `src/ui/components/campaign/GalacticWarProgressPanel.gd` (366 lines)

### Documentation
- `docs/features/GALACTIC_WAR_SYSTEM.md` (this file)

### Modified Files (Touch Target Fixes)
- `src/ui/screens/campaign/TradingScreen.gd` (4 buttons: 36→48, 32→48, 32→48, 44→48)
- `src/ui/screens/battle/PreBattleEquipmentUI.gd` (1 button: 40→48)

**Total Touch Target Violations Fixed**: 5

## Contact

For integration questions or issues, refer to:
- System Architecture: `docs/technical/SYSTEM_ARCHITECTURE_DEEP_DIVE.md`
- Testing Guide: `tests/TESTING_GUIDE.md`
- Design System: `src/ui/screens/campaign/panels/BaseCampaignPanel.gd`
