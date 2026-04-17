# Five Parsecs Digital — Narrative System Design

**Version**: 1.0 (Draft)  
**Date**: April 16, 2026  
**Inspiration**: King of Dragon Pass / Six Ages  
**Scope**: Core Rulebook campaign experience (9-phase turn flow)

---

## 1. Vision Statement

The Five Parsecs Campaign Manager transforms from a **campaign bookkeeping tool** into a **digital storybook** where every campaign turn feels like a chapter in a pulp sci-fi novel. Inspired by King of Dragon Pass, the UI alternates between two clean modes:

- **Management Mode** — information-dense dashboard (crew stats, equipment, ship). The "clipboard."
- **Narrative Mode** — full-screen illustrated event scenes with text and choices. The "story."

When narrative is happening, all management chrome disappears. The player is *in* the world, not managing a spreadsheet.

---

## 2. The NarrativeScreen Component

### Architecture

```
NarrativeScreen (extends Control, full-screen)
│
├── IllustrationLayer (TextureRect, top 55% of screen)
│   ├── Loads from: res://assets/narrative/{art_tag}.png
│   ├── Fallback: gradient atmosphere (world-theme-tinted ColorRect)
│   ├── text_side property: "left" | "right" | "center"
│   └── Expand mode: EXPAND_FIT_WIDTH, STRETCH_KEEP_ASPECT_COVERED
│
├── NarrativePanel (PanelContainer, bottom 45%, semi-transparent overlay)
│   ├── EventTitle (Label — FONT_SIZE_LG, COLOR_FOCUS cyan)
│   ├── NarrativeText (RichTextLabel — FONT_SIZE_MD, COLOR_TEXT_PRIMARY)
│   ├── AdvisorRow (HBoxContainer, optional)
│   │   ├── AdvisorPortrait (TextureRect, 64x64, CharacterCard portrait system)
│   │   ├── AdvisorName (Label, FONT_SIZE_SM, COLOR_TEXT_SECONDARY)
│   │   └── AdvisorQuote (RichTextLabel, italic)
│   ├── ChoicesContainer (VBoxContainer)
│   │   └── NarrativeChoiceButton[] (touch-friendly, shows consequence hints)
│   └── OutcomePanel (VBoxContainer, hidden until choice made)
│       ├── OutcomeText (RichTextLabel)
│       ├── DiceResult (Label, if applicable)
│       └── ContinueButton ("Continue")
│
└── Signals:
    ├── choice_made(choice_id: int, outcome: Dictionary)
    ├── narrative_completed(result: Dictionary)
    └── skip_requested()
```

### Lifecycle

1. Parent phase panel calls `NarrativeScreen.present(event_data, context)`
2. NarrativeScreen hides PersistentResourceBar (Layer 80) and phase breadcrumbs
3. Illustration loads (or gradient fallback), text appears with typewriter-optional effect
4. If advisor is relevant, portrait + quote fades in below narrative text
5. Choices appear as touch-friendly buttons with consequence hints
6. Player makes choice → dice roll resolves if needed → outcome panel appears
7. Player clicks Continue → `narrative_completed` emitted → phase panel resumes
8. Chrome restored

### Illustration Specs

- **Scene paintings**: 2048×1024 px (2:1 landscape), PNG
- **Character portraits**: 512×512 px (square), PNG
- **Style**: Painted/illustrated (matching Five Parsecs book interior art), NOT photorealistic
- **Rule**: Illustrations depict *situations*, not specific player characters (enables reuse)
- **Tone**: Gritty sci-fi mercenary — dingy ships, alien bazaars, war-torn worlds

---

## 3. Art Tag System

Instead of 1:1 art-to-event mapping, events carry an `art_tag` that maps to a pool of scene illustrations. One painting serves multiple events.

### Core Rulebook Art Tags (~30 tags, ~50-60 paintings total)

| Art Tag | Description | Painting Variants | Events Using It |
|---------|-------------|-------------------|-----------------|
| `ship_interior_crew` | Crew gathered in ship common area | 2-3 | Upkeep, crew arguments, heart-to-heart, time to burn |
| `ship_interior_bridge` | Captain at ship controls | 1-2 | Travel decisions, navigation trouble |
| `ship_interior_medbay` | Medical bay / sick bay | 1-2 | Injury recovery, friendly doc, good food healing |
| `ship_cargo` | Cargo bay / stash room | 1 | Equipment assignment, cargo selling, contraband |
| `ship_interior_damaged` | Ship with sparking consoles | 1-2 | Life support failure, hull damage, malfunction |
| `starport_market` | Busy alien marketplace | 2-3 | Trading events, buying weapons, merchant encounters |
| `starport_bar` | Seedy bar / cantina | 2 | Recruitment, meet a patron, nice chat, rumors |
| `starport_street` | Street-level starport scene | 2 | Exploration events, got noticed, pick a fight |
| `starport_docks` | Landing pads / ship docks | 1-2 | Arrival, departure, escape pod rescue, patrol ship |
| `wilderness_approach` | Open terrain, approaching target | 2 | Opportunity missions, battle approach |
| `urban_approach` | Urban ruins / settlement edge | 2 | Street fight missions, urban battles |
| `industrial_zone` | Factory / refinery area | 1 | Industrial missions, salvage jobs |
| `alien_ruins` | Ancient alien structures | 1-2 | Quest missions, story track events |
| `wasteland` | Desolate terrain | 1 | Roving threat encounters, dangerous world events |
| `crash_site` | Wrecked ship / debris field | 1 | Asteroids travel event, distress call, salvage |
| `battle_aftermath_victory` | Crew standing over battlefield | 1-2 | Post-battle victory, get paid, battlefield finds |
| `battle_aftermath_retreat` | Crew fleeing / carrying wounded | 1 | Post-battle loss, injuries, retreat |
| `character_training` | Character practicing / studying | 1-2 | XP awards, advanced training, instruction book |
| `character_personal` | Character alone, contemplative | 2 | Depression, melancholy, hobby, make-over |
| `character_social` | Two characters talking | 2 | Heart-to-heart, crew fight, admirer, new friend |
| `patron_meeting` | Formal meeting / job briefing | 2 | Patron jobs, corporate contacts |
| `rival_encounter` | Hostile confrontation | 1-2 | Rival attacks, old nemesis, tracked down |
| `galactic_war` | Military forces / invasion | 1 | Invasion battles, galactic war progress |
| `quest_discovery` | Finding clues / evidence | 1 | Quest progress, rumors, data files |
| `world_arrival` | New planet from orbit | 2 | New world arrival, world traits |
| `space_travel` | Starship in transit | 2 | Travel events, down-time, cosmic phenomenon |
| `trade_shady` | Back-alley deal / suspicious goods | 1 | Contraband, odd device, military surplus |
| `red_zone` | Dangerous war-torn zone | 1 | Red Zone missions |
| `black_zone` | Deep space / void operations | 1 | Black Zone missions |
| `loot_discovery` | Opening crate / examining find | 1-2 | Loot table results, battlefield finds, rewards |
| `story_event_NN` | Per-story-event (7 unique) | 7 total | Story Track events 1-7 |

**Total: ~50-60 scene paintings + 7 story event paintings ≈ 57-67 illustrations**

### JSON Schema Extension

Add to existing event JSON files (all fields optional, backward-compatible):

```json
{
  "art_tag": "starport_market",
  "art_side": "right",
  "advisor_role": "broker",
  "advisor_mood": "warning",
  "atmosphere_tags": ["market", "crowded", "alien"],
  "narrative_opener": null,
  "skip_narrative": false
}
```

---

## 4. Advisor System — Crew As Characters

When a narrative event fires, the system checks if any crew member has a relevant **advisory role**. That crew member's portrait appears with a procedurally generated reaction quote.

### Advisory Roles

| Role | Training Match | Class Match | Species Bonus | Triggers On |
|------|---------------|-------------|---------------|-------------|
| **Broker** | Broker Training | Merchant | — | trade_shady, patron_meeting, contraband |
| **Medic** | Medical School | Doctor, Technician | Engineer (repairs) | ship_interior_medbay, battle_aftermath_retreat |
| **Fighter** | Security Training | Soldier, Bounty Hunter, Enforcer | K'Erin | battle_aftermath, rival_encounter, wilderness_approach |
| **Tech** | Mechanic Training | Technician, Hacker, Scientist | Engineer | ship_interior_damaged, crash_site, industrial_zone |
| **Scout** | Pilot Training | Explorer, Scavenger, Primitive | Feral, Swift | wilderness_approach, world_arrival, quest_discovery |
| **Social** | — | Entertainer, Diplomat | Manipulator, Empath, Precursor | starport_bar, character_social, patron_meeting |

### Advisor Selection Priority

1. Crew member with matching **training** (highest priority — they earned this)
2. Crew member with matching **class**
3. Crew member with matching **species bonus**
4. If multiple candidates: prefer captain > highest Savvy > random
5. If no match: no advisor shown (some events are better without commentary)

### Species Personality Flavors (from Core Rules lore)

| Species | Personality | Source |
|---------|-------------|--------|
| **K'Erin** | Always wants to fight. Challenges = insults to honor. | "Proud and warlike aliens with a penchant for brutality and a peculiar sense of honor" |
| **Engineer** | Technical fixation. Comments on machinery first. | "Innate talent for interfacing with machinery" |
| **Precursor** | Cryptic, philosophical. Cosmic patterns. | "Enlightened beyond the likes of you and me" |
| **Soulless** | Analytical, unsettling. Hive-mind references. | "Connected to a hive-mind. It's like having 20 million friends" |
| **Feral** | Instinctive, sensory. Smells, sounds, movement. | "Humanoid-animal hybrids, originally engineered for military purposes" |
| **Swift** | Excitable, quick observations. Chirping. | "Erratic, jerky motions... the chirping sound — they make that all day long" |
| **Manipulator** | Political, calculating. Always working angles. | "Renowned for talents at communication and large-scale political machinations" |
| **Traveler** | Eerily knowing. Hints at foreknowledge. | "Claiming they are not really from this moment in space and time" |
| **Hulker** | Blunt, physical. Solves problems with strength. | "Bulging with muscles and rage, perfect for hauling, crushing, and breaking" |
| **De-converted** | Haunted, wary. Flinches at cybernetics. | "A prisoner of the Converted... rescued before the control chips could be inserted" |
| **Empath** | Reads the room. Comments on emotional states. | "Minor psionic inclination allowing the easy reading of emotional states" |
| **Hopeful Rookie** | Wide-eyed, optimistic. Everything is exciting. | "Wide-eyed and enthusiastic, you almost feel bad for this kid" |

### Quote Structure

Each advisory role has three quote pools:
- **Positive** — when the event outcome is good (credits, XP, loot, allies)
- **Warning** — when the event involves risk (rivals, injury, loss, combat)
- **Neutral** — when the event is mundane (no effect, cosmetic, minor)

Quotes are 1-2 sentences, written in character voice. Examples:

**Broker (positive):** "I know someone who deals in these. Could be worth triple on the right world."  
**Broker (warning):** "Those markings are Unity military. Could be trouble."  
**K'Erin Fighter (positive):** "Good fight. They won't be coming back."  
**K'Erin Fighter (warning):** "We are outnumbered. But that has never stopped a K'Erin."  
**Precursor Scout (neutral):** "The patterns of this place are... familiar. As if we were meant to come here."  
**Hopeful Rookie (any):** "This is amazing! Is it always like this?" / "Wait, that's bad, right?"  
**Soulless Tech (positive):** "The collective concurs: this is an optimal outcome."

---

## 5. Procedural Narrative Text

The Core Rules descriptions (1-3 sentences) are the **sacred text** — never altered, never fabricated. The narrative layer wraps them with atmospheric flavor:

```
[ATMOSPHERE OPENER]      — procedural, based on world + crew state
[CORE RULES DESCRIPTION] — verbatim from the book
[ADVISOR REACTION]       — procedural, based on crew member personality
```

### Atmosphere Openers

Generated from: current world name, world trait, art_tag, crew state.

**Ship Interior openers:**
- "The recycled air aboard the ship carries its usual metallic tang."
- "Somewhere in the ship's guts, a pipe rattles with the rhythm of an old engine."
- "The overhead lights flicker — another power coupling that needs attention."
- "The hum of the Svensen drive fills the silence between conversations."

**Starport openers:**
- "The starport on [world_name] is like every other — crowded, loud, and smelling of engine grease and alien cooking."
- "Docking fees paid, your crew steps out into the press of bodies and commerce."
- "The market stalls stretch in every direction, a maze of salvage and stolen goods."
- "Somewhere nearby, a Unity recruitment poster peels from a rust-stained wall."
- "A K'Erin merchant argues prices with a Soulless trader. Neither seems to be winning."

**Wilderness openers:**
- "Beyond the settlement perimeter, [world_name] stretches to the horizon."
- "The terrain here hasn't been mapped properly. Typical Fringe cartography."
- "Your boots crunch on unfamiliar ground. The air tastes different on every world."
- "Somewhere out there, something is watching. You can feel it."

**Battle aftermath openers:**
- "The dust is still settling. Somewhere, a weapon hisses as it cools."
- "Silence, finally. The kind that follows violence."
- "Your crew moves through the aftermath, checking corners out of habit."
- "The locals are already emerging from cover. They've seen this before."

**Space travel openers:**
- "The stars outside the viewport blur into streaks as the Svensen drive engages."
- "Three days in Tunnel space. Nothing but the hum of the drive and the tick of the nav computer."
- "The ship settles into the familiar rhythm of transit. Time to catch up on maintenance."
- "Somewhere between worlds, the universe feels smaller. Just you and the void."

### World Trait Modifiers

Appended to openers when the current world has a trait:

| Trait | Addition |
|-------|----------|
| Haze | "The ever-present haze turns everything past fifty meters into grey suggestions." |
| Frozen | "Frost clings to every surface. Your breath hangs in the air like smoke." |
| Barren | "Nothing grows here. The landscape is naked rock and dust." |
| Rampant crime | "A pair of enforcers watch from a rooftop. Nobody makes eye contact." |
| Warzone | "Blast craters mark the street. This place has seen better decades." |
| Overgrown | "Vegetation pushes through every crack. The planet is reclaiming its cities." |
| Fog | "Fog rolls in thick. Visibility is an optimistic word." |
| Crystals | "Strange crystalline formations catch the light, casting prismatic shadows." |
| Flat | "The terrain is featureless to the horizon. Nowhere to hide." |
| Heavily enforced | "Unity patrol bots sweep the streets in formation. The locals keep their heads down." |
| Dangerous | "This world has teeth. Even the locals carry weapons." |
| Corporate state | "Corporate logos are everywhere. Someone owns this world, and they don't let you forget it." |

---

## 6. Phase-by-Phase Narrative Mapping

### STORY Phase
**Mode**: Full Narrative  
**Art**: `story_event_NN` (7 unique paintings)  
**Content**: Story Track events already have `narrative_intro` and `narrative_briefing` in JSON — they ARE KoDP events. Just display them in NarrativeScreen.

### TRAVEL Phase
**Mode**: Decision (Management) → Travel Event (Narrative)  
**Art**: `space_travel`, `crash_site`, `starport_docks`  
**Content**: D100 Starship Travel Events (asteroids, raids, distress calls, cosmic phenomena). These are the richest narrative events in the book.

### UPKEEP Phase
**Mode**: Management (normal) → Narrative (failure only)  
**Art**: `ship_interior_crew`, `ship_cargo`, `starport_docks`  
**Content**: Normal upkeep is a quick payment screen. Failure triggers sell-for-upkeep, crew lockout, dismiss, or ship seizure — each as a narrative moment.

### WORLD — CREW TASKS Phase
**Mode**: Full Narrative (every task result is an event)  
**Art**: `starport_market`, `starport_bar`, `starport_street`, `trade_shady`, `wilderness_approach`  
**Content**: Trade table (50 entries) + Exploration table (50 entries). This is the bulk of narrative events. CrewTaskEventDialog's 26 event types expand to full NarrativeScreen.

### WORLD — JOB OFFERS Phase
**Mode**: Full Narrative  
**Art**: `patron_meeting` (2 variants — formal and informal)  
**Content**: Patron type, danger pay, time frame, benefits/hazards/conditions. Advisor evaluates the deal.

### BATTLE Phase (Pre/During/Post)
**Pre-Battle**: Narrative (mission briefing with terrain art)  
**During**: Tabletop companion (text instructions, not narrative)  
**Post-Battle**: Series of narrative beats (14 steps, ~3-5 as full NarrativeScreen, rest as management)

### CHARACTER EVENT Phase
**Mode**: Full Narrative  
**Art**: `character_personal`, `character_social`, `ship_interior_crew`, `starport_bar`  
**Content**: 30 D100 Character Events — the emotional heart of the game. Each event is a complete illustrated scene.

### ADVANCEMENT Phase
**Mode**: Management  
**Content**: XP spending is satisfying crunch. Optional: brief training montage opener on upgrade.

### END/RETIREMENT Phase
**Mode**: Brief Narrative → Management (save)  
**Art**: `space_travel` or `world_arrival`  
**Content**: Turn summary as narrative prose, then stats and save.

---

## 7. Art Requirements Summary

### For Modiphius (Art Assets Ask)

**Scene Illustrations: ~57-67 paintings**
- Dimensions: 2048×1024 px (2:1 landscape), PNG, 2x for retina
- Style: Painted/illustrated (match Five Parsecs book interior art by Christian Quinot)
- Rule: Depict situations, not specific player characters
- Tone: Gritty sci-fi mercenary — dingy ships, alien bazaars, war-torn worlds
- Delivery: Layered PSD/TIFF preferred (allows text overlay positioning)

| Category | Count | Priority |
|----------|-------|----------|
| Ship interiors (crew, bridge, medbay, cargo, damaged) | 8-10 | HIGH |
| Starport scenes (market, bar, street, docks) | 8-10 | HIGH |
| Terrain approaches (wilderness, urban, industrial, ruins, wasteland, crash) | 8-10 | HIGH |
| Battle aftermath (victory, retreat) | 2-3 | MEDIUM |
| Character moments (personal, social, training) | 5-6 | MEDIUM |
| Story-specific (patron, rival, war, quest, loot) | 7-8 | MEDIUM |
| Travel/world (space, arrival, trade shady) | 5-6 | MEDIUM |
| Story Track events (7 unique) | 7 | HIGH |
| Red/Black Zone | 2 | LOW |

**Character Portraits: ~30-50 images**
- Dimensions: 512×512 px (square), PNG
- Need species variety: Human (diverse), K'Erin, Engineer, Precursor, Soulless, Feral, Swift, Bot, Krag, Skulker, Hulker, De-converted, Manipulator, Traveler, Empath, Primitive
- Potential source: Titan Forge mini renders with painted post-processing
- Need: neutral expression (usable across positive/warning/neutral contexts)

**Art Direction Guide needed from Modiphius:**
- Color palette (to complement Deep Space theme: #1A1A2E, #252542, #2D5A7B)
- Tone references ("do"/"don't" examples)
- Brand consistency guidelines for Five Parsecs visual identity
- Whether Christian Quinot (Compendium interior artist) is available/affordable

### Without Modiphius Art (Placeholder Strategy)

Until art arrives, the system works with:
1. **Gradient atmospheres** — themed ColorRect gradients (already exist in CrewTaskEventDialog)
2. **Procedural starfield** — simple particle effect for space scenes
3. **Colored initials portraits** — already exist in CharacterCard (8 deterministic colors)
4. **Community art** — CC-licensed sci-fi illustrations as temporary placeholders
5. **AI-generated concept art** — for internal prototyping only (cannot ship)

The design deliberately separates art from logic so the system works at every fidelity level.

---

## 8. Implementation Phases

### Phase 1: Foundation (No Art Required)
- Create `NarrativeScreen.gd` component
- Create `NarrativeTextGenerator.gd` (procedural openers)
- Add `art_tag` / `advisor_role` fields to event JSON files
- Create `AdvisorSystem.gd` (crew member → advisory role matching)
- Gradient/placeholder fallback art system
- Wire NarrativeScreen into CharacterPhasePanel (highest-impact first)

### Phase 2: Event Integration
- Wire NarrativeScreen into CrewTaskEventDialog (replace Window with full-screen)
- Wire into StoryPhasePanel (Story Track events)
- Wire into PostBattleSequence (campaign events, character events)
- Wire into TravelPhasePanel (travel events)
- Advisor quote pools (JSON-driven, ~180 quotes across 6 roles × 3 moods × ~10 quotes)

### Phase 3: Art Drop-In
- When Modiphius provides art: drop PNGs into `res://assets/narrative/{art_tag}.png`
- Multiple variants per tag: `{art_tag}_01.png`, `{art_tag}_02.png` (random selection)
- Character portraits: drop into `res://assets/portraits/{species}_{variant}.png`
- No code changes needed — the fallback system detects presence automatically

### Phase 4: Polish
- Typewriter text effect (optional, accessibility toggle)
- Illustration parallax (subtle Ken Burns effect on paintings)
- Transition animations between management/narrative modes
- Sound design hooks (ambient audio per art_tag category)
- Steam screenshot optimization (NarrativeScreen is the screenshot-worthy screen)

---

## 9. Comparable Games — Art Budget Reference

| Game | Scene Illustrations | Events | Ratio | Notes |
|------|-------------------|--------|-------|-------|
| King of Dragon Pass | ~430 | ~600 | 0.72:1 | Multiple artists, multiple styles |
| Six Ages: Ride Like the Wind | ~325 | ~490 | 0.66:1 | Refined from KoDP |
| Five Parsecs Digital (target) | ~60-70 | ~200+ | 0.30:1 | Higher reuse via art_tag system |

The lower ratio is achievable because Five Parsecs events are more mechanical than narrative — a "marketplace" painting works for 6+ different trade events. KoDP needed more variety because its events are narratively unique.

---

## 10. Key Design Rules

1. **Core Rules text is sacred.** Never modify, abbreviate, or "improve" the rulebook descriptions. They ARE the game. The narrative layer wraps them, never replaces them.

2. **Art depicts situations, not characters.** This is the KoDP multiplier — one painting of "a trader at a ship" works for 5 different trade events with different text.

3. **Advisor quotes are flavor, not mechanics.** They never affect game state. They exist to make the crew feel like characters, not stat blocks.

4. **Management mode stays clean.** Don't narrativize XP spending, equipment assignment, or stat management. Those are satisfying crunch moments that work better as dashboards.

5. **Every narrative moment must be skippable.** Accessibility and replay require a "Skip" option. Power users who've seen the events 50 times need to be able to blow through them.

6. **The system works without art.** Gradient fallbacks, colored initials, and text-only mode must all be fully functional. Art enhances; it doesn't gate.

7. **Species personality is derived from Core Rules only.** No fabricated personality traits. Every species flavor quote must trace back to a specific rulebook passage.
