# Five Parsecs Campaign Manager - Development Guide

**Last Updated**: 2026-03-27
**Engine**: Godot 4.6-stable (non-mono, pure GDScript)
**Repository**: https://github.com/Reptarus/five-parsecs-campaign-manager

---

## Environment

```
PROJECT_ROOT: c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager
GODOT_CONSOLE: C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe
GODOT_VERSION: 4.6-stable (non-mono, pure GDScript)
MAIN_SCENE: res://src/ui/screens/mainmenu/MainMenu.tscn
```

Note: The Godot folder IS named `*.exe` (it's a directory containing executables inside).

---

## Project Status (March 2026)

| Metric | Value |
|--------|-------|
| Game Mechanics Compliance | **100%** (170/170 mechanics) |
| Core Rules Systems | 11/11 verified |
| Campaign Turn Phases | 9/9 fully wired |
| Campaign Creation | 7-phase coordinator system |
| Bug Hunt Gamemode | Phases 1-7 complete (38 files) |
| Store/Paywall System (Phase 24) | Tri-platform (Steam/Android/iOS) |
| Script Consolidation (Phase 5) | 9/9 sprints complete |
| World→Battle Data Flow (Phase 21) | 3 sub-phases complete |
| Functional Gaps Cleanup | 7/7 sprints (F-1 to F-7) |
| Compile Errors | 0 |
| GDScript Files | ~900 (excl. addons) |

---

## Architecture Overview

### Campaign Creation Flow (7 Phases)
```
MainMenu → CampaignCreationUI → CampaignDashboard
  Step 1: CONFIG (ExpandedConfigPanel)
  Step 2: CAPTAIN_CREATION (CaptainPanel + CharacterCreator)
  Step 3: CREW_SETUP (CrewPanel)
  Step 4: EQUIPMENT_GENERATION (EquipmentPanel)
  Step 5: SHIP_ASSIGNMENT (ShipPanel)
  Step 6: WORLD_GENERATION (WorldInfoPanel)
  Step 7: FINAL_REVIEW (FinalPanel)
```
Orchestrated by `CampaignCreationCoordinator` with `CampaignCreationStateManager`. CampaignCreationUI.gd is a thin shell (~161 lines) that wires panels to the coordinator.

### Campaign Turn Flow (9 Phases)
```
STORY -> TRAVEL -> UPKEEP -> MISSION -> POST_MISSION -> ADVANCEMENT -> TRADING -> CHARACTER -> RETIREMENT
```
Each phase has a dedicated panel wired into `CampaignPhaseManager` -> `CampaignTurnController` with completion signals and data handoff.

### PostBattlePhase Subsystem Architecture (Phase 33)
```
PostBattlePhase.gd (296-line orchestrator, emits all 19 signals)
  └─ post_battle/
     ├─ PostBattleContext.gd      — DI hub (campaign, managers, battle result)
     ├─ RivalPatronResolver.gd    — Steps 1-3 (rival/patron/quest)
     ├─ PaymentProcessor.gd       — Steps 4-6 (pay, finds, invasion)
     ├─ LootProcessor.gd          — Step 7
     ├─ InjuryProcessor.gd        — Step 8
     ├─ ExperienceTrainingProcessor.gd — Steps 9-11
     ├─ CampaignEventEffects.gd   — Step 12 (80-case match)
     ├─ CharacterEventEffects.gd  — Step 13 (60-case match)
     ├─ GalacticWarProcessor.gd   — Step 14a
     └─ PostBattleCompletion.gd   — Step 14b (stats, journal, morale)
```
Subsystems are RefCounted (not Node), return data to orchestrator which emits signals. Zero `.emit()` calls in subsystems.

### WorldPhaseComponent Base Class (Phase 33)
All 9 world phase components extend `WorldPhaseComponent` with:
- Event bus auto-cleanup via `_subscribe()` + `_event_subscriptions` tracking
- `TOUCH_TARGET_MIN` constant (48px) for mobile UX
- `_help_dialog` + `_show_help_dialog()` shared utility
- Virtual hooks: `_subscribe_to_events()`, `_connect_ui_signals()`, `_setup_initial_state()`

### Bug Hunt Gamemode (Compendium)

Standalone military-themed variant with 3-stage turn, separate from the 9-phase campaign.

```
MainMenu → BugHuntCreationUI (4-step wizard) → BugHuntDashboard → BugHuntTurnController
  Stage 1: SPECIAL_ASSIGNMENTS (SpecialAssignmentsPanel)
  Stage 2: MISSION (BugHuntMissionPanel → TacticalBattleUI in bug_hunt mode)
  Stage 3: POST_BATTLE (BugHuntPostBattlePanel)
```

- **BugHuntCampaignCore** (Resource): Separate from FiveParsecsCampaignCore — no ship, no patrons/rivals
- **BugHuntPhaseManager**: 3-stage turn orchestration (vs 9-phase CampaignPhaseManager)
- **TacticalBattleUI** reused with `battle_mode: "bug_hunt"` (hides morale, adds ContactMarkerPanel)
- **CharacterTransferService**: Bidirectional transfer (5PFH ↔ Bug Hunt) with enlistment rolls
- **GameState.load_campaign()**: Uses `_detect_campaign_type()` to peek at save file JSON `campaign_type` field, routing to `FiveParsecsCampaignCore` (default) or `BugHuntCampaignCore` loader. Legacy saves without the field default to standard 5PFH.
- **SceneRouter keys**: `bug_hunt_creation`, `bug_hunt_dashboard`, `bug_hunt_turn_controller`
- **15 JSON data files** in `data/bug_hunt/`, **23 GDScript/TSCN files** across `src/`

### Battle Simulator (Standalone Battles)

Standalone battle mode accessible from MainMenu — no campaign required. Ungated for demo (DLC gating planned).

```
MainMenu → "Battle Simulator" button
  └─ SceneRouter.navigate_to("battle_simulator")
       └─ BattleSimulatorUI (thin shell, code-built)
            ├─ BattleSimulatorSetupPanel (single-screen config)
            │   ├─ Crew Size (3-6), Enemy Category/Type, Mission, Difficulty
            ├─ TacticalBattleUI (instantiated on launch from .tscn)
            └─ BattleSimulatorResultsPanel (shown after battle)
```

- **BattleSimulatorSetup.gd** (RefCounted): Loads `enemy_types.json` + `mission_templates.json`, generates lightweight crew dicts + enemy squads
- **Crew uses minimal dicts** (not Character resources) — `TacticalBattleUI.TacticalUnit` handles both
- **Critical timing**: `initialize_battle()` must be called sync after `add_child()` — TacticalBattleUI `call_deferred("_check_standalone_mode")` fires otherwise
- **Results don't persist** — no campaign to save to, just Play Again / Main Menu
- **SceneRouter key**: `battle_simulator`

### Battle Phase Manager
The battle system is a **tabletop companion assistant** (NOT a tactical simulator). All output is TEXT INSTRUCTIONS for the player to execute on the physical tabletop. Three-tier tracking: LOG_ONLY / ASSISTED / FULL_ORACLE.

### Key Patterns (Phase 5 Consolidation)
- **CampaignDashboard** uses `FiveParsecsCampaignPhase` (14 values, aliased as `FPC`). The old `CampaignPhase` enum (10 values) is deprecated.
- **BattlePhase._simulate_battle_outcome()** delegates to `BattleResolver.resolve_battle()` for rules-accurate combat.
- **VictoryChecker.gd** — centralized victory condition checking (18 types), used by EndPhasePanel.
- **character_events.gd** — character phase event data/logic, used by CharacterPhasePanel.
- **DeploymentManager** has static `infer_deployment_type()` and `infer_terrain_features()` methods.
- **EquipmentManager** has `get_sell_value()` for condition-aware resale pricing.

### Three Enum Systems (CRITICAL - Must Stay In Sync)
1. `src/core/systems/GlobalEnums.gd` — autoloaded as `GlobalEnums`
2. `src/core/enums/GameEnums.gd` — class_name `GameEnums`
3. `src/game/campaign/crew/FiveParsecsGameEnums.gd` — CharacterClass only

### Character Data Model
- Canonical: `src/core/character/Character.gd` (class_name `Character`, ~1,900 lines)
- Base: `src/core/character/Base/Character.gd` (class_name `BaseCharacterResource`, extends Resource)
- Thin redirects: `game/character/Character.gd` -> extend Character
- API stub: `character_base.gd`
- **Stats are flat properties**: `combat`, `reaction`, `toughness`, `speed`, `savvy`, `luck` (NO `stats` sub-object)
- `CharacterStats.gd` exists as a separate Resource but is NOT used as a property on characters
- Implants: 11 types (Core Rules p.55), max 2 per character. `Character.create_implant_from_loot()` does name-match scan (no separate map constant)

### BaseCharacterResource Combat Interface (Session 10)

`BaseCharacterResource` implements the full `CombatResolver` interface contract (22 methods + 13 properties). Methods delegate to existing data:

- `get_equipped_weapon()` → returns `weapons[0]` as Dictionary
- `get_combat_skill()` → returns `combat` stat
- `get_speed()` → returns `speed` stat
- `apply_damage(amount)` / `heal_damage(amount)` → modify health, mark wounded/dead
- `is_mechanical()` → returns `is_bot`
- Status checks (`is_suppressed`, `is_pinned`, `has_overwatch`) → scan `active_effects` array
- Property aliases: `name`→`character_name`, `bot`→`is_bot`, `soulless`→`is_soulless`
- Transient battle state: `_action_points`, `_combat_modifiers`, `_active_ability`, `_ability_cooldowns`
- `reset_battle_state()` clears transient state between rounds

### DLC/Compendium System
- 33 ContentFlags across 3 DLC packs (Trailblazer's Toolkit=7, Freelancer's Handbook=17, Fixer's Guidebook=9)
- DLC gating pattern:
```gdscript
var dlc = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
if dlc and dlc.is_feature_enabled(dlc.ContentFlag.SOME_FLAG):
    # DLC-gated code
```

### Store/Paywall System (Phase 24)
Tri-platform DLC purchase system using adapter pattern:
```
StoreManager (autoload) → StoreAdapter (abstract base)
  ├─ SteamStoreAdapter    → Engine.get_singleton("Steam") + steamInitEx()
  ├─ AndroidStoreAdapter  → Engine.get_singleton("AndroidIAPP")
  ├─ IOSStoreAdapter      → ClassDB.instantiate("StoreKitManager")  ← NOT a singleton!
  └─ OfflineStoreAdapter  → Fallback for editor/dev mode
```
- **Product IDs**: All in `StoreManager.gd` `PRODUCT_IDS` const — placeholder, swap before release
- **Plugins installed**: GodotSteam (addons/godotsteam/), GodotApplePlugins (addons/GodotApplePlugins/), AndroidIAPP (addons/AndroidIAPP/ + android_IAPP/)
- **Purchase flow**: StoreManager.purchase_dlc() → Adapter.purchase() → purchase_completed signal → DLCManager.set_dlc_owned()
- **Autoload timing**: Adapters use `load()` not `preload()`, path-based `extends` (not class_name)
- **iOS quirk**: `purchase()` takes a `StoreProduct` object (cached from query), not a string ID
- **Android quirk**: Product IDs passed as arrays: `purchase(["pid"], false)`, must acknowledge within 3 days
- **Steam quirk**: Opens store overlay for purchase, ownership via `isDLCInstalled(app_id: int)`

### Review System (Phase 25)

Cross-platform in-app review prompts via ReviewManager autoload:

- **Android/iOS**: InappReviewPlugin (`Engine.has_singleton("InappReviewPlugin")`) — 2-step flow: `generate_review_info()` → `launch_review_flow()`
- **Steam**: Opens store page via overlay (`activateGameOverlayToWebPage()`)
- **Offline**: No-op
- **Timing**: MIN_TURNS_BEFORE_REVIEW=5, REVIEW_COOLDOWN_DAYS=30, persisted to `user://review_prefs.cfg`
- **InappReviewPlugin file layout**: plugin.cfg + .gd in `addons/InappReviewPlugin/`, AARs in `InappReviewPlugin/bin/` (project root)
- **class_name collision fix**: Root copy `InappReviewPlugin/InappReview.gd` has NO class_name; `addons/` copy retains it

---

## Key Autoloads (from project.godot)

| Autoload | Path | Purpose |
|----------|------|---------|
| GlobalEnums | src/core/systems/GlobalEnums.gd | Shared enum definitions |
| GameState | src/core/state/GameState.gd | Campaign state singleton |
| GameStateManager | src/core/managers/GameStateManager.gd | State mutation helper |
| GameDataManager | src/core/managers/GameDataManager.gd | Data loading |
| DataManager | src/core/data/DataManager.gd | Data persistence |
| DLCManager | src/core/systems/DLCManager.gd | DLC feature flags |
| StoreManager | src/core/store/StoreManager.gd | Platform store adapter bridge |
| ReviewManager | src/core/store/ReviewManager.gd | Cross-platform in-app review prompts |
| DiceManager | src/core/managers/DiceManager.gd | Dice rolling |
| SceneRouter | src/ui/screens/SceneRouter.gd | Scene transitions |
| EquipmentManager | src/core/equipment/EquipmentManager.gd | Equipment operations |
| CampaignPhaseManager | src/core/campaign/CampaignPhaseManager.gd | Turn phase orchestration |
| CampaignJournal | src/core/campaign/CampaignJournal.gd | Auto-entries, timeline |
| TurnPhaseChecklist | src/core/campaign/TurnPhaseChecklist.gd | Phase completion tracking |
| LegacySystem | src/core/campaign/LegacySystem.gd | Campaign archival |
| NPCTracker | src/core/campaign/NPCTracker.gd | NPC tracking |
| KeywordDB | src/autoload/KeywordDB.gd | Keyword tooltips |
| PlanetDataManager | src/core/world/PlanetDataManager.gd | Planet persistence |
| PlanetCache | src/core/world/PlanetCache.gd | Planet data cache |
| WorldEconomyManager | src/core/world/WorldEconomyManager.gd | World economy |
| ResourceSystem | src/core/systems/ResourceSystem.gd | Resource management |
| TweenFX | addons/TweenFX/TweenFX.gd | Animation addon (70 animations, auto-lifecycle) |
| GalacticWarManager | src/core/campaign/GalacticWarManager.gd | Galactic war progress tracking |
| FactionSystem | src/core/systems/FactionSystem.gd | Faction/rival management + DLC expanded factions |

---

## UI Design System - Deep Space Theme

**Source**: `src/ui/screens/campaign/panels/BaseCampaignPanel.gd`
**Project Theme**: `src/ui/themes/sci_fi_theme.tres` (set in `project.godot` → `gui/theme/custom`)
**Fonts**: Montserrat-Regular (body), Montserrat-SemiBold (buttons), Montserrat-Bold (titles), CourierPrime-Regular (monospace)
**Max Form Width**: `BaseCampaignPanel.MAX_FORM_WIDTH := 800` (centered on wide screens via `_apply_content_max_width()`)
**Portrait Avatars**: `CharacterCard._update_portrait()` prefers `portrait_path`, falls back to colored initials (8 deterministic colors from name hash)

### Spacing (8px Grid)
```gdscript
SPACING_XS := 4   # Icon padding, label-to-input gap
SPACING_SM := 8   # Element gaps within cards
SPACING_MD := 16  # Inner card padding
SPACING_LG := 24  # Section gaps between cards
SPACING_XL := 32  # Panel edge padding
```

### Touch Targets
```gdscript
TOUCH_TARGET_MIN := 48      # Minimum interactive element height
TOUCH_TARGET_COMFORT := 56  # Comfortable input height
```

### Typography
```gdscript
FONT_SIZE_XS := 11  # Captions, limits
FONT_SIZE_SM := 14  # Descriptions, helpers
FONT_SIZE_MD := 16  # Body text, inputs
FONT_SIZE_LG := 18  # Section headers
FONT_SIZE_XL := 24  # Panel titles
```

### Color Palette
```gdscript
# Backgrounds
COLOR_BASE := Color("#1A1A2E")         # Panel background
COLOR_ELEVATED := Color("#252542")     # Card backgrounds
COLOR_INPUT := Color("#1E1E36")        # Form field backgrounds
COLOR_BORDER := Color("#3A3A5C")       # Card borders

# Accent
COLOR_ACCENT := Color("#2D5A7B")       # Primary accent (Deep Space Blue)
COLOR_ACCENT_HOVER := Color("#3A7199") # Hover state
COLOR_FOCUS := Color("#4FC3F7")        # Focus ring (cyan)

# Text
COLOR_TEXT_PRIMARY := Color("#E0E0E0")   # Main content
COLOR_TEXT_SECONDARY := Color("#808080") # Descriptions
COLOR_TEXT_DISABLED := Color("#404040")  # Inactive

# Status
COLOR_SUCCESS := Color("#10B981")  # Green
COLOR_WARNING := Color("#D97706")  # Orange
COLOR_DANGER := Color("#DC2626")   # Red
```

### BBCode Colors for RichTextLabel
```gdscript
"[color=#10B981]Success[/color]"  # Green
"[color=#D97706]Warning[/color]"  # Orange
"[color=#DC2626]Error[/color]"    # Red
```

### Helper Methods (panels extending FiveParsecsCampaignPanel)
- `_create_section_card(title, content, description)` - Styled card container
- `_create_labeled_input(label_text, input)` - Label + input pair
- `_create_stat_display(stat_name, value)` - Stat badge
- `_create_stats_grid(stats, columns)` - Grid of stat displays
- `_create_character_card(name, subtitle, stats)` - Character display
- `_style_line_edit(line_edit)` - Apply styling to LineEdit
- `_style_option_button(option_btn)` - Apply styling to OptionButton

---

## Testing

### Frameworks
- **gdUnit4** v6.0.3 — primary test framework
- GUT addon was **removed** (Feb 2026); ~20 test files still need migration

### Test Directories
```
tests/unit/          # Unit tests (~178 files)
tests/integration/   # Integration tests (~54 files)
tests/battle/        # Battle-specific tests
tests/performance/   # Performance benchmarks
tests/mobile/        # Mobile-specific tests
tests/fixtures/      # Test helpers and factories
```

### Headless Verification (compile check)
```powershell
& "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --headless --quit --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" 2>&1
```

### Running Tests
```powershell
& "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" `
  --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_character_advancement_costs.gd `
  --quit-after 60
```

---

## Development Patterns

### Autoload Null-Guard
```gdscript
var system = get_node_or_null("/root/SystemName")
if system and system.has_method("some_method"):
    system.some_method()
```

### Resource Class Instantiation
Non-Node classes (extending Resource/RefCounted) must be instantiated with `.new()`:
```gdscript
var story_track = FPCM_StoryTrackSystem.new()
var battle_events = FPCM_BattleEventsSystem.new()
```

### Preload Pattern for UI Class References
```gdscript
const MyPanelClass = preload("res://src/ui/components/MyPanel.gd")
var panel = MyPanelClass.new()
```

### Signal Architecture
- Parent calls down to child (direct method calls)
- Child signals up to parent (`signal_name.emit()`)
- Phase panels emit `phase_completed` signal with completion data
- Campaign creation panels emit typed signals; CampaignCreationUI uses lambda adapters to convert to Dict format for coordinator

### Campaign Creation Coordinator Pattern
```gdscript
# CampaignCreationUI wires panels to coordinator:
coordinator.navigation_updated.connect(_on_navigation_updated)
coordinator.step_changed.connect(_on_step_changed)

# Panel signal adapters (Control-based panels → Dict format):
panel.captain_updated.connect(func(captain): coordinator.update_captain_state({"captain": captain}))
```

---

## Agent & Skill Architecture (Token Optimization)

Seven specialized agents with three-tier model routing to minimize token usage on routine tasks:

| Agent | Model | Domain |
| ----- | ----- | ------ |
| `fpcm-project-manager` | **opus** | Orchestration, task decomposition, cross-agent coordination |
| `battle-systems-engineer` | **opus** | Battle state machine, combat resolution, deployment, victory |
| `campaign-systems-engineer` | **sonnet** | Campaign creation/turns, save/load, state management |
| `character-data-engineer` | **sonnet** | Character model, enums, JSON data, equipment, world |
| `bug-hunt-specialist` | **sonnet** | Bug Hunt gamemode, cross-mode safety |
| `qa-specialist` | **sonnet** | Testing, QA, gdUnit4 |
| `ui-panel-developer` | **haiku** | UI components, Deep Space theme, TweenFX |

### Agent Files

- **Agent definitions**: `.claude/agents/*.md` (7 files)
- **Agent memory**: `.claude/agent-memory/{agent-name}/MEMORY.md` (7 files, persistent across sessions)
- **Skills**: `.claude/skills/{skill-name}/SKILL.md` + `references/*.md` (7 skills, 22 reference files)
- **Token settings**: `MAX_THINKING_TOKENS=10000`, `AUTOCOMPACT_PCT=50` in `.claude/settings.local.json`

### Routing Rules

- Each agent owns specific files — route tasks by file ownership (see `.claude/skills/fpcm-project-management/references/agent-roster.md`)
- `character-data-engineer` exclusively owns all 3 enum files (three-enum sync rule)
- Multi-domain tasks → decompose via `fpcm-project-manager`
- `bug-hunt-specialist` reviews any shared file changes (TacticalBattleUI, GameState, SceneRouter)
- `qa-specialist` is always the final verification step
- Dependency order: data → campaign → battle → bug-hunt → UI → QA

---

## Dev Environment & Workflow

### Synology Drive Sync
Project lives in `SynologyDrive/` — background sync touches file timestamps, triggering phantom change events. Mitigated by Cursor `files.watcherExclude` and Godot `checkOnChange: false`.

### Godot Ports (from docs)

- **6005** — LSP (GDScript language server)
- **6006** — DAP (Debug Adapter Protocol)
- **6007** — Editor connection

### MCP Servers (`.mcp.json`)
Versions are **pinned** — do NOT change to `@latest` (causes npm downloads on every agent start). To update, run `npm view <package> version` and update the version string.

### Import Cache (`.godot/imported/`)
Godot never cleans orphaned cached imports. If the cache grows large (>600MB) or causes crashes, delete `.godot/imported/` — Godot regenerates it on next editor open.

### File Watcher Exclusions
Both `.vscode/settings.json` and Cursor user settings exclude: `.godot/`, `.mcp/`, `node_modules/`, `mcp-servers/`. The `.cursorignore` file additionally excludes `*.import` and `*.uid` from AI indexing.

### Python Tools

Python 3.14.2 is available via `py` launcher (NOT `python` — Windows app alias blocks that).
Installed PDF libraries:

- **PyPDF2** 3.0.1 — PDF text extraction, page manipulation
- **PyMuPDF** 1.27.1 (fitz) — Fast PDF rendering, text extraction, image extraction

Use for: extracting game data values from rulebook PDFs, verifying text extractions, batch PDF operations.
Example: `py -c "import fitz; doc = fitz.open('docs/rules/Five Parsecs From Home-Compendium.pdf'); print(doc[5].get_text())"`

---

## Data Integrity Rules

- **THE CORE RULES AND COMPENDIUM ARE THE CANONICAL AUTHORITY FOR ALL GAME MECHANICS.** Every mechanic name, stat value, table range, cost, probability, weapon property, species trait, and game term in this project MUST match the Core Rules and Compendium PDFs exactly. These books are the **default dictionary** — if the code says one thing and the book says another, the book is right and the code is wrong. No exceptions. No "balancing." No "improvements." The books define the game.
- **NEVER invent game data values**: When adding or modifying any numeric game data (stats, costs, ranges, probabilities, D100 table boundaries), the value MUST come from the Core Rules book. AI agents must ask the user for book values rather than guessing. Tag intentional deviations as `GAME_BALANCE_ESTIMATE`.
- **CHECK `data/RulesReference/` FIRST**: 18 JSON files extracted from the rulebooks/Compendium PDFs exist at `data/RulesReference/`. ALWAYS check these before inventing values. They cover: Bestiary, Campaign rules, Difficulty, Elite Enemies, Enemy AI, Equipment, Expanded Missions, Factions, Name Tables, Psionics, Salvage, Species, Stealth/Street, Terrain. If the data you need isn't in RulesReference, extract it from the PDF using Python (see Dev Environment).
- **Core Rules PDFs available in repo — USE THEM**: Both the Core Rulebook and Compendium PDFs are at `docs/rules/`:
  - `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf` — Core Rules 3e
  - `docs/rules/Five Parsecs From Home-Compendium.pdf` — Compendium
  - `docs/rules/core_rulebook.txt` — Text extraction of Core Rules
  - `docs/rules/compendium_source.txt` — Text extraction of Compendium
  - `docs/rules/5PCompendium/` — Compendium source directory
  - Text extractions may have OCR artifacts — verify against the PDF when precision matters
- **NEVER "fix" data without the book**: Phase 30 changed ship hull from 20-35 to 6-14, documenting it as a "Core Rules correction." The Core Rules actually says 20-40. The "fix" made it WORSE. Never assume a value is wrong without checking the source material.
- **NEVER create duplicate data sources**: If a value already exists in a JSON file, load it from there. Do not create a parallel constant in GDScript. Single Source of Truth: JSON file is canonical for each data domain.
- **All data changes require book page citation**: Include the Core Rules page number in commit messages when modifying game data. Example: `"Fix Infantry Laser range to 30" (Core Rules p.50)"`
- **Data Source Authority Hierarchy (absolute, no exceptions)**:
  1. **Core Rules PDF + Compendium PDF** — Word of God. Always right. Extract with `py -c "import fitz; ..."`
  2. `data/RulesReference/*.json` — Direct extractions from the PDFs. Trust these, but verify against PDF if suspicious
  3. Dedicated JSON data file in `data/` — May have errors introduced by agents
  4. GDScript constants file — Lowest code authority
  5. Inline hardcoded values — Least trustworthy, often wrong
  When sources disagree, the higher-authority source wins. ALWAYS.
- **Verification checklist**: See `docs/QA_RULES_ACCURACY_AUDIT.md` for the master verification checklist (745+ values across 131 files).

---

## Gotchas

- **`.exe` directory name**: The Godot installation folder IS named `*.exe` — this is a directory, not an executable
- **`replace_all` substring trap**: Short identifiers corrupt longer ones (e.g., replacing "HARD" also matches inside "HARDCORE"). Always check for substring collisions
- **`--headless --quit` is NOT comprehensive**: Only validates startup scripts. The Godot editor LSP loads ALL scripts. Always reboot editor after headless check
- **`class_name` + autoload conflict**: If a script has `class_name Foo` AND is registered as autoload "Foo", Godot 4.6 errors "Class hides an autoload singleton." Fix: remove `class_name` from autoloaded scripts
- **Godot 4.6 type inference**: `var x := untyped_array[i]` fails. Use explicit typing: `var x: Type = array[i]`
- **Two VictoryDescriptions files**: `src/core/victory/` (basic) and `src/game/victory/` (full, used by UI)
- **Explore agents can be wrong**: ALWAYS verify explore agent claims by reading actual files. Agents have claimed files were stubs when they were fully implemented
- **PowerShell for batch ops**: Bash `sed -i` doesn't work on Windows. Use PowerShell `-replace` with proper regex
- **Character stats are FLAT**: `BaseCharacterResource` has `combat`, `reaction`, `toughness`, `speed`, `savvy`, `luck` as direct properties. There is NO `stats` sub-object. `CharacterStats.gd` is a separate Resource class.
- **CharacterCreator.start_creation()**: Accepts `CreatorMode` enum (not bool). Has legacy bool compatibility.
- **FiveParsecsCampaignCore is Resource**: `campaign["key"] = val` silently fails. Use `progress_data["key"]` for runtime state. Use `"key" in campaign` instead of `.has("key")`
- **World phase components need refresh**: Initialized at `_ready()` with stale data. Must call `_refresh_*()` from `_show_current_step()` when entering each step
- **equipment_data key is `"equipment"`**: Ship stash is stored under `campaign.equipment_data["equipment"]`. Do NOT use `"pool"` — that was a systemic bug fixed in Phase 22
- **Character.to_dictionary() dual keys**: Returns both `"id"`/`"name"` AND `"character_id"`/`"character_name"` aliases. Always include both when manually creating crew dicts
- **PreBattleUI uses `setup_preview()`**: Not `initialize_battle()` or `set_mission_data()`. Also needs `setup_crew_selection()` for crew panel
- **Autoload timing with `load()` vs `preload()`**: Autoloads parse before import system. StoreManager uses `load()` at runtime for adapter scripts, and adapters use path-based `extends "res://path/to/script.gd"` instead of `extends ClassName`
- **GodotApplePlugins StoreKitManager is NOT a singleton**: Use `ClassDB.class_exists(&"StoreKitManager")` + `ClassDB.instantiate(&"StoreKitManager")`. Do NOT use `Engine.get_singleton()`
- **AndroidIAPP file layout**: `plugin.cfg` + `.gd` in `addons/AndroidIAPP/`, AARs (`.aar` files) in `android_IAPP/` at project root
- **Steam needs `steam_appid.txt`**: Place at project root with base game App ID. Without it, `steamInitEx()` returns status 1
- **Bug Hunt ↔ 5PFH campaign types are incompatible**: `BugHuntCampaignCore` has `main_characters`/`grunts` (flat Arrays), `FiveParsecsCampaignCore` has `crew_data["members"]` (nested Dict). Always validate `"main_characters" in campaign` before Bug Hunt code. `GameState.load_campaign()` currently only loads FiveParsecsCampaignCore — Bug Hunt uses separate SceneRouter-based loading
- **Bug Hunt temp_data keys use `"bug_hunt_*"` prefix**: `"bug_hunt_battle_context"`, `"bug_hunt_battle_result"`, `"bug_hunt_mission"`. Standard keys: `"world_phase_results"`, `"return_screen"`, `"selected_character"`. No collisions
- **TacticalBattleUI shared between both modes**: Bug Hunt code is guarded by `battle_mode == "bug_hunt"` and `_check_bug_hunt_launch()` validation. Standard flow unaffected
- **Bug Hunt equipment step auto-completes**: `BugHuntCreationCoordinator.go_to_step()` marks EQUIPMENT complete automatically since Bug Hunt uses standard issue (read-only panel). Without this, the Next button won't appear on step 3
- **CombatResolver `_validate_character_interface()`**: Runs in `_ready()` via `assert()`. Will crash if `BaseCharacterResource` is missing any of the 24 required methods. All 22 previously-missing methods were added in Session 10
- **TweenFX pivot_offset**: TweenFX NEVER sets `pivot_offset`. Must call `node.pivot_offset = node.size / 2` before any scale/rotation animation (`press`, `pop_in`, `pulsate`, `punch_in`, `breathe`, `tada`, `critical_hit`, `upgrade`, `attract`, `headshake`). Safe without: `fade_in`, `fade_out`, `blink`, `spotlight`, `alarm`, `shake`
- **TweenFX looping cleanup**: Looping animations (`alarm`, `breathe`, `attract`, `glow_pulse`) must be explicitly stopped with `TweenFX.stop(node, TweenFX.Animations.X)` or `TweenFX.stop_all(node)` in cleanup/hide code
- **TweenFX.tada() signature**: Takes only 2 args `(node, duration)` — no scale parameter
- **GameEnums ↔ GlobalEnums ordinal sync**: After the Mar 23 fix, shared enum members MUST have identical ordinal values. GameEnums-only extras use explicit `= N` values. Verify with MCP Scenario 9 after any enum changes
- **CampaignDashboard dict key fallbacks**: Crew reads `"origin"`/`"character_class"` with fallback to `"species"`/`"class"`. Equipment reads `"weapons"`/`"armor"`/`"gear"` but auto-decomposes from `"equipment"` if unified format found. Always `str()` wrap values assigned to String-typed vars (character_class may be int)
- **BasePhasePanel + BaseCampaignPanel auto-background**: Both inject a `COLOR_BASE` ColorRect in `_ready()` with `show_behind_parent = true`. Named `"__phase_bg"` / `"__panel_bg"` to prevent duplicates. New panels inheriting either base get correct background automatically
- **TransitionManager overlay blocks MCP screenshots**: `TransitionOverlay` (full-screen ColorRect) must be disabled (`visible = false`) for MCP take_screenshot to work during scene transitions. Safe to disable for automated testing
- **UI/UX issues tracker**: `docs/QA_UI_UX_ISSUES.md` — 30 issues found, 21 fixed, 9 deferred (card containers, dialog backdrop, max-width, disabled button contrast)
- **Project-wide theme**: `sci_fi_theme.tres` is set via `gui/theme/custom` in `project.godot`. All controls inherit fonts and styles unless overridden. Per-element `add_theme_*_override()` calls always take priority over the project theme
- **Legacy `5PFH.tres` theme removed from CampaignDashboard**: Was a sprite-based theme with empty textures and a different color palette. Dashboard now inherits the project-wide Deep Space theme
- **Bug Hunt panels extend Control (not BaseCampaignPanel)**: `BugHuntCreationUI` has its own `MAX_FORM_WIDTH` and `_apply_content_max_width()` since it doesn't inherit from BaseCampaignPanel
- **Portrait path existence check**: Use `ResourceLoader.exists()` for `res://` paths, `FileAccess.file_exists()` for `user://` paths. `FileAccess.file_exists()` fails for `res://` in exported PCK builds
- **CharacterCard portrait priority**: `_update_portrait()` checks `portrait_path` first (custom image), falls back to colored initials (8 deterministic colors from `name.hash() % 8`). IconRegistry class icons are no longer the default
- **CampaignDashboard ButtonContainer is HFlowContainer**: NOT GridContainer. Auto-wraps, no `columns` property to manage

---

## Agent Search Accuracy Protocol

Agents frequently return inaccurate search results — claiming files are stubs, missing code, or returning wrong locations. Follow these rules to mitigate:

### Prompt Specificity

- Use exact function/class names, not vague descriptions: `EquipmentManager.get_sell_value()` not "equipment pricing"
- Include file path hints: "search in `src/core/character/`" not "search for character code"
- Request structured output: `[file_path]:[line_number]: [exact code line]`

### Explore Agent Prompts

- Always specify `"very thorough"` thoroughness level unless doing a trivial single-file lookup
- Front-load structural context: key directories, known file paths, class names
- Tell the agent what NOT to do: "Do not assume a file is a stub without reading it fully"

### Verification (MANDATORY)

- After any agent search/explore, READ at least 1-2 claimed files to spot-check accuracy
- Never act on unverified search results — especially for routing decisions or code changes
- If verification fails, re-search with more specific prompts rather than trusting the original result

### Model Selection for Search Tasks

- Opus: best for cross-system searches, complex pattern matching
- Sonnet: good accuracy with specific, well-anchored prompts
- Haiku: lowest search accuracy — provide extra file path hints, limit search scope, always verify claims
- Do NOT use Haiku-model agents for search-heavy exploration tasks

---

## Key Documentation

- `docs/PROJECT_STATUS_2026.md` — Current project status
- `docs/GAME_MECHANICS_IMPLEMENTATION_MAP.md` — 100% compliance tracker (170/170)
- `docs/DOCUMENTATION_INDEX.md` — Documentation hub
- `tests/TESTING_GUIDE.md` — Test methodology (needs update for 4.6)

### QA Documentation Suite (Mar 2026)

| Document | Purpose |
|----------|---------|
| `docs/QA_STATUS_DASHBOARD.md` | Consolidated QA health — open bugs, coverage %, risk areas, next priorities |
| `docs/QA_CORE_RULES_TEST_PLAN.md` | All 170 mechanics mapped to test verification status |
| `docs/QA_INTEGRATION_SCENARIOS.md` | 9 end-to-end workflow scripts with MCP command templates |
| `docs/QA_UX_UI_TEST_PLAN.md` | Systematic theme/responsive/animation/accessibility coverage |

Update the dashboard and core rules plan after each QA sprint.
