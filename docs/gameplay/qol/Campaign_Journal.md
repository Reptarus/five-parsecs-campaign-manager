# Campaign Journal - Narrative Tracking System

**Priority**: P0 - Critical  
**Effort**: 3-4 days  
**Phase**: 1 - Core UX  
**Status**: Ready to Implement

## 📖 Overview

The Campaign Journal transforms your Five Parsecs campaign into a living story. Automatically track major events, manually add personal notes, and visualize your crew's journey through an interactive timeline.

**Core Value**: Never forget your campaign's narrative arc. Remember fallen heroes, epic victories, and crushing defeats.

## 🎯 User Stories

### Story Preservation
> "As a **player**, I want to **record memorable moments** so that **I can remember my campaign's story years later**."

**Example**: After an intense battle where a crew member sacrificed themselves:
```
[Turn 15 - Day 45]
📸 Photo: Battle at Rusty Ruins
Battle Result: Victory (Pyrrhic)

Kira "Deadeye" Chen fell protecting the escape route.
Her last shot took down the enemy captain.

Legacy: +1 Story Point earned
         Crew morale penalty (2 turns)
         
Tags: #memorable #sacrifice #KiraChen
```

### Campaign Timeline
> "As a **veteran player**, I want to **see my campaign timeline** so that **I can track story progression and major milestones**."

**Example**: Timeline view shows:
```
Turn 1   ──────●  Campaign Start
           |      Captain created: "Iron" Jack Morrison
Turn 5   ──────●  First Battle Victory
Turn 10  ──────●  Rival Established: Red Hand Gang
Turn 15  ──────●  ⚠️ Crew Member Died: Kira Chen
Turn 18  ──────●  🏆 Story Track Milestone Reached
Turn 22  ──────●  💰 Major Purchase: Plasma Rifle
```

### Character Histories
> "As a **narrative player**, I want **individual character journals** so that **each crew member has a unique story**."

**Example**: Viewing Kira Chen's history:
```
KIRA "DEADEYE" CHEN
━━━━━━━━━━━━━━━━━
Joined: Turn 1 (Campaign Start)
Battles: 12
Kills: 23
Injuries: 3
Advancements: 2 (+1 Combat Skill, Crack Shot trait)

Key Moments:
• Turn 7: First kill (Converted Pirate)
• Turn 11: Critical injury (recovered after 3 turns)
• Turn 13: Earned Crack Shot trait
• Turn 15: KIA - Battle at Rusty Ruins 💀
```

## 🏗️ Technical Architecture

### System Components

```
CampaignJournal.gd (Autoload Singleton)
├── Entry Management
│   ├── Create entry (auto/manual)
│   ├── Edit/delete entries
│   ├── Tag system
│   └── Photo attachments
├── Timeline Generator
│   ├── Turn-based sorting
│   ├── Filter by type
│   ├── Milestone detection
│   └── Visualization data
├── Character History Tracker
│   ├── Per-character timelines
│   ├── Battle participation
│   ├── Injury tracking
│   └── Achievement milestones
└── Export System
    ├── PDF generation
    ├── Markdown export
    ├── JSON backup
    └── Photo compilation
```

### Integration Points

| Existing System | Integration Method |
|----------------|-------------------|
| `GameState.gd` | Hook turn advancement, save/load |
| `BattleResultsManager.gd` | Auto-generate battle entries |
| `PostBattlePhase.gd` | Capture post-battle narrative |
| `CharacterStats.gd` | Track character milestones |
| `StoryTrackSystem.gd` | Story point earned events |

## 💾 Data Structure

### Journal Entry Format

```gdscript
# Entry schema
{
    "id": "entry_12345",
    "turn_number": 15,
    "timestamp": 1700000000,
    "type": "battle",  # battle, story, purchase, injury, milestone, custom
    "auto_generated": true,
    
    # Content
    "title": "Battle at Rusty Ruins",
    "description": "Kira Chen fell protecting the crew...",
    "mood": "somber",  # triumph, defeat, neutral, somber, exciting
    
    # Metadata
    "tags": ["memorable", "sacrifice", "KiraChen"],
    "characters_involved": ["kira_chen", "jack_morrison"],
    "location": "Rusty Ruins - Fringe World Delta-7",
    
    # Media
    "photos": [
        {
            "path": "user://campaign_photos/turn15_battle.png",
            "caption": "Final stand at the ruins"
        }
    ],
    
    # Stats
    "stats": {
        "battle_result": "victory",
        "casualties": 1,
        "loot_earned": 350,
        "xp_gained": 4
    },
    
    # Player notes
    "player_notes": "This was the most intense battle yet..."
}
```

### Timeline Data Format

```gdscript
# Timeline structure
{
    "campaign_id": "campaign_12345",
    "created_at": 1700000000,
    "last_updated": 1700000500,
    
    "entries": [
        # Array of entry objects (sorted by turn_number)
    ],
    
    "milestones": [
        {
            "turn": 10,
            "type": "rival_established",
            "title": "Rival: Red Hand Gang",
            "icon": "skull"
        },
        {
            "turn": 18,
            "type": "story_track",
            "title": "Story Milestone Reached",
            "icon": "star"
        }
    ],
    
    "characters": {
        "kira_chen": {
            "name": "Kira 'Deadeye' Chen",
            "status": "deceased",
            "entries": [3, 7, 11, 13, 15]  # Entry IDs
        }
    },
    
    "statistics": {
        "total_entries": 42,
        "auto_generated": 35,
        "manual_entries": 7,
        "photos_attached": 12,
        "battles_recorded": 15
    }
}
```

### Character History Format

```gdscript
# Per-character tracking
{
    "character_id": "kira_chen",
    "name": "Kira 'Deadeye' Chen",
    
    "timeline": [
        {
            "turn": 1,
            "event": "joined_crew",
            "details": "Campaign start - original crew"
        },
        {
            "turn": 7,
            "event": "first_kill",
            "details": "Converted Pirate - Battle at Trade Station"
        },
        {
            "turn": 11,
            "event": "injury",
            "details": "Leg Wound - recovered turn 14"
        },
        {
            "turn": 13,
            "event": "advancement",
            "details": "Earned Crack Shot trait"
        },
        {
            "turn": 15,
            "event": "death",
            "details": "KIA - Battle at Rusty Ruins",
            "legacy": "Heroic sacrifice earned +1 Story Point"
        }
    ],
    
    "statistics": {
        "battles_participated": 12,
        "kills": 23,
        "injuries_sustained": 3,
        "advancements": 2,
        "turns_active": 15
    }
}
```

## 🎨 UI/UX Design

### Journal Panel Layout

```
┌──────────────────────────────────────────────────────┐
│ ≡ Campaign Journal              [Timeline] [Entries] │ ← Header
├──────────────────────────────────────────────────────┤
│ Turn 15 - Day 45                        [📷][✏️][🗑️] │ ← Entry header
│ ⚔️ Battle at Rusty Ruins                              │
│                                                       │
│ [Photo: Battle scene]                                 │
│                                                       │
│ Victory (Pyrrhic) - 1 casualty                       │
│ Kira "Deadeye" Chen fell protecting the crew.       │
│ Her final shot eliminated the enemy captain.         │
│                                                       │
│ ┌─────────────────────────────────────────────────┐  │
│ │ 📊 Stats:                                       │  │ ← Expandable stats
│ │ • Loot: 350 credits                             │  │
│ │ • XP: 4 points                                  │  │
│ │ • Story Point earned: +1                        │  │
│ └─────────────────────────────────────────────────┘  │
│                                                       │
│ Tags: #memorable #sacrifice #KiraChen                │
│ Involved: Kira Chen, Jack Morrison                   │
│                                                       │
│ Player Notes:                                         │
│ "This was the most intense battle yet. Kira's       │
│  sacrifice saved the mission. We'll never forget."   │
│                                                       │
├──────────────────────────────────────────────────────┤
│ [+ New Entry] [📥 Export] [🔍 Search] [⚙️ Settings]   │ ← Actions
└──────────────────────────────────────────────────────┘
```

### Timeline View

```
┌──────────────────────────────────────────────────────┐
│ Campaign Timeline                     [Filter ▼]      │
├──────────────────────────────────────────────────────┤
│                                                       │
│ Turn 1  ●──────  Campaign Start                      │
│         │        Captain: "Iron" Jack Morrison       │
│         │                                              │
│ Turn 5  ●──────  ⚔️ First Victory                     │
│         │        vs Vent Crawlers                     │
│         │                                              │
│ Turn 10 ●──────  💀 Rival Established                 │
│         │        Red Hand Gang (Status: Hostile)      │
│         │                                              │
│ Turn 15 ●──────  ⚠️ Crew Member Died                  │
│         │        Kira "Deadeye" Chen - KIA            │
│         │                                              │
│ Turn 18 ●──────  🏆 Story Milestone                   │
│         │        +1 Victory Point                     │
│         │                                              │
│ Turn 22 ●──────  💰 Major Purchase                    │
│                  Plasma Rifle (cost: 18 credits)     │
│                                                       │
└──────────────────────────────────────────────────────┘
```

### Character History View

```
┌──────────────────────────────────────────────────────┐
│ ← Back to Journal        Kira "Deadeye" Chen        │
├──────────────────────────────────────────────────────┤
│ [Portrait]              Status: Deceased ⚰️           │
│                         Service: Turn 1-15 (15 turns)│
│                                                       │
│ Career Statistics:                                    │
│ ├─ Battles: 12                                       │
│ ├─ Kills: 23                                         │
│ ├─ Injuries: 3 (all recovered)                       │
│ └─ Advancements: 2                                   │
│                                                       │
│ ━━━ Timeline ━━━                                      │
│                                                       │
│ Turn 1  ● Joined Crew                                │
│         Original crew member                          │
│                                                       │
│ Turn 7  ● First Kill                                 │
│         Converted Pirate - Trade Station battle      │
│                                                       │
│ Turn 11 ● Injured                                    │
│         Leg Wound - recovered turn 14                │
│                                                       │
│ Turn 13 ● Advanced                                   │
│         Earned "Crack Shot" trait                    │
│                                                       │
│ Turn 15 ● KIA - Heroic Sacrifice                    │
│         Battle at Rusty Ruins                        │
│         Final shot eliminated enemy captain          │
│         Legacy: +1 Story Point earned                │
│                                                       │
│ [View All Battles]  [Export History]                │
└──────────────────────────────────────────────────────┘
```

## 🔧 Implementation Details

### Phase 1: Core Journal (Day 1-2)

**Files to Create**:
1. `src/qol/CampaignJournal.gd` - Core journal logic
2. `src/ui/components/qol/JournalPanel.gd` - UI component
3. `src/ui/components/qol/JournalPanel.tscn` - Scene layout

**Core Methods**:
```gdscript
# CampaignJournal.gd
class_name CampaignJournal
extends Node

signal entry_created(entry: Dictionary)
signal entry_updated(entry_id: String)
signal entry_deleted(entry_id: String)
signal timeline_updated()

# Entry management
func create_entry(data: Dictionary) -> String  # Returns entry ID
func update_entry(entry_id: String, data: Dictionary) -> bool
func delete_entry(entry_id: String) -> bool
func get_entry(entry_id: String) -> Dictionary
func get_all_entries() -> Array[Dictionary]

# Auto-generation
func auto_create_battle_entry(battle_result: Dictionary) -> void
func auto_create_milestone_entry(milestone_type: String, data: Dictionary) -> void
func auto_create_character_event(character_id: String, event_type: String, details: Dictionary) -> void

# Timeline
func get_timeline_data() -> Dictionary
func get_milestones() -> Array[Dictionary]
func filter_entries(filter: Dictionary) -> Array[Dictionary]  # By type, turn range, tags

# Character tracking
func get_character_history(character_id: String) -> Dictionary
func get_character_timeline(character_id: String) -> Array[Dictionary]

# Export
func export_to_pdf(file_path: String) -> bool
func export_to_markdown(file_path: String) -> bool
func export_to_json(file_path: String) -> bool
```

### Phase 2: Auto-Generation (Day 2-3)

**Hook into existing systems**:

```gdscript
# BattleResultsManager.gd integration
func _on_battle_completed(results: Dictionary):
    # Existing battle processing...
    
    # NEW: Auto-create journal entry
    CampaignJournal.auto_create_battle_entry({
        "turn": GameState.turn_number,
        "result": results.outcome,
        "casualties": results.casualties,
        "loot": results.loot_gained,
        "enemy_type": results.enemy_type,
        "location": results.battle_location
    })
```

```gdscript
# CharacterStats.gd integration
func apply_injury(injury_data: Dictionary):
    # Existing injury logic...
    
    # NEW: Track in character history
    CampaignJournal.auto_create_character_event(
        character_id,
        "injury",
        {"injury_type": injury_data.type, "recovery_time": injury_data.recovery}
    )
```

```gdscript
# StoryTrackSystem.gd integration
func advance_story_track():
    # Existing story advancement...
    
    # NEW: Milestone entry
    if story_points >= milestone_threshold:
        CampaignJournal.auto_create_milestone_entry("story_track", {
            "points": story_points,
            "milestone": current_milestone
        })
```

### Phase 3: UI & Export (Day 3-4)

**Journal Panel UI**:
```gdscript
# JournalPanel.gd
extends ResponsiveContainer

@onready var entries_container = $ScrollContainer/VBoxContainer
@onready var timeline_view = $TimelineView
@onready var search_box = $Header/SearchBox

func _ready():
    _load_entries()
    CampaignJournal.entry_created.connect(_on_entry_created)

func _load_entries():
    var entries = CampaignJournal.get_all_entries()
    for entry in entries:
        var entry_card = create_entry_card(entry)
        entries_container.add_child(entry_card)

func create_entry_card(entry: Dictionary) -> Control:
    var card = preload("res://src/ui/components/qol/JournalEntryCard.tscn").instantiate()
    card.setup(entry)
    return card

func _on_export_pressed(export_type: String):
    match export_type:
        "pdf":
            CampaignJournal.export_to_pdf("user://journal_export.pdf")
        "markdown":
            CampaignJournal.export_to_markdown("user://journal_export.md")
```

## 📸 Photo Attachment System

### Photo Storage

```gdscript
# Photo management
func attach_photo_to_entry(entry_id: String, image_data: Image, caption: String = "") -> bool:
    var photo_dir = "user://campaign_photos/"
    if not DirAccess.dir_exists_absolute(photo_dir):
        DirAccess.make_dir_absolute(photo_dir)
    
    var photo_path = photo_dir + "entry_%s_%d.png" % [entry_id, Time.get_unix_time_from_system()]
    var err = image_data.save_png(photo_path)
    
    if err == OK:
        var entry = get_entry(entry_id)
        if not entry.has("photos"):
            entry.photos = []
        entry.photos.append({"path": photo_path, "caption": caption})
        update_entry(entry_id, entry)
        return true
    return false
```

### Camera Integration (Mobile)

```gdscript
# Mobile camera capture
func _on_attach_photo_pressed():
    if OS.has_feature("mobile"):
        # Use native camera on mobile
        var camera_texture = await capture_from_camera()
        if camera_texture:
            attach_photo_to_entry(current_entry_id, camera_texture.get_image())
    else:
        # File picker on desktop
        var file_dialog = FileDialog.new()
        file_dialog.file_selected.connect(_on_photo_selected)
        add_child(file_dialog)
        file_dialog.popup_centered()
```

## 🧪 Testing Plan

### Unit Tests
```gdscript
# tests/unit/test_campaign_journal.gd
extends GdUnitTestSuite

func test_create_entry():
    var entry_id = CampaignJournal.create_entry({
        "turn_number": 10,
        "type": "battle",
        "title": "Test Battle"
    })
    assert_string(entry_id).is_not_empty()
    
func test_auto_generate_battle_entry():
    CampaignJournal.auto_create_battle_entry({
        "turn": 5,
        "result": "victory",
        "casualties": 0
    })
    var entries = CampaignJournal.filter_entries({"type": "battle"})
    assert_int(entries.size()).is_greater(0)

func test_character_timeline():
    var timeline = CampaignJournal.get_character_timeline("test_char")
    assert_array(timeline).is_not_null()
```

### Integration Tests
```gdscript
func test_battle_auto_journal():
    # Simulate battle completion
    var battle_result = create_test_battle_result()
    SignalBus.battle_completed.emit(battle_result)
    
    await get_tree().create_timer(0.1).timeout
    
    # Check journal entry created
    var entries = CampaignJournal.get_all_entries()
    assert_int(entries.size()).is_equal(1)
    assert_string(entries[0].type).is_equal("battle")
```

## 📤 Export Formats

### PDF Export Structure
```
┌─────────────────────────────────────┐
│ FIVE PARSECS CAMPAIGN JOURNAL       │
│ Campaign: [Name]                     │
│ Turns: 1-25                          │
│ Generated: [Date]                    │
├─────────────────────────────────────┤
│                                      │
│ TURN 1 - CAMPAIGN START             │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━    │
│ Captain "Iron" Jack Morrison...      │
│                                      │
│ TURN 5 - FIRST VICTORY              │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━    │
│ [Photo]                              │
│ Battle vs Vent Crawlers...           │
│ ...                                  │
└─────────────────────────────────────┘
```

### Markdown Export
```markdown
# Five Parsecs Campaign Journal
**Campaign**: Iron Will  
**Turns**: 1-25  
**Generated**: 2025-11-17

---

## Turn 1 - Campaign Start
**Date**: Day 1  
**Type**: Milestone

Captain "Iron" Jack Morrison begins his journey...

- Initial Crew: 4 members
- Starting Credits: 100
- Ship: Modified Freighter

---

## Turn 5 - First Victory
**Date**: Day 15  
**Type**: Battle  
**Result**: Victory

![Battle Photo](campaign_photos/turn5_battle.png)

The crew faced their first real challenge...

**Stats**:
- Enemy: Vent Crawlers
- Casualties: 0
- Loot: 250 credits
- XP: 3 points

---
```

## 📚 Related Documentation

- **UI Framework**: `docs/gameplay/UI_Framework.md` (journal inspiration)
- **GameState**: `src/core/state/GameState.gd` (persistence)
- **Battle System**: `src/core/battle/` (auto-generation hooks)

## ✅ Definition of Done

- [ ] CampaignJournal.gd core functionality
- [ ] Auto-generation from battle results
- [ ] Auto-generation from character events
- [ ] Manual entry creation UI
- [ ] Timeline visualization
- [ ] Character history view
- [ ] Photo attachment system
- [ ] PDF export working
- [ ] Markdown export working
- [ ] Save/load preserves entries
- [ ] Mobile-optimized UI
- [ ] Search/filter functional
- [ ] Unit tests pass (90%+ coverage)

---

**Next Steps**: Create initial `CampaignJournal.gd` singleton and hook into battle system.
