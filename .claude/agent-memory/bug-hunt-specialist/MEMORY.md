# Bug Hunt Specialist — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: cross-mode isolation issues, data model mismatches, transfer bugs -->

## ABSOLUTE RULE: Core Rules & Compendium Are Word of God

The Compendium PDF at `docs/rules/Five Parsecs From Home-Compendium.pdf` is the canonical authority for all Bug Hunt mechanics. If code disagrees with the book, the code is wrong.

---

## Critical Gotchas — Must Remember

### 1. Incompatible Data Models

Standard 5PFH and Bug Hunt use fundamentally different data structures:

| Aspect | Standard (FiveParsecsCampaignCore) | Bug Hunt (BugHuntCampaignCore) |
|--------|-----------------------------------|-------------------------------|
| Crew | `crew_data["members"]` (nested) | `main_characters[]` + `grunts[]` (flat, top-level) |
| Ship | `ship_data` | None |
| Patrons | `patrons[]`, `rivals[]` | None |

Detection pattern:
```gdscript
if "main_characters" in campaign:
    # Bug Hunt campaign
else:
    # Standard 5PFH campaign
```

### 2. Stat Key Mapping

| Bug Hunt | Standard 5PFH |
|----------|---------------|
| `combat_skill` | `combat` |
| `reactions` | `reaction` |

CharacterTransferService handles bidirectional mapping. Always use the transfer service — never manually remap stats.

### 3. Temp Data Namespacing

Bug Hunt keys use `"bug_hunt_*"` prefix to prevent collision:
- `"bug_hunt_battle_context"`, `"bug_hunt_battle_result"`, `"bug_hunt_mission"`

Standard keys: `"world_phase_results"`, `"return_screen"`, `"selected_character"`

Never use a Bug Hunt prefix on standard keys or vice versa.

### 4. TacticalBattleUI is Shared

`TacticalBattleUI.gd` (class_name `FPCM_TacticalBattleUI`) serves both Standard and Bug Hunt modes. Bug Hunt detection happens at a higher level (BugHuntBattleSetup, temp_data keys). Any changes to TacticalBattleUI must be tested in both modes.

### 5. Enlistment Roll (FIXED Session 42)

Bug Hunt recruitment: 2D6 + Combat >= **7+** (Compendium p.212). Was incorrectly coded as 8+ — fixed in Session 42.

### 6. PDF Rulebooks & Python Extraction Tools

Bug Hunt rules are in the Compendium — extract directly instead of guessing:
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Text extractions**: `docs/rules/core_rulebook.txt` and `docs/rules/compendium_source.txt`
- **Python (PyPDF2 ONLY)**: `py` launcher (NOT `python`). PyPDF2 3.0.1 is the only PDF tool — do NOT use PyMuPDF/fitz. Example: `py -c "from PyPDF2 import PdfReader; r = PdfReader('path'); print(r.pages[PAGE].extract_text())"`

### 7. Bug Hunt Equipment Step Auto-Complete (Session 10)

`BugHuntCreationCoordinator.go_to_step()` auto-marks EQUIPMENT as complete when entering step 2. Bug Hunt uses standard issue equipment (read-only panel) — the panel never emits `equipment_updated`, so without auto-complete the Next button won't appear and the wizard gets stuck at step 3.

### 8. TacticalBattleUI Now Serves Three Modes

TacticalBattleUI is shared between Standard 5PFH, Bug Hunt, and **Battle Simulator** (new standalone mode). Battle Simulator passes lightweight crew/enemy dicts. Any changes to TacticalBattleUI must work in all three modes.

### 9. Session 40b Context: Legal Stack + Compendium Library

No direct Bug Hunt changes. Context awareness:

- Legal stack shipped (EULAScreen, LegalConsentManager, etc.) — 14 new files. Bug Hunt campaigns are NOT affected by legal consent flow (consent is app-level, not campaign-level)
- Compendium library added (10 categories, 340+ items) — Bug Hunt content is in the Compendium, so Bug Hunt-specific items should be browsable through the library
- Icon SOP: game-icons.net SVGs, white on transparent, `assets/icons/{context}/`
- `docs/MODIPHIUS_ASK_LIST.md` — Bug Hunt pricing listed as open question (separate purchase vs included vs DLC pack)

### 10. campaign_crew_size Does NOT Apply to Bug Hunt (Session 39)

`FiveParsecsCampaignCore.campaign_crew_size` (4/5/6 setting) is Standard 5PFH only. Bug Hunt uses `BugHuntCampaignCore` which has `main_characters` + `grunts` arrays, not crew_data. Bug Hunt enemy counts follow Compendium Bug Hunt tables, not the Core Rules p.63 dice formula. If changes touch `get_campaign_crew_size()` in shared files (GameState, GameStateManager), ensure Bug Hunt code paths don't call it.

### 11. Godot 4.6 Type Inference

`var x := dict["key"]` will NOT compile — Dictionary values are always Variant.
Always use explicit type annotation: `var x: Type = dict["key"]`. Zero exceptions.

### 12. Session 42+43: Bug Hunt Audit + Wiring + Transfer Complete

**Data audit**: All 15 JSON files verified against Compendium PDF — zero corrections needed.

**Bugs fixed (14)**: 6 JSON key mismatches (enemies never loaded, post-battle tables all read wrong keys), 7 logic bugs (priority formula, spawn rating bounds, XP/Rep/Mustering formulas all wrong), 1 op-progress string range parser.

**Features implemented**: 3D6 objective generation (Vital/Critical), per-character loadout selection, interactive support team rolling, Special Assignment stat/XP/Rep application with eligibility filtering, advancement spending UI, court martial, BugHuntBattleCompanion (contact movement/tactical activation/spawn closing/evac/signals/formation), Movie Magic activation UI.

**UI modernization**: BugHuntScreenBase extends CampaignScreenBase. Dashboard rewritten with HubFeatureCards/stat strip/crew cards. All 12 Bug Hunt UI files migrated to UIColors. Glass morphism cards. Input validation on ConfigPanel.

**Transfer system wired**: CharacterTransferPanel rewritten as 3-step guided flow. Dashboard has Enlist/Muster Out cards. MainMenu detects Bug Hunt saves (continue/load/new dialog). Transfer inbox at `user://transfers/`. Equipment stash + character snapshots persist in BugHuntCampaignCore save data. Deep copy with `.duplicate(true)` on every cross-campaign boundary. Atomic file writes for transfer files.

**Field mapping**: `combat`↔`combat_skill`, `experience`↔`xp`, `reaction`↔`reactions`, `missions_completed`↔`completed_missions_count`. Original 5PFH character snapshot stored at enlistment for lossless muster-out.

### 13. Bug Hunt Compendium Text Extraction

Full Bug Hunt rules extracted to `docs/rules/bug_hunt_compendium_extract.txt` (pages 163-226). Use this instead of re-extracting from PDF.

### 14. Session 45: Runtime QA — Critical Bugs Fixed

**BugHuntTurnController must use `call_deferred("_initialize")`** — `_ready()` fires before node is in scene tree when instantiated by `TransitionManager.fade_to_scene()`. All `get_node_or_null("/root/...")` calls fail. Fix: defer all initialization.

**HubFeatureCard pending data pattern** — `setup()` called before `add_child()` means `_ready()` hasn't built UI yet. Labels are null. Fix: store pending data, apply in `_ready()`. CampaignDashboard does `add_child` first (correct); BugHuntDashboard did `setup` first (was broken, now fixed with pending pattern).

**MainMenu Bug Hunt dialog navigation** — `AcceptDialog` modal blocks `SceneRouter.navigate_to()`. Fix: `dialog.queue_free()` + `create_timer(0.05).timeout` for scene change. Also `bug_hunt_dashboard` was missing from MainMenu `scene_map`.

**Bug Hunt flow verified**: MainMenu → dialog → Dashboard → Turn 1 → Assignments → Mission → Launch → Tactical Battle (all working).
