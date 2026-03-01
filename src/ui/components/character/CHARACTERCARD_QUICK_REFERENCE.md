# CharacterCard Quick Reference

## Visual Layout Guide

```
┌─────────────────────────────────────────────────────┐
│ COMPACT VARIANT (80px height)                       │
│ ┌────────┐                                          │
│ │        │  Character Name                          │
│ │ [IMG]  │  Baseline • Colonist                     │
│ │        │                                          │
│ └────────┘                                          │
│   64x64                                             │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ STANDARD VARIANT (120px height) - DEFAULT           │
│ ┌────────┐                                          │
│ │        │  Character Name                          │
│ │        │  Baseline • Colonist                     │
│ │ [IMG]  │  COM: 4  REA: 4  SAV: 4                  │
│ │        │                                          │
│ │        │                                          │
│ └────────┘                                          │
│   96x96                                             │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ EXPANDED VARIANT (160px height)                     │
│ ┌──────────┐                                        │
│ │          │  Character Name                        │
│ │          │  Baseline • Colonist                   │
│ │          │  COM: 4  REA: 4  TOU: 4                │
│ │  [IMG]   │  SAV: 4  SPD: 4  LUK: 4                │
│ │          │  [View] [Edit] [Remove]                │
│ │          │                                        │
│ └──────────┘                                        │
│   128x128                                           │
└─────────────────────────────────────────────────────┘
```

## Copy-Paste Integration Examples

### 1. Add to CrewManagementScreen (Crew List)
```gdscript
# In CrewManagementScreen.gd
const CARD_SCENE := preload("res://src/ui/components/character/CharacterCard.tscn")

func _populate_crew_list(crew: Array[Character]) -> void:
    for character in crew:
        var card := CARD_SCENE.instantiate()
        card.set_variant(CharacterCard.CardVariant.STANDARD)
        card.set_character(character)
        card.card_tapped.connect(_on_crew_card_selected.bind(character))
        crew_list_container.add_child(card)

func _on_crew_card_selected(character: Character) -> void:
    print("Selected: %s" % character.name)
    # Navigate to character details screen
```

### 2. Add to CampaignDashboard (Captain Panel)
```gdscript
# In CampaignDashboard.gd
@onready var captain_card: CharacterCard = $CaptainPanel/CaptainCard

func _ready() -> void:
    var captain := GameStateManager.get_captain()
    captain_card.set_variant(CharacterCard.CardVariant.COMPACT)
    captain_card.set_character(captain)
    captain_card.card_tapped.connect(_on_captain_tapped)

func _on_captain_tapped() -> void:
    get_tree().change_scene_to_file("res://src/ui/screens/character/CharacterDetailsScreen.tscn")
```

### 3. Add to CharacterDetailsScreen (Hero Card)
```gdscript
# In CharacterDetailsScreen.gd
@onready var hero_card: CharacterCard = $Header/HeroCard

func display_character(character: Character) -> void:
    hero_card.set_variant(CharacterCard.CardVariant.EXPANDED)
    hero_card.set_character(character)
    hero_card.edit_pressed.connect(_on_edit_character)
    hero_card.remove_pressed.connect(_on_remove_character)

func _on_edit_character() -> void:
    # Open character editor
    pass

func _on_remove_character() -> void:
    # Confirm removal dialog
    pass
```

## Signal Reference

| Signal | Emitted When | Use Case |
|--------|-------------|----------|
| `card_tapped()` | User clicks/taps card body | Navigate to details, select character |
| `view_details_pressed()` | "View" button pressed | Open character sheet |
| `edit_pressed()` | "Edit" button pressed | Open character editor |
| `remove_pressed()` | "Remove" button pressed | Remove from crew (with confirmation) |

## Performance Tips

✅ **DO:**
- Preload scene: `const CARD_SCENE := preload(...)`
- Use STANDARD variant for lists (120px optimal)
- Batch instantiate in loops
- Connect signals after set_character()

❌ **DON'T:**
- Load scene in loops: `load()` is slow
- Use EXPANDED in ScrollContainer (too large)
- Update display in `_process()` (use signals)
- Forget to disconnect signals before queue_free()

## Variant Selection Guide

| Context | Variant | Why |
|---------|---------|-----|
| Dashboard captain panel | COMPACT | Space-efficient, glanceable |
| Crew roster list | STANDARD | Balance of info/space |
| Character details header | EXPANDED | Full info + actions |
| Mobile portrait mode | COMPACT/STANDARD | Vertical space limited |
| Desktop wide screen | STANDARD/EXPANDED | More horizontal space |

## Complete Integration Example

```gdscript
extends Control
class_name CrewRosterPanel

const CARD_SCENE := preload("res://src/ui/components/character/CharacterCard.tscn")

@onready var crew_container: VBoxContainer = $ScrollContainer/VBoxContainer

func _ready() -> void:
    _load_crew()

func _load_crew() -> void:
    var crew := GameStateManager.get_crew()
    
    # Clear existing
    for child in crew_container.get_children():
        child.queue_free()
    
    # Add cards
    for character in crew:
        var card := CARD_SCENE.instantiate()
        card.set_variant(CharacterCard.CardVariant.STANDARD)
        card.set_character(character)
        
        # Connect signals
        card.card_tapped.connect(_on_crew_selected.bind(character))
        card.view_details_pressed.connect(_on_view_details.bind(character))
        
        crew_container.add_child(card)
    
    print("Loaded %d crew members" % crew.size())

func _on_crew_selected(character: Character) -> void:
    print("Selected: %s" % character.name)
    # Highlight selection, show context menu, etc.

func _on_view_details(character: Character) -> void:
    # Navigate to character details
    var details_screen = load("res://src/ui/screens/character/CharacterDetailsScreen.tscn").instantiate()
    details_screen.set_character(character)
    get_tree().root.add_child(details_screen)
```

## Testing Checklist

Before integration:
- [ ] Card displays character name correctly
- [ ] Variant switching works at runtime
- [ ] Signals emit when expected
- [ ] Touch targets are 48dp minimum
- [ ] Performance <1ms per card
- [ ] Works on mobile (touch) and desktop (mouse)
- [ ] Follows Deep Space theme colors
- [ ] Stats update when character data changes

## Files

```
src/ui/components/character/
├── CharacterCard.gd                        # Implementation (396 lines)
├── CharacterCard.tscn                      # Scene (STANDARD default)
├── CHARACTERCARD_IMPLEMENTATION_NOTES.md   # Detailed docs
└── CHARACTERCARD_QUICK_REFERENCE.md        # This file
```

---

**Ready to integrate!** Copy-paste examples above into your screens and connect signals.
