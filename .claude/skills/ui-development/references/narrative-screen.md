# Narrative Screen — KoDP-style Event Overlay (Phase 1 SHIPPED)

Full-screen King-of-Dragon-Pass-style narrative event display, integrated into Story Track May 22, 2026. Phases 2-6 extend to other campaign phases.

## Files

| Path | Lines | Role |
|------|-------|------|
| `src/ui/screens/narrative/NarrativeScreen.gd` | 609 | Full-screen overlay, extends CanvasLayer at L95 |
| `src/ui/screens/narrative/NarrativeTextGenerator.gd` | 107 | SSOT composer: opener + trait modifier + verbatim core_text |
| `src/ui/screens/narrative/AdvisorSystem.gd` | 215 | Crew→role match, quote generation |
| `src/ui/screens/narrative/NarrativeChoiceButton.gd` | 111 | Button + hint, fires `choice_pressed(int)` |
| `src/ui/screens/narrative/SceneStage.gd` | — | Layered scene composer (PSD pipeline output OR single-PNG) |
| `data/narrative/atmosphere_openers.json` | — | 5 categories + 12 trait modifiers + art_tag map |
| `data/narrative/advisor_quotes.json` | — | 6 roles × 3 moods × 1 quote scaffold |
| `data/narrative/species_personality.json` | — | 10 species flavor entries |

## Architecture

```text
NarrativeScreen.gd (CanvasLayer, layer = 95)
  └─ _root: Control (PRESET_FULL_RECT)
       ├─ BackgroundDim (ColorRect, blocks input)
       ├─ IllustrationFrame (Control, top 55%)
       │    ├─ GradientFallback (ColorRect, always-renders fallback)
       │    └─ SceneStage (the only rendering path for layered/flat art)
       ├─ NarrativePanel (PanelContainer, bottom 45%)
       │    ├─ EventTitle
       │    ├─ NarrativeText (RichTextLabel — composed text)
       │    ├─ AdvisorRow (portrait + quote)
       │    ├─ Briefing
       │    ├─ TurnRestrictions
       │    ├─ BonusObjective
       │    ├─ ChoicesContainer (VBoxContainer of NarrativeChoiceButton)
       │    └─ OutcomePanel (hidden for single-choice Story Track flow)
       └─ SkipButton (top-right)
```

## CanvasLayer L95 — why it matters

If you `extends Control` and add to root, you render BEHIND MainMenu's existing CanvasLayers (L80 PersistentResourceBar, L90 NotificationManager). First MCP screenshot showed MainMenu, not the overlay. **Fix**: `extends CanvasLayer`, `layer = 95` between game chrome (80/90/99) and TransitionManager (L100). All UI tree lives under a `_root: Control` child at `PRESET_FULL_RECT`.

## Settings toggle

- `SettingsManager.are_narrative_events_enabled()` — returns `true` by default
- Off path: phase panels fall through to their existing card UI
- Wire your phase panel to branch on this in its render method

## Integration pattern (replicate for Phases 2-5)

Reference implementation: `src/ui/screens/campaign/phases/StoryPhasePanel.gd`

```gdscript
func _show_event_view() -> void:
    if not _current_event:
        _show_clock_view()
        return

    var settings = get_node_or_null("/root/SettingsManager")
    if settings and settings.has_method("are_narrative_events_enabled") \
            and settings.are_narrative_events_enabled():
        _present_via_narrative_screen()
        return

    # [existing card-UI code — fallback path, unchanged]

func _present_via_narrative_screen() -> void:
    var NarrativeScreenClass = load("res://src/ui/screens/narrative/NarrativeScreen.gd")
    var screen = NarrativeScreenClass.new()
    get_tree().root.add_child(screen)
    screen.narrative_completed.connect(_on_narrative_done)
    screen.skip_requested.connect(_on_narrative_skipped)
    screen.present(_event_to_narrative_dict(_current_event), _build_narrative_context())

func _event_to_narrative_dict(event) -> Dictionary:
    var art_tag := "story_event_%02d" % event.event_number  # fallback
    return {
        "id": event.event_id,
        "title": event.title,
        "art_tag": art_tag,
        "core_text": event.narrative_intro,
        "briefing_text": event.narrative_briefing,
        "advisor_role": "social",
        "advisor_mood": "warning",
        "turn_restrictions": event.get_turn_restriction_strings(),
        "bonus_objective": event.objectives.get("bonus", {}),
        "choices": [{"id": 0, "label": "Continue to Battle", "hint": ""}],
    }

func _on_narrative_done(_result: Dictionary) -> void:
    _on_action_pressed()  # existing flow trigger, unchanged
```

The key principle: **narrative branch is purely additive**. The off path stays exactly the same as today. Existing tests, signals, and downstream consumers are untouched.

## NarrativeTextGenerator

```gdscript
const NarrativeTextGenerator = preload("res://src/ui/screens/narrative/NarrativeTextGenerator.gd")

var composed: String = NarrativeTextGenerator.compose_full_text(event_data, context)
# Returns: opener (from category) + " " + trait modifier + "\n\n" + verbatim core_text
```

- Static SSOT cache. `_ensure_loaded()` on first call, then in-memory thereafter
- `event_data["art_tag"]` selects opener category via art_tag→category map
- `context["world_traits"]` may append a trait modifier (e.g. "The dust here gets into everything.")
- `event_data["core_text"]` is treated as sacred — appended verbatim, never modified

## AdvisorSystem

```gdscript
const AdvisorSystem = preload("res://src/ui/screens/narrative/AdvisorSystem.gd")

var advisor: Character = AdvisorSystem.select_advisor(role, crew, art_tag)
var quote: String = AdvisorSystem.generate_quote(advisor, role, mood)
```

- Static SSOT cache
- **Priority**: training > class > species (a crew member trained as Broker outranks a class-Broker for the broker role)
- **6 roles**: Broker, Medic, Fighter, Tech, Scout, Social
- **3 moods**: warning, neutral, encouraging
- 18-quote scaffold (1 per role×mood). Expand during Phase 3 (CharacterPhasePanel integration)
- Empty crew or no-match → returns `null`, AdvisorRow hidden

## Critical gotchas

- **Portrait load safety**: `_apply_advisor_portrait` MUST guard `if ResourceLoader.exists(pp)` before `load(pp)`. `SpeciesPortraitRegistry.DEFAULT_PORTRAIT` points at art that doesn't ship.
- **Chrome restore**: Use `_exit_tree()`, NOT `tree_exited`. The latter fires after node detachment, breaking `/root/PersistentResourceBar` lookups.
- **Art assets deferred**: SceneStage manifests for `story_event_NN` don't exist yet. Gradient `ColorRect` behind SceneStage renders as fallback.
- **Path-loaded preload**: All narrative files use `preload("res://...")`, no `class_name`. Matches `docs/sop/component-patterns.md`.

## Public API

`NarrativeScreen` signals:
- `narrative_completed(result: Dictionary)` — emitted on choice click
- `choice_made(choice_id: int, outcome: Dictionary)` — emitted before completion
- `skip_requested` — top-right Skip button (treat same as continue for inevitable Story Track events)

`NarrativeScreen` methods:
- `present(event_data: Dictionary, context: Dictionary)` — show with data
- `dismiss()` — hide and queue_free

## What's deferred to Phase 2+

- Settings UI checkbox for the narrative-events toggle
- Quote pool expansion beyond 1-per-cell scaffold
- Real SceneStage manifests for `story_event_01..07`
- CharacterPhasePanel, CrewTaskEventDialog, TravelPhase, PostBattle integrations
- Polish: typewriter, Ken Burns, atmosphere overlay, audio
