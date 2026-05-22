# NarrativeScreen Phase 1 — Foundation Build Plan

**Status**: Draft — awaiting approval before implementation
**Date**: 2026-05-21
**Predecessor**: `docs/design/narrative_system_design.md` (full design, this plan implements its revised Phase 1 scope)
**Related**: `docs/research/scene-stage-atmosphere.md` (atmosphere overlay, parked — slots in as a SceneStage sibling)

## Locked decisions

1. **SceneStage is the only rendering path.** Flat illustrations are degenerate one-layer scenes (single BG plate, no actors). One mental model, one z-order, atmosphere overlays naturally slot in as a SceneStage sibling.
2. **Foundation-only MVP — no integration target in Phase 1.** Builds the substrate; integration is Phase 2+.
3. **Art_tag retrofit is per-phase, not bulk.** Phase 1 touches zero existing event JSONs. Each integration phase retrofits only the events it integrates.

## What Phase 1 ships

A working NarrativeScreen component that can be opened standalone (test scene + MCP injection) and renders mock events end-to-end with all five surfaces — illustration, narrative text, advisor, choices, outcome — using fallback art (gradient + colored initial portraits). Phase 2+ wires it into real campaign phases.

## File manifest

### New files (foundation)

```
src/ui/screens/narrative/
├── SceneStage.gd                    # EXISTING — unchanged
├── NarrativeScreen.gd               # NEW ~350 lines — Control, full-screen event display
├── NarrativeTextGenerator.gd        # NEW ~180 lines — procedural openers + trait modifiers
├── AdvisorSystem.gd                 # NEW ~220 lines — crew→role matching + quote lookup
├── NarrativeChoiceButton.gd         # NEW ~80 lines — consequence-hint button
├── narrative_demo.tscn              # NEW — test scene loaded with mock event data
└── narrative_demo.gd                # NEW ~60 lines — test driver, can be standalone or MCP-injected

data/narrative/
├── atmosphere_openers.json          # NEW — opener pools by scene_category + world_trait modifiers
├── advisor_quotes.json              # NEW — ~180 quotes (6 roles × 3 moods × ~10 quotes)
├── species_personality.json         # NEW — species voice flavors (Section 4 of design doc)
└── mock_events.json                 # NEW — 5-7 hand-crafted test events covering the major shapes

assets/narrative/
└── (empty in Phase 1 — fallback gradients only)
```

### Files NOT touched in Phase 1

- Any phase panel (`CharacterPhasePanel`, `StoryPhasePanel`, `CrewTaskEventDialog`, etc.)
- Any campaign event JSON (no `art_tag` retrofit)
- `SceneStage.gd` (used as-is)
- `CharacterCard.gd` (advisor portraits use existing `get_portrait()` accessor)

## Component contracts

### `NarrativeScreen.gd` public API

```gdscript
extends Control

signal choice_made(choice_id: int, outcome: Dictionary)
signal narrative_completed(result: Dictionary)
signal skip_requested()

func present(event_data: Dictionary, context: Dictionary) -> void
func dismiss() -> void
func is_presenting() -> bool
```

**event_data shape (input contract)**:
```gdscript
{
    "id": "event_unique_id",
    "title": "The Quiet Bar",
    "art_tag": "starport_bar",                  # OR scene_id for SceneStage extracted PSD
    "art_side": "right",                        # "left" | "right" | "center"
    "core_text": "(verbatim from rulebook)",
    "advisor_role": "social",                   # optional, auto-picked if absent
    "advisor_mood": "neutral",                  # positive | warning | neutral
    "atmosphere_tags": ["interior", "bar"],
    "choices": [
        {"id": 0, "label": "Talk to the locals", "hint": "Tests Savvy", ...},
        {"id": 1, "label": "Buy a drink and listen", "hint": "1 credit", ...},
        {"id": 2, "label": "Leave quietly", "hint": "No effect", ...}
    ],
    "narrative_opener": null                    # if set, skips procedural generation
}
```

**context shape (game state passed in)**:
```gdscript
{
    "world_name": "Krash IV",
    "world_traits": ["haze", "rampant_crime"],
    "crew": [Character, Character, ...],        # for advisor selection
    "turn_number": 14
}
```

**Internal scene tree** (built in `_ready()`):
```
NarrativeScreen (Control, PRESET_FULL_RECT)
├── BackgroundDim (ColorRect, modulate.a = 0.85, blocks input)
├── IllustrationFrame (Control, top 55%)
│   └── SceneStage (Control)             # <- the only rendering path
├── NarrativePanel (PanelContainer, bottom 45%)
│   ├── VBoxContainer
│   │   ├── EventTitle (Label)
│   │   ├── NarrativeText (RichTextLabel)
│   │   ├── AdvisorRow (HBoxContainer, optional)
│   │   │   ├── AdvisorPortrait (TextureRect 64x64)
│   │   │   ├── AdvisorName (Label)
│   │   │   └── AdvisorQuote (RichTextLabel, italic)
│   │   ├── ChoicesContainer (VBoxContainer)
│   │   │   └── NarrativeChoiceButton[] (touch-friendly)
│   │   └── OutcomePanel (VBoxContainer, hidden until choice made)
│   │       ├── OutcomeText (RichTextLabel)
│   │       └── ContinueButton ("Continue")
└── SkipButton (Button, top-right corner, FONT_SIZE_SM)
```

### `NarrativeTextGenerator.gd` API

```gdscript
extends RefCounted

# Returns a 1-2 sentence atmospheric opener for the scene category.
static func generate_opener(scene_category: String, world_name: String,
        world_traits: Array) -> String

# Returns the world-trait modifier sentence (or empty string).
static func get_trait_modifier(world_traits: Array) -> String

# Composes the full narrative text: opener + core_text + (optional) trait modifier.
static func compose_full_text(event_data: Dictionary, context: Dictionary) -> String
```

Loads `data/narrative/atmosphere_openers.json` once via SSOT static cache pattern.

### `AdvisorSystem.gd` API

```gdscript
extends RefCounted

# Picks the best crew member for the given advisor role + event context.
# Returns null if no suitable advisor exists. Priority: training > class > species.
static func select_advisor(role: String, crew: Array, art_tag: String = "") -> Character

# Returns one quote from the role+mood pool, optionally flavored by species.
static func generate_quote(advisor: Character, role: String, mood: String) -> String

# Returns the role inferred from an art_tag if event_data doesn't specify.
static func infer_role_from_art_tag(art_tag: String) -> String
```

Loads `data/narrative/advisor_quotes.json` + `data/narrative/species_personality.json` once.

### `NarrativeChoiceButton.gd` API

```gdscript
extends Button

signal choice_pressed(choice_id: int)

func setup(choice_data: Dictionary) -> void
```

choice_data shape:
```gdscript
{
    "id": 0,
    "label": "Talk to the locals",
    "hint": "Tests Savvy",          # consequence hint shown as smaller text below label
    "enabled": true,                # if false, button disabled with reason in tooltip
    "disabled_reason": ""            # tooltip text when disabled
}
```

## Data file schemas

### `data/narrative/atmosphere_openers.json`

```json
{
  "_source": "Five Parsecs Digital narrative design (docs/drafts/narrative_system_design.md §5)",
  "openers": {
    "ship_interior": [
      "The recycled air aboard the ship carries its usual metallic tang.",
      "Somewhere in the ship's guts, a pipe rattles with the rhythm of an old engine.",
      "The overhead lights flicker — another power coupling that needs attention.",
      "The hum of the Svensen drive fills the silence between conversations."
    ],
    "starport": [
      "The starport on {world_name} is like every other — crowded, loud, and smelling of engine grease and alien cooking.",
      "Docking fees paid, your crew steps out into the press of bodies and commerce.",
      "The market stalls stretch in every direction, a maze of salvage and stolen goods.",
      "Somewhere nearby, a Unity recruitment poster peels from a rust-stained wall.",
      "A K'Erin merchant argues prices with a Soulless trader. Neither seems to be winning."
    ],
    "wilderness": [...],
    "battle_aftermath": [...],
    "space_travel": [...]
  },
  "trait_modifiers": {
    "haze": "The ever-present haze turns everything past fifty meters into grey suggestions.",
    "frozen": "Frost clings to every surface. Your breath hangs in the air like smoke.",
    "barren": "Nothing grows here. The landscape is naked rock and dust."
  },
  "art_tag_to_category": {
    "ship_interior_crew": "ship_interior",
    "ship_interior_bridge": "ship_interior",
    "starport_market": "starport",
    "starport_bar": "starport",
    "wilderness_approach": "wilderness",
    "battle_aftermath_victory": "battle_aftermath",
    "space_travel": "space_travel"
  }
}
```

`{world_name}` is substituted at runtime via `String.format()`. Categories are coarse; art tags are fine. Mapping covers the ~30 known art tags.

### `data/narrative/advisor_quotes.json`

```json
{
  "_source": "Section 4 of narrative system design",
  "roles": {
    "broker": {
      "positive": [
        "I know someone who deals in these. Could be worth triple on the right world.",
        "This is a good deal. Don't think too hard about it."
      ],
      "warning": [
        "Those markings are Unity military. Could be trouble.",
        "Trust me, that price is too good. There's a catch."
      ],
      "neutral": [
        "Standard merchant fare. Nothing special.",
        "I've seen better. I've seen worse."
      ]
    },
    "medic": {...},
    "fighter": {...},
    "tech": {...},
    "scout": {...},
    "social": {...}
  },
  "role_to_art_tags": {
    "broker":  ["trade_shady", "patron_meeting", "starport_market"],
    "medic":   ["ship_interior_medbay", "battle_aftermath_retreat"],
    "fighter": ["battle_aftermath_victory", "rival_encounter", "wilderness_approach"],
    "tech":    ["ship_interior_damaged", "crash_site", "industrial_zone"],
    "scout":   ["wilderness_approach", "world_arrival", "quest_discovery"],
    "social":  ["starport_bar", "character_social", "patron_meeting"]
  }
}
```

**Phase 1 scaffold density: 1 quote per role-mood cell = 18 quotes total** (6 roles × 3 moods). Just enough to prove the swap-by-mood + species-flavor system works on the 5-7 mock events. Target ~10 per cell = ~180 quotes is the long-term content goal, expanded during Phase 2-4 integration where advisor coverage actually matters.

### `data/narrative/species_personality.json`

```json
{
  "k_erin":      {"flavor_words": ["honor", "challenge", "battle", "weak"], "speech_pattern": "blunt"},
  "engineer":    {"flavor_words": ["interface", "circuit", "tolerance", "spec"], "speech_pattern": "technical"},
  "precursor":   {"flavor_words": ["pattern", "echoes", "convergence"], "speech_pattern": "cryptic"},
  "soulless":    {"flavor_words": ["collective", "concurs", "optimal"], "speech_pattern": "hive_voice"},
  "feral":       {"flavor_words": ["scent", "movement", "wrong"], "speech_pattern": "instinctive"},
  "swift":       {"flavor_words": ["quick", "look look", "yes"], "speech_pattern": "excitable"},
  "manipulator": {"flavor_words": ["leverage", "angle", "useful"], "speech_pattern": "political"},
  "hopeful_rookie": {"flavor_words": ["amazing", "really", "wow"], "speech_pattern": "wide_eyed"}
}
```

Used by `AdvisorSystem.generate_quote()` to optionally insert species-specific flavor when the matched advisor is a non-human species. Phase 1 ships 8-12 species entries; full coverage is content work.

### `data/narrative/mock_events.json`

5-7 hand-crafted events for the test harness, covering:
- One ship_interior_crew event with social advisor (Phase 1 must show this works)
- One starport_market event with broker advisor (test trade flow)
- One battle_aftermath_victory event with fighter advisor (test mood = positive)
- One wilderness_approach event with scout advisor (test species flavor)
- One ship_interior_damaged event with tech advisor (test mood = warning)
- One event with NO advisor match (test the "no advisor" path)
- One event with three choices, each with different consequence hints

## Test harness

`narrative_demo.tscn` is a standalone scene that:
1. Loads `mock_events.json`
2. Provides a launcher UI (event picker dropdown + "Present" button)
3. On Present: instantiates `NarrativeScreen`, calls `present(event_data, mock_context)`
4. Listens for `choice_made` and `narrative_completed` signals, logs to a debug panel

Runs in two ways:
- **Standalone**: open the .tscn in editor, click Run Scene
- **MCP injection**: `mcp__godot__run_script` from MainMenu, instantiates NarrativeScreen as overlay (same pattern as the SceneStage proof)

Mock context shape:
```gdscript
{
    "world_name": "Krash IV",
    "world_traits": ["haze", "rampant_crime"],
    "crew": [_make_mock_crew_member(...)],   # 5-6 hand-crafted Characters
    "turn_number": 7
}
```

## Verification criteria

Phase 1 is "done" when:

- [ ] Headless compile clean across all new files
- [ ] `narrative_demo.tscn` launches in editor and shows event picker
- [ ] All 5-7 mock events present + dismiss without errors
- [ ] Advisor portrait + quote appears for the 4-5 events that have matching crew
- [ ] "No advisor" event renders cleanly with the advisor row hidden (not blank)
- [ ] Choice buttons fire `choice_made` with correct choice_id
- [ ] Skip button fires `skip_requested` and dismisses cleanly
- [ ] Procedural openers vary across multiple presentations of the same event (random pick from pool)
- [ ] World trait modifier appears appended to opener when context has matching trait
- [ ] Gradient fallback art renders cleanly for every event (no art_tag has a real PNG yet)
- [ ] MCP screenshot captured: `narrative-screen-foundation.png` shows the full surface
- [ ] One end-to-end test: present event → make choice → see outcome → click Continue → screen dismisses

No phase panels are modified. No event JSONs are modified. The component is fully testable in isolation.

## What's IN scope for Phase 1

- Component structure + signals + lifecycle
- Procedural opener generation from world+crew state
- Advisor selection + quote retrieval (training > class > species priority)
- Choice presentation + outcome panel
- Skip button (skip-this-event scope only — settings-level skip-all is Phase 4)
- Gradient/colored-initial fallback art (the system works without art)
- Test scene + mock event data

## What's OUT of scope for Phase 1

- Any phase panel integration (Phase 2)
- Any existing event JSON modifications (each phase retrofits its own)
- Real art assets (`assets/narrative/{art_tag}.png` directory stays empty)
- Atmosphere overlay (parked research — Phase 3 if NarrativeScreen + atmosphere both activate)
- Typewriter text effect (Phase 4 polish)
- Ken Burns / parallax on illustrations (Phase 4 polish)
- Transition animations between management/narrative modes (Phase 4 polish)
- Sound design hooks (Phase 4 polish)
- "Story log" / event re-read mode (post-Phase 4 if at all)
- Dice resolution mechanic on choices (Phase 2 — depends on which phase integrates first; choice outcomes are passed in for now)

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| SceneStage doesn't gracefully handle single-PNG art (was designed for layered PSDs) | Medium | Test in Phase 1: degenerate one-layer manifest with just a bg_layers entry. If SceneStage chokes, falls back to direct TextureRect inside IllustrationFrame as escape hatch |
| Advisor selection logic gets edge cases wrong (e.g. captain has multiple matching trainings) | Medium | Phase 1 test covers no-match, single-match, and tie-break paths. Add unit tests if logic gets > 50 lines |
| Quote pools feel formulaic with only 3-4 quotes per cell | High | Acceptable for Phase 1 — content work, not engineering. Phase 2 expands pools as part of MVP target's integration |
| Mock events don't match real event_data shape from existing systems | Medium | Reference CrewTaskEventDialog event handling for the real shape; mock_events.json mirrors it |
| NarrativeScreen layout breaks at small viewport sizes | Low | Use existing FiveParsecsCampaignPanel responsive base methods; test at 1280x720 and 1920x1080 |

## Estimated effort

| Component | Lines | Effort |
|---|---|---|
| `NarrativeScreen.gd` | ~350 | 4-6h |
| `NarrativeTextGenerator.gd` | ~180 | 2-3h |
| `AdvisorSystem.gd` | ~220 | 3-4h |
| `NarrativeChoiceButton.gd` | ~80 | 1h |
| `narrative_demo.tscn` + driver | ~100 total | 2h |
| Data files (scaffolding pools) | n/a | 2-3h |
| Test + screenshot verification | n/a | 2-3h |
| **Total** | **~930 lines of code** | **~16-22 hours** |

Within 2-3 focused work days.

## Refinement: visual layout (ASCII wireframe)

The NarrativeScreen at presentation time, 1920×1080 viewport reference:

```
+----------------------------------------------------------------------+
|                                                            [Skip ✕] |
|                                                                      |
|                                                                      |
|                     IllustrationFrame (top 55%)                      |
|                          contains SceneStage                         |
|                                                                      |
|                                                                      |
|                                                                      |
|                                                                      |
+----------------------------------------------------------------------+
|  The Quiet Bar                                              [EVT_03] |
|  ------------------------------------------------------------------- |
|  The starport on Krash IV is like every other — crowded, loud, and  |
|  smelling of engine grease and alien cooking. The ever-present haze |
|  turns everything past fifty meters into grey suggestions. You step |
|  into the cantina. The locals stop talking when you enter. Then     |
|  resume, pretending not to watch.                                    |
|                                                                      |
|  [Portrait]  Mara, Social Advisor                                   |
|   (64x64)   "I'd let me handle the talking. They're sizing us up."  |
|                                                                      |
|  ------------------------------------------------------------------- |
|  ┌─────────────────────────────┐  Tests Savvy                       |
|  │ Talk to the locals          │                                    |
|  └─────────────────────────────┘                                    |
|  ┌─────────────────────────────┐  Costs 1 credit                    |
|  │ Buy a drink and listen      │                                    |
|  └─────────────────────────────┘                                    |
|  ┌─────────────────────────────┐  No effect                         |
|  │ Leave quietly               │                                    |
|  └─────────────────────────────┘                                    |
+----------------------------------------------------------------------+
                       NarrativePanel (bottom 45%)
```

Skip button is top-right corner, single-line label. NarrativePanel is `PanelContainer` with `COLOR_ELEVATED` background and `COLOR_BORDER` 1px border. Choices stack vertically with 8px gaps; each is a touch-target (`TOUCH_TARGET_MIN = 48px`).

After a choice is pressed, the ChoicesContainer hides and OutcomePanel slides in below the advisor row:

```
|  ------------------------------------------------------------------- |
|  You spend the evening listening. By midnight you know the rumors:  |
|  Unity patrol cycles, three local crews, and where the cheap fixer  |
|  drinks. +1 Story Point gained.                                     |
|                                                                      |
|                                              ┌─────────────────────┐|
|                                              │     Continue        │|
|                                              └─────────────────────┘|
+----------------------------------------------------------------------+
```

Continue button is right-aligned, full-width on mobile.

## Refinement: full event walkthrough (one complete trace)

Trace of a single mock event through every component. Use this as the integration spec for cross-component contracts.

**Input** — `mock_events.json` entry:

```json
{
  "id": "EVT_03",
  "title": "The Quiet Bar",
  "art_tag": "starport_bar",
  "art_side": "right",
  "core_text": "You step into the cantina. The locals stop talking when you enter. Then resume, pretending not to watch.",
  "advisor_role": "social",
  "advisor_mood": "warning",
  "atmosphere_tags": ["interior", "bar", "tense"],
  "choices": [
    {"id": 0, "label": "Talk to the locals", "hint": "Tests Savvy"},
    {"id": 1, "label": "Buy a drink and listen", "hint": "Costs 1 credit"},
    {"id": 2, "label": "Leave quietly", "hint": "No effect"}
  ]
}
```

**Context passed in** — game state at call time:

```gdscript
{
  "world_name": "Krash IV",
  "world_traits": ["haze", "rampant_crime"],
  "crew": [captain, mara, jax, k_thar],   # Character objects
  "turn_number": 14
}
```

**Step 1 — `present()` receives event_data + context, hides chrome**

```gdscript
PersistentResourceBar.hide_bar()
# Phase panel breadcrumbs hide via existing visibility signal
self.visible = true
```

**Step 2 — IllustrationFrame.SceneStage resolves art**

```gdscript
# Look up art_tag → SceneStage scene_id
var scene_id := _resolve_scene_id("starport_bar")
# Phase 1: no PSDs match, returns "" → fallback gradient renders
# Phase 2+: when a starport_bar PSD is extracted, scene_id resolves
#          and SceneStage.set_scene(scene_id) loads the layered scene
if scene_id == "":
    _render_gradient_fallback("starport_bar")
else:
    scene_stage.set_scene(scene_id)
```

**Step 3 — NarrativeTextGenerator composes text**

```gdscript
var category := NarrativeTextGenerator._art_tag_to_category("starport_bar")
# → "starport"
var opener := NarrativeTextGenerator._pick_opener_for_category(
    "starport", context.world_name)
# → "The starport on Krash IV is like every other — crowded, loud, and smelling
#    of engine grease and alien cooking."
var trait_modifier := NarrativeTextGenerator.get_trait_modifier(
    context.world_traits)
# → "The ever-present haze turns everything past fifty meters into grey
#    suggestions." (haze wins; rampant_crime is also in traits but openers
#    table only has one slot — first match by table order)
var full_text := opener + " " + trait_modifier + " " + event_data.core_text
narrative_text.text = full_text
```

**Step 4 — AdvisorSystem picks an advisor**

```gdscript
var advisor := AdvisorSystem.select_advisor("social", context.crew, "starport_bar")
# Iterates crew, priority:
#   1. Training match (any crew member with relevant social training)
#   2. Class match (Entertainer, Diplomat)
#   3. Species match (Manipulator, Empath, Precursor)
# Returns Mara (Diplomat class) — captain has no social training, others fail
if advisor:
    var quote := AdvisorSystem.generate_quote(advisor, "social", "warning")
    # Phase 1: 1 quote per cell → returns the single "social warning" quote
    # Species flavor: Mara is human → no species substitution
    # → "I'd let me handle the talking. They're sizing us up."
    advisor_portrait.texture = _load_portrait(advisor)
    advisor_name.text = advisor.character_name + ", " + "Social Advisor"
    advisor_quote.text = "[i]" + quote + "[/i]"
    advisor_row.visible = true
else:
    advisor_row.visible = false   # no commentary
```

**Step 5 — Choices instantiated**

```gdscript
for choice in event_data.choices:
    var btn := NarrativeChoiceButton.new()
    btn.setup(choice)
    btn.choice_pressed.connect(_on_choice_pressed)
    choices_container.add_child(btn)
```

**Step 6 — Player clicks "Buy a drink and listen"**

```gdscript
func _on_choice_pressed(choice_id: int) -> void:
    var outcome := {
        "choice_id": choice_id,
        "text": "You spend the evening listening. By midnight you know the rumors: Unity patrol cycles, three local crews, and where the cheap fixer drinks. +1 Story Point gained.",
        "state_changes": {"story_points": 1, "credits": -1}
    }
    # Phase 1: outcome comes from a mock _resolve_outcome() in the demo
    # Phase 2+: outcome comes from the integrating phase panel's resolution logic
    choice_made.emit(choice_id, outcome)
    _show_outcome(outcome)

func _show_outcome(outcome: Dictionary) -> void:
    choices_container.visible = false
    outcome_text.text = outcome.text
    outcome_panel.visible = true
```

**Step 7 — Player clicks Continue, screen dismisses**

```gdscript
func _on_continue_pressed() -> void:
    narrative_completed.emit({"choice_id": current_choice_id, "outcome": current_outcome})
    dismiss()

func dismiss() -> void:
    PersistentResourceBar.show_bar()
    self.visible = false
```

Phase 1 callers receive `narrative_completed`, log the result. Phase 2+ callers (real phase panels) consume `outcome.state_changes` to apply the actual game state mutations.

## Refinement: build sequencing within Phase 1

The 7 files have a dependency order. Build in this sequence so each step is testable in isolation:

1. **`data/narrative/atmosphere_openers.json`** + **`advisor_quotes.json`** + **`species_personality.json`** (data first — no code dependency). ~2h
2. **`NarrativeTextGenerator.gd`** — pure RefCounted, reads atmosphere_openers.json. Unit-testable with `print(generator.compose_full_text(mock_event, mock_context))`. ~2-3h
3. **`AdvisorSystem.gd`** — RefCounted, reads advisor_quotes.json + species_personality.json. Unit-testable with hand-crafted Character instances. ~3-4h
4. **`NarrativeChoiceButton.gd`** — small standalone Control. Can be dropped into any test scene to visually verify. ~1h
5. **`mock_events.json`** — author 5-7 events after the above are working (so you know what shapes work). ~1h
6. **`NarrativeScreen.gd`** — the orchestrator. Composes steps 2-4 into the full surface. ~4-6h
7. **`narrative_demo.tscn` + `narrative_demo.gd`** — last, picks up everything. ~2h

Each step's exit criterion is "the next step can be built on top." Step 1 = JSON parses. Step 2 = opener generation prints expected strings. Step 3 = advisor selection picks right Character. Step 4 = button renders with hint. Step 5 = events round-trip through Steps 2-4. Step 6 = screen presents/dismisses cleanly. Step 7 = full E2E demo runs.

## Refinement: expanded edge cases

Phase 1 must explicitly handle:

| Case | Expected behavior | Test mock event |
|---|---|---|
| `event_data.advisor_role` is null/absent | Try `infer_role_from_art_tag(art_tag)`; if still no match, hide advisor row | Mock event with no advisor_role; expects "no commentary" path |
| No crew member matches the advisor role | Hide advisor row entirely (don't show "no advisor available") | Mock event with role = "social" but crew has no social-capable members |
| Crew array is empty (very early game?) | Hide advisor row, log warning | Mock context with empty crew |
| `event_data.core_text` is empty | Render opener + trait modifier only, with empty core_text — graceful degradation | Mock event with core_text = "" |
| `event_data.choices` is empty | Hide choices container, show a single "Continue" button that fires choice_made with id=-1 | Mock event with no choices (informational event) |
| Multiple world traits match openers table | Take first match by table order (don't stack modifiers — looks busy) | Context with world_traits = ["haze", "frozen"] |
| World trait not in openers table | Skip trait modifier silently | Context with world_traits = ["heavily_enforced"] (not in modifiers table) |
| `art_tag` doesn't match any scene_id and has no flat PNG | Fallback gradient renders; system continues | Mock event with art_tag = "nonexistent_tag" |
| Skip button pressed during outcome panel | Treat as "Continue" — fires narrative_completed with current state | Manual test |
| `present()` called while already presenting | Replace current event with new one (don't queue; phase panels can manage queueing if needed) | Manual test |
| Viewport resize during presentation | Layout recalculates, no visual glitches | Manual test at 1280×720 and 1920×1080 |

Each row maps to either a mock event in `mock_events.json` or a manual test step in the verification checklist.

---

## Phase 2+ preview (not in this plan, for context)

Once Phase 1 ships:

- **Phase 2**: First integration. Recommend Story Track (7 events, narrative_intro + narrative_briefing JSON already exist). Retrofit `art_tag: "story_event_NN"` on each. Wire `StoryPhasePanel` to `NarrativeScreen.present()`. Validates the full integration shape with the lowest-risk event surface.
- **Phase 3**: CharacterPhasePanel (30 character events). Highest narrative-density integration. Quote pools expand.
- **Phase 4**: CrewTaskEventDialog replacement. Bulk content work (200+ events retrofitted with art_tags).
- **Phase 5**: TravelPhase + PostBattle narrative beats.
- **Phase 6**: Polish (typewriter, Ken Burns, transitions, audio hooks, atmosphere overlay activation).

Each phase is a standalone deliverable with its own MVP and verification.
