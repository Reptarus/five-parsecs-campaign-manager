# Integration Test Scenarios

**Last Updated**: 2026-05-01 (added S11-S15 for alpha-1; S4 deferred; fixed S5 flag count 37→33)
**Purpose**: End-to-end workflow test scripts covering multi-system data flows
**Extends**: `docs/testing/DEMO_QA_SCRIPT.md` (which covers CC→2 turns→save/load)
**Alpha-1 specific**: Scenarios S11-S15 are alpha-1 deliverables. Scenario 4 (Cross-Mode Isolation) is DEFERRED to alpha-2. See `docs/testing/ALPHA_1_QA_PLAN.md` for scope decision.

---

## How to Use This Document

Each scenario has:
- **Prerequisites**: What must be set up before starting
- **Steps**: Numbered actions to perform
- **Checkpoints**: Verification points marked with `[CHECK]`
- **MCP Commands**: Automation snippets in the Appendix

**Testing methods**: `MCP` = MCP-automated via Godot tools, `MANUAL` = requires human observation, `HYBRID` = MCP steps + manual verification

---

## Scenario Index

| # | Scenario | Priority | Est. Time | Checkpoints | Method |
|---|----------|----------|-----------|-------------|--------|
| 1 | Full Campaign Lifecycle (5+ turns → victory) | P0 | 90 min | 25 | MCP |
| 2 | Battle Lifecycle — All 3 Oracle Tiers | P0 | 45 min | 18 per tier | HYBRID |
| 3 | Save/Load Roundtrip Deep Validation | P0 | 30 min | 20 | MCP |
| ~~4~~ | ~~Cross-Mode Isolation (5PFH ↔ Bug Hunt)~~ — **DEFERRED to alpha-2** | — | — | — | — |
| 5 | DLC Gating Validation (33 flags — TT=7, FH=17, FG=9) | P1 | 45 min | 33 | MCP |
| 6 | Difficulty Modifier Propagation | P1 | 30 min | 15 | MCP |
| 7 | Elite Ranks Cross-Campaign Flow | P1 | 20 min | 8 | MCP |
| ~~8~~ | ~~Store/Paywall Adapter Testing~~ — **DEFERRED to beta** (alpha runs offline mode) | — | — | — | — |
| 9 | Three-Enum Sync Validation | P0 | 15 min | 5 | MCP |
| 10 | Rules Accuracy Spot Check | P0 | 60 min | 20 | HYBRID |
| **11** | **Compendium DLC Toggle Lifecycle** (33 flags ON/OFF mid-campaign) | **P0 (alpha-1)** | 45 min | 18 | MCP |
| **12** | **Telemetry Consent + No-PII Audit** | **P0 (alpha-1)** | 30 min | 12 | MCP |
| **13** | **Category-Perception Probe Surfaces** | **P1 (alpha-1)** | 20 min | 8 | HYBRID |
| **14** | **Conversion Mechanism Placement + Tone** | **P1 (alpha-1)** | 30 min | 10 | HYBRID + tester debrief |
| **15** | **Pre-Alpha A0 Smoke (Standard 5PFH only)** | **P0 (alpha-1)** | 60 min | 11 | MCP |

---

## Scenario 1: Full Campaign Lifecycle (P0, ~90 min)

**Goal**: Create a campaign, play 5+ turns, trigger a victory condition, verify end-to-end state.

**Prerequisites**: Clean game state (no existing saves or delete before starting)

### Steps

1. **Create campaign** with NORMAL difficulty, TURNS_20 victory condition, Story Track enabled
2. **Play Turn 1**: All 9 phases (STORY → TRAVEL → UPKEEP → MISSION → POST_MISSION → ADVANCEMENT → TRADING → CHARACTER → RETIREMENT)
   - `[CHECK-1.1]` Turn counter shows 1 after completion
   - `[CHECK-1.2]` Credits changed from starting value (upkeep deducted, mission pay added)
   - `[CHECK-1.2a]` Starting credits value matches Core Rules book (verify against book)
   - `[CHECK-1.2b]` Upkeep deduction amount matches Core Rules p.80
   - `[CHECK-1.3]` CampaignJournal has Turn 1 entries

3. **Play Turn 2**: Same 9-phase flow
   - `[CHECK-1.4]` Turn counter shows 2
   - `[CHECK-1.5]` Story points incremented if every 3rd turn rule applies

4. **Save mid-campaign**
   - `[CHECK-1.6]` Save file exists at `user://saves/`
   - `[CHECK-1.7]` Save file contains `turn_number: 2` in progress_data

5. **Quit and reload**
   - `[CHECK-1.8]` Credits match pre-save value
   - `[CHECK-1.9]` Crew count matches pre-save
   - `[CHECK-1.10]` Equipment stash preserved (BUG-035 regression check)

6. **Play Turns 3-5**: Abbreviated (can skip some phases via automation)
   - `[CHECK-1.11]` Turn counter increments correctly each turn
   - `[CHECK-1.12]` No crashes across 5 turns of sequential play
   - `[CHECK-1.13]` Invasion escalation observable (if applicable)

7. **Fast-forward to victory** (set turn_number to 19 via run_script, then complete Turn 20)
   - `[CHECK-1.14]` VictoryChecker detects TURNS_20 condition met
   - `[CHECK-1.15]` EndPhasePanel shows victory message
   - `[CHECK-1.16]` Campaign can be saved post-victory

8. **Verify cumulative state integrity**
   - `[CHECK-1.17]` progress_data.battles_won > 0 (BUG-033 regression)
   - `[CHECK-1.18]` progress_data.missions_completed > 0
   - `[CHECK-1.19]` Crew XP increased from starting values
   - `[CHECK-1.19a]` XP values are within Core Rules expected ranges (p.89-90)
   - `[CHECK-1.20]` Equipment count reflects loot/purchases across turns
   - `[CHECK-1.20a]` Equipment stats on generated items match Core Rules p.50
   - `[CHECK-1.21]` Dual-sync: campaign.credits == progress_data.credits
   - `[CHECK-1.22]` Dual-sync: campaign.supplies == progress_data.supplies
   - `[CHECK-1.23]` Dual-sync: campaign.reputation == progress_data.reputation
   - `[CHECK-1.24]` Dual-sync: campaign.story_progress == progress_data.story_progress
   - `[CHECK-1.25]` CampaignJournal has entries spanning all turns played

---

## Scenario 2: Battle Lifecycle — All 3 Oracle Tiers (P0, ~45 min)

**Goal**: Verify the battle companion system works correctly in all 3 tracking modes.

**Prerequisites**: Active campaign with at least 1 turn completed, battle available

### Per-Tier Steps (repeat for LOG_ONLY, ASSISTED, FULL_ORACLE)

1. **Enter battle** from World Phase mission selection
   - `[CHECK-2.1]` PreBattleUI loads with mission briefing
   - `[CHECK-2.2]` Crew selection shows only active (non-injured) members

2. **Select oracle tier**
   - `[CHECK-2.3]` Tier selection overlay appears (BUG-B01 regression)
   - `[CHECK-2.4]` Selected tier activates correct panel visibility

3. **Battle setup**
   - `[CHECK-2.5]` Enemy count formula applied correctly (2D6 pick-based)
   - `[CHECK-2.6]` Deployment conditions displayed
   - `[CHECK-2.7]` Terrain suggestions generated

4. **Combat rounds** (tier-specific behavior)
   - LOG_ONLY: `[CHECK-2.8]` Only logging available, no suggestions
   - ASSISTED: `[CHECK-2.9]` AI suggestions shown, dice helpers available
   - FULL_ORACLE: `[CHECK-2.10]` Auto-resolve available, all AI decisions made

5. **Initiative roll**
   - `[CHECK-2.11]` Initiative roll works without crash (BUG-042/043 regression)
   - `[CHECK-2.12]` Seize initiative result displayed correctly

6. **Battle completion**
   - `[CHECK-2.13]` Battle outcome determined (victory/defeat/partial)
   - `[CHECK-2.14]` Transition to post-battle sequence
   - `[CHECK-2.15]` All 14 post-battle steps accessible

7. **Post-battle data**
   - `[CHECK-2.16]` XP distributed to surviving crew
   - `[CHECK-2.17]` Loot added to inventory
   - `[CHECK-2.18]` Victory flag propagated to campaign stats (BUG-033 check)

---

## Scenario 3: Save/Load Roundtrip Deep Validation (P0, ~30 min)

**Goal**: Verify every data category survives a save/load cycle with correct values.

**Prerequisites**: Campaign with 2+ turns played, equipment acquired, injuries sustained

### Steps

1. **Record pre-save state** (via run_script):
   - Credits, supplies, reputation, story_progress
   - Crew count, each member's name + stats + equipment
   - Ship hull, debt, components
   - Turn number, missions completed, battles won/lost
   - Equipment stash contents

2. **Save campaign**
   - `[CHECK-3.1]` Save file written to `user://saves/`

3. **Inspect save JSON** (via run_script reading the file):
   - `[CHECK-3.2]` `equipment_data["equipment"]` key exists (NOT "pool")
   - `[CHECK-3.3]` Every crew dict has both `id` and `character_id` keys
   - `[CHECK-3.4]` Every crew dict has both `name` and `character_name` keys
   - `[CHECK-3.5]` Exactly 1 crew member has `is_captain: true`
   - `[CHECK-3.6]` All stat values within valid ranges
   - `[CHECK-3.7]` `difficulty` is GlobalEnums.DifficultyLevel int (1,2,4,6,8)
   - `[CHECK-3.8]` Integer values preserved (JSON float → int conversion)

4. **Reload campaign**
   - `[CHECK-3.9]` Load completes without errors

5. **Verify restored state**:
   - `[CHECK-3.10]` Credits match pre-save (dual-sync: campaign + progress_data)
   - `[CHECK-3.11]` Supplies match pre-save
   - `[CHECK-3.12]` Reputation match pre-save
   - `[CHECK-3.13]` Story progress match pre-save
   - `[CHECK-3.14]` Crew count matches
   - `[CHECK-3.15]` Each crew member's stats match
   - `[CHECK-3.16]` Equipment per crew member restored
   - `[CHECK-3.17]` Ship stash equipment restored (BUG-035 regression)
   - `[CHECK-3.18]` Ship hull/debt/components match
   - `[CHECK-3.19]` Turn number, missions, battles counts match
   - `[CHECK-3.20]` Origin field non-empty for all crew (BUG-030 regression)

---

## Scenario 4: Cross-Mode Isolation — 5PFH vs Bug Hunt (P0, ~30 min)

> **DEFERRED to alpha-2** (decision 2026-05-01): Bug Hunt is out of alpha-1 scope per `docs/testing/ALPHA_1_QA_PLAN.md` §1. This scenario is preserved for alpha-2 / beta when cross-mode coverage re-enters scope. Do NOT execute against alpha-1 builds.

**Goal**: Verify standard campaign and Bug Hunt campaigns don't contaminate each other's data.

**Prerequisites**: Both gamemodes accessible

### Steps

1. **Create standard 5PFH campaign**, play 1 turn, save as "Standard_Test"
   - `[CHECK-4.1]` Save file contains `crew_data.members[]` (nested)
   - `[CHECK-4.2]` Save file has `ship` data

2. **Create Bug Hunt campaign**, play 1 stage, save as "BugHunt_Test"
   - `[CHECK-4.3]` Save file contains `main_characters[]` (flat array)
   - `[CHECK-4.4]` Save file has `grunts[]`
   - `[CHECK-4.5]` Save file has NO `ship` data

3. **Load standard campaign**
   - `[CHECK-4.6]` GameState._detect_campaign_type() returns standard
   - `[CHECK-4.7]` No Bug Hunt temp_data keys present (no `bug_hunt_*`)
   - `[CHECK-4.8]` Ship data accessible

4. **Load Bug Hunt campaign**
   - `[CHECK-4.9]` GameState._detect_campaign_type() returns bug_hunt
   - `[CHECK-4.10]` `main_characters` array accessible
   - `[CHECK-4.11]` No standard temp_data contamination

5. **Cross-load safety**
   - `[CHECK-4.12]` Loading a standard save after Bug Hunt session shows correct data (no Bug Hunt remnants)

---

## Scenario 5: DLC Gating Validation (P1, ~45 min)

**Goal**: Verify all 33 content flags properly gate their features. (Canonical count verified 2026-05-01 against `src/core/systems/DLCManager.gd:34` — TT=7, FH=17, FG=9. Prior "37" was incorrect.)

**Prerequisites**: Access to DLCManager to toggle flags

### Steps

1. **Disable all DLC flags**
   - `[CHECK-5.1-33]` For each of 33 flags: verify gated content is NOT accessible
   - Key areas: Character creation (no Krag/Skulker), missions (no Stealth/Street/Salvage), CheatSheet (no compendium sections)

2. **Enable Trailblazer's Toolkit (7 flags)**
   - `[CHECK-5.TT]` Species selection shows Krag + Skulker
   - `[CHECK-5.TT]` Psionic legality check runs
   - `[CHECK-5.TT]` Bot upgrade options appear in Advancement
   - Flags: SPECIES_KRAG, SPECIES_SKULKER, PSIONICS, NEW_TRAINING, BOT_UPGRADES, NEW_SHIP_PARTS, PSIONIC_EQUIPMENT

3. **Enable Freelancer's Handbook (17 flags)**
   - `[CHECK-5.FH]` Difficulty toggles available in config
   - `[CHECK-5.FH]` Expanded missions appear in job offers
   - Flags: PROGRESSIVE_DIFFICULTY, DIFFICULTY_TOGGLES, PVP_BATTLES, COOP_BATTLES, AI_VARIATIONS, DEPLOYMENT_VARIABLES, ESCALATING_BATTLES, ELITE_ENEMIES, EXPANDED_MISSIONS, EXPANDED_QUESTS, EXPANDED_CONNECTIONS, DRAMATIC_COMBAT, NO_MINIS_COMBAT, GRID_BASED_MOVEMENT, TERRAIN_GENERATION, CASUALTY_TABLES, DETAILED_INJURIES

4. **Enable Fixer's Guidebook (9 flags)**
   - `[CHECK-5.FG]` Stealth/Street/Salvage missions in job pipeline
   - `[CHECK-5.FG]` Expanded loans available
   - Flags: STEALTH_MISSIONS, STREET_FIGHTS, SALVAGE_JOBS, EXPANDED_FACTIONS, FRINGE_WORLD_STRIFE, EXPANDED_LOANS, NAME_GENERATION, INTRODUCTORY_CAMPAIGN, PRISON_PLANET_CHARACTER

5. **Toggle mid-campaign**
   - `[CHECK-5.MID]` No crash when enabling/disabling DLC during active campaign
   - `[CHECK-5.MID]` Content appears/disappears on next relevant phase

---

## Scenario 6: Difficulty Modifier Propagation (P1, ~30 min)

**Goal**: Verify difficulty selection in campaign creation propagates through all systems.

**Prerequisites**: None (creates new campaigns)

### Steps

1. **Create EASY campaign**
   - `[CHECK-6.1]` DifficultyModifiers.get_xp_bonus() returns +1
   - `[CHECK-6.1a]` XP bonus value (+1 for EASY) matches Core Rules difficulty table
   - `[CHECK-6.2]` Story points NOT disabled
   - `[CHECK-6.3]` Victory conditions limited to basic set

2. **Create INSANITY campaign**
   - `[CHECK-6.4]` Story points disabled (DifficultyModifiers.are_story_points_disabled() == true)
   - `[CHECK-6.5]` add_story_points() is a no-op
   - `[CHECK-6.6]` Enemy count modifier: +1 specialist per battle
   - `[CHECK-6.7]` Invasion roll modifier: +3
   - `[CHECK-6.8]` Seize initiative modifier: -3
   - `[CHECK-6.9]` Unique Individual forced every battle

3. **Verify persistence**
   - `[CHECK-6.10]` Difficulty stored as GlobalEnums.DifficultyLevel int (8 for INSANITY)
   - `[CHECK-6.11]` Save/reload preserves difficulty value
   - `[CHECK-6.12]` Modifiers still active after reload

4. **Create HARDCORE campaign**
   - `[CHECK-6.13]` -1 starting story points
   - `[CHECK-6.14]` +1 basic enemy per battle
   - `[CHECK-6.15]` Rival resistance -2

---

## Scenario 7: Elite Ranks Cross-Campaign Flow (P1, ~20 min)

**Goal**: Verify Elite Ranks award, persist, and apply bonuses in new campaigns.

**Prerequisites**: Ability to force a victory condition completion

### Steps

1. **Complete campaign with TURNS_20 victory**
   - Set turn_number to 19 via run_script, complete Turn 20
   - `[CHECK-7.1]` VictoryChecker detects victory
   - `[CHECK-7.2]` PlayerProfile.award_elite_rank() called

2. **Verify persistence**
   - `[CHECK-7.3]` `user://player_profile.json` contains `elite_ranks: 1`
   - `[CHECK-7.4]` `completed_victory_conditions` includes TURNS_20

3. **Start new campaign**
   - `[CHECK-7.5]` Story point bonus: +1 (rank 1 × 1)
   - `[CHECK-7.6]` XP bonus: +2 (rank 1 × 2)
   - `[CHECK-7.7]` Extra starting characters: 0 (rank 1 / 3 = 0)

4. **Duplicate award rejection**
   - `[CHECK-7.8]` Completing TURNS_20 again returns false, rank stays at 1

---

## Scenario 8: Store/Paywall Adapter Testing (P2, ~20 min)

> **DEFERRED to beta / Steam Playtest** (decision 2026-05-01): Alpha runs in offline mode with all Compendium content unlocked per `docs/CLOSED_ALPHA_PLAN.md` §3. Store adapter testing requires real device + real billing accounts; out of scope for closed alpha. Re-enters scope in Phase D.

**Goal**: Verify store adapter pattern works for DLC purchases.

**Note**: Platform adapters (Steam/Android/iOS) require real devices. Only OfflineStoreAdapter testable in dev.

### Steps

1. **OfflineStoreAdapter (editor/dev mode)**
   - `[CHECK-8.1]` StoreManager initializes with OfflineStoreAdapter
   - `[CHECK-8.2]` purchase_dlc() returns appropriate fallback
   - `[CHECK-8.3]` purchase_completed signal fires

2. **Signal chain verification** (via run_script)
   - `[CHECK-8.4]` StoreManager.purchase_dlc() → adapter.purchase() chain works
   - `[CHECK-8.5]` purchase_completed → DLCManager.set_dlc_owned() chain works

3. **Platform-specific documentation** (manual test steps)
   - `[CHECK-8.6]` Each platform adapter documented with test steps for real-device testing

---

## Scenario 9: Three-Enum Sync Validation (P0, ~15 min)

**Goal**: Verify the three enum systems are aligned.

### Steps (via run_script)

1. **FiveParsecsCampaignPhase alignment**
   - `[CHECK-9.1]` All phase names in GlobalEnums.FiveParsecsCampaignPhase exist in GameEnums with same ordinal values

2. **CharacterClass superset check**
   - `[CHECK-9.2]` FiveParsecsGameEnums.CharacterClass contains all values from GlobalEnums character classes

3. **ContentFlag count**
   - `[CHECK-9.3]` DLCManager.ContentFlag.size() == 37 (35 DLC + 2 Bug Hunt)

4. **DifficultyLevel values**
   - `[CHECK-9.4]` GlobalEnums.DifficultyLevel values are {EASY:1, NORMAL:2, CHALLENGING:4, HARDCORE:6, INSANITY:8}

5. **No shadowing conflicts**
   - `[CHECK-9.5]` No enum name collisions between the three files

---

## Scenario 10: Rules Accuracy Spot Check (P0, ~60 min)

**Goal**: Verify specific game data values match the Core Rules book during live gameplay.

**Prerequisites**: Active campaign, physical Core Rules book at hand

**Method**: HYBRID — MCP pre-check for internal consistency, then human book verification

### Pre-Check: Internal Consistency (MCP Automated, ~10 min)

Run internal consistency scripts before human verification to catch code-vs-code discrepancies.

1. **Weapon data cross-check** (run A6 script below)
   - `[CHECK-10.1]` weapons.json stats match LootSystemConstants.WEAPON_DEFINITIONS for all shared weapons
   - `[CHECK-10.2]` weapons.json stats match equipment_database.json for all shared weapons

2. **Injury data cross-check** (run A7 script below)
   - `[CHECK-10.3]` injury_table.json ranges match InjurySystemConstants.INJURY_ROLL_RANGES

3. **Economy constants cross-check** (run A8 script below)
   - `[CHECK-10.4]` FiveParsecsConstants.ECONOMY.base_upkeep matches WorldEconomyManager.BASE_UPKEEP_COST

### Human Verification: Book Check (~50 min)

Requires a human with the physical Core Rules book open.

4. **Species Stats** (Core Rules pp.15-22)
   - Create characters of each species (Human, Engineer, K'Erin, Soulless, Precursor, Feral, Swift, Bot)
   - `[CHECK-10.5]` Each species' stat modifiers match Core Rules table
   - `[CHECK-10.6]` Special rules text matches book

5. **Weapon Stats** (Core Rules p.50)
   - Open equipment panel, inspect 5 randomly selected weapons
   - `[CHECK-10.7]` Each weapon's Range matches book
   - `[CHECK-10.8]` Each weapon's Shots matches book
   - `[CHECK-10.9]` Each weapon's Damage modifier matches book
   - `[CHECK-10.10]` Each weapon's Traits match book

6. **Upkeep Economy** (Core Rules p.80)
   - Enter upkeep phase with known crew size
   - `[CHECK-10.11]` Upkeep cost per crew member matches book
   - `[CHECK-10.12]` Ship maintenance cost matches book

7. **Injury Table** (Core Rules pp.122-124)
   - Trigger post-battle with casualties
   - `[CHECK-10.13]` Injury D100 ranges match book (Fatal 1-15, etc.)
   - `[CHECK-10.14]` Recovery times match book

8. **Loot Tables** (Core Rules pp.66-72)
   - `[CHECK-10.15]` Battlefield finds D100 ranges match book
   - `[CHECK-10.16]` Main loot table D100 ranges match book

9. **Advancement XP Costs** (Core Rules p.128)
   - Open advancement panel
   - `[CHECK-10.17]` XP cost per stat advancement matches book
   - `[CHECK-10.18]` Max stat values per species match book

10. **Enemy Generation** (Core Rules p.88)
    - Enter battle phase
    - `[CHECK-10.19]` Enemy count formula matches book
    - `[CHECK-10.20]` Spot check 3 enemy type stat blocks against book

---

## Scenario 11: Compendium DLC Toggle Lifecycle (P0 alpha-1, ~45 min)

**Goal**: Verify all 33 ContentFlags toggle correctly via Settings UI, content surfaces appear/disappear as expected, and toggle state survives mid-campaign + save/load.

**Prerequisites**: Fresh `user://` state OR existing campaign

**Method**: MCP

### Steps

1. **Pre-condition: all DLC OFF**
   - `[CHECK-11.1]` Settings → DLC management shows all 33 flags OFF
   - `[CHECK-11.2]` `DLCManager.is_feature_enabled(ContentFlag.SPECIES_KRAG)` returns false (and equivalent for any 5 sampled flags)

2. **Enable Trailblazer's Toolkit (7 flags) all at once via "Enable Pack"**
   - `[CHECK-11.3]` All 7 TT flags now ON
   - `[CHECK-11.4]` New Campaign → Captain creation → species dropdown shows Krag + Skulker
   - `[CHECK-11.5]` Advancement panel shows Bot Upgrade options
   - `[CHECK-11.6]` Equipment panel shows psionic items category

3. **Enable Freelancer's Handbook (17 flags) all at once**
   - `[CHECK-11.7]` All 17 FH flags now ON
   - `[CHECK-11.8]` Config panel shows 12 Compendium difficulty toggles
   - `[CHECK-11.9]` Job offers panel shows expanded mission types

4. **Enable Fixer's Guidebook (9 flags) all at once**
   - `[CHECK-11.10]` All 9 FG flags now ON
   - `[CHECK-11.11]` World phase shows Stealth/Street/Salvage mission types in job pipeline
   - `[CHECK-11.12]` Loans panel accessible from world phase

5. **Mid-campaign disable**: turn off Fixer's Guidebook entirely while a campaign is loaded
   - `[CHECK-11.13]` No crash; campaign continues
   - `[CHECK-11.14]` Next world phase shows no Stealth/Street/Salvage missions
   - `[CHECK-11.15]` Existing campaign data not corrupted (credits/crew preserved)

6. **Save → reload → verify toggle state preserved**
   - `[CHECK-11.16]` After reload, Settings → DLC management shows TT+FH ON, FG OFF (matches pre-save state)
   - `[CHECK-11.17]` `dlc_states` dict in save JSON serialized correctly

7. **Re-enable all 33 flags + save → reload**
   - `[CHECK-11.18]` All 33 flags persisted ON across save cycle

---

## Scenario 12: Telemetry Consent + No-PII Audit (P0 alpha-1, ~30 min)

**Goal**: Verify the analytics consent gate works correctly + payloads contain zero PII.

**Prerequisites**: Fresh `user://` state OR known consent state; Talo dashboard access

**Method**: MCP + manual payload inspection

### Steps

1. **First-launch consent flow**
   - `[CHECK-12.1]` `LegalConsentManager.needs_legal_consent()` returns true; first launch routes to EULA
   - `[CHECK-12.2]` After EULA accept → Privacy → Analytics opt-in screen
   - `[CHECK-12.3]` Analytics opt-in screen shows OFF as default (must explicitly click to enable)

2. **Default-OFF gate enforcement**
   - Decline analytics; complete onboarding to MainMenu
   - `[CHECK-12.4]` `LegalConsentManager.get_analytics_consent()` returns false
   - Trigger 5+ events that would normally be analytics-recorded (phase changes, validation events, feature usage)
   - `[CHECK-12.5]` Talo dashboard shows ZERO new events for this session

3. **Opt-in via Settings**
   - Settings → Privacy → enable analytics
   - `[CHECK-12.6]` `LegalConsentManager.get_analytics_consent()` returns true; `consent_updated` signal fires
   - Trigger phase changes, save event, feature usage
   - `[CHECK-12.7]` Talo dashboard receives matching events within 60 seconds
   - `[CHECK-12.8]` Each event has anonymous session UUID; no name, email, IP, save content, character names, custom strings

4. **Mid-session opt-out**
   - Settings → Privacy → disable analytics
   - Continue playing; trigger more events
   - `[CHECK-12.9]` Talo dashboard receives NO new events for this session_id from opt-out timestamp forward

5. **No-PII payload audit**
   - Inspect last 10 events in Talo dashboard
   - `[CHECK-12.10]` Zero events contain: email, real name, IP, save file content, character names, captain custom name, ship custom name
   - `[CHECK-12.11]` Free-text survey responses (NPS open-ended fields) are stored separately and consent-gated

6. **GDPR data export + delete**
   - Settings → Privacy → "Export my data" → file written to `user://`
   - `[CHECK-12.12]` JSON manifest lists all `user://` files; opening it shows expected structure (consent state, save files, no orphan PII)

---

## Scenario 13: Category-Perception Probe Surfaces (P1 alpha-1, ~20 min)

**Goal**: Verify pricing-perception modal triggers correctly at session-end and category-perception modal triggers at week-3 + week-6 build checkpoints. Per `docs/CLOSED_ALPHA_PLAN.md` §6.1 and `docs/PRICING_RESEARCH_PLAN.md` §4.

**Prerequisites**: Analytics consent ON; survey state file fresh (`user://survey_state.cfg` deleted)

**Method**: HYBRID — MCP for trigger logic + manual review of question content

### Steps

1. **First session-end trigger (pricing modal)**
   - Play 1 campaign turn; navigate to MainMenu (session end)
   - `[CHECK-13.1]` Pricing modal appears with 4 Van Westendorp questions + 1 NPS question + 2 free-text questions (7 total)
   - `[CHECK-13.2]` 4 VW questions appear in randomized order (verify across 3 sessions)
   - `[CHECK-13.3]` Modal is dismissable (cancel button works without submission)

2. **Second session-end trigger (same build)**
   - Restart app; play 1 turn; navigate to MainMenu
   - `[CHECK-13.4]` Pricing modal does NOT reappear (once-per-build-version persistence working)

3. **Submit a complete pricing survey**
   - Trigger modal again on a fresh build version (or delete `user://survey_state.cfg`)
   - Fill all 7 fields; submit
   - `[CHECK-13.5]` Submission succeeds; toast confirms
   - `[CHECK-13.6]` Talo dashboard shows event `pricing_survey_submitted` with anonymized payload

4. **Category-perception modal at week-3 checkpoint (build A3)**
   - Set `application/config/version` = "v0.9.7-alpha1.A3" via debug or simulate
   - Trigger session-end
   - `[CHECK-13.7]` Category-perception modal appears (forced choice from 6 labels: campaign manager / solo RPG companion / digital edition / tabletop assistant / campaign tracker / gamemaster tool)
   - `[CHECK-13.8]` Submission produces Talo event `category_perception_choice`

5. **Category-perception trigger at A1 (should NOT fire)**
   - Reset state; set version "v0.9.7-alpha1.A1"
   - `[CHECK-13.9]` Category modal does NOT appear at session-end (only A3 + A6 are checkpoints)

---

## Scenario 14: Conversion Mechanism Placement + Tone (P1 alpha-1, ~30 min)

**Goal**: Verify all 5 §6.5 conversion mechanisms render in their specified placements and capture subjective tester signal during alpha-week-1 debrief. Per `docs/CLOSED_ALPHA_PLAN.md` §6.5.

**Prerequisites**: Fresh `user://` (for first-launch mechanism) OR existing campaign (for in-game placements)

**Method**: HYBRID — MCP for placement verification + tester debrief for tone signal

### Steps

1. **Mechanism #1: Discount code dialog**
   - Fresh launch → consent flow → MainMenu
   - `[CHECK-14.1]` Discount code dialog appears once after consent (placeholder code "ALPHA-TESTER-15" visible)
   - `[CHECK-14.2]` "Get the Book" entry visible in Settings → second appearance same dialog

2. **Mechanism #2: "Get the Physical Edition" CTA — 3 placements**
   - `[CHECK-14.3]` MainMenu footer shows "Get the Physical Edition" link
   - `[CHECK-14.4]` Help screen shows the link
   - `[CHECK-14.5]` Post-campaign-completion EndPhasePanel shows the link
   - `[CHECK-14.6]` Click in any placement opens external URL (mock during alpha)

3. **Mechanism #3: Bundled-PDF reminder tooltip**
   - Navigate to Compendium screen
   - `[CHECK-14.7]` Tooltip on hover/focus reads "Physical book includes free PDF — no need to repurchase digital content"

4. **Mechanism #4: Pre-order incentive mockup**
   - Navigate to Store / Expansions screen
   - `[CHECK-14.8]` "Coming Soon" panel section labeled "Future expansions: pre-order to receive [tier 1/2/3] incentives"; greyed-out tiers; non-interactive

5. **Mechanism #5: Newsletter capture form**
   - Settings → "Get Modiphius Newsletter" entry
   - `[CHECK-14.9]` Form requires email + name; consent checkbox unchecked by default
   - `[CHECK-14.10]` Submit triggers mock POST + success toast

6. **Subjective tone signal (week-1 tester debrief)**
   - During first weekly Discord debrief, ask 3 testers verbatim: "Which of these 5 in-app prompts about the physical book felt helpful, which felt pushy?" Capture exact words.
   - Acceptance: ≥2 of 3 testers describe at least 4 of 5 mechanisms as "helpful" / "respectful" / "obvious" — NOT "pushy" / "salesy" / "annoying"

---

## Scenario 15: Pre-Alpha A0 Smoke (Standard 5PFH only, P0 alpha-1, ~60 min)

**Goal**: Final pre-distribution smoke test for A0 build (Wed May 20). Mirrors §Verification of `C:\Users\admin\.claude\plans\warm-weaving-llama.md`.

**Prerequisites**: Clean Windows VM with no prior `user://` state; fresh A0 .exe build

**Method**: MCP-automated where possible + manual SmartScreen walkthrough

**Pass criteria**: All 11 checkpoints pass with ZERO P0 (game-breaking) issues. P1 (major UX) issues triaged into hotfix budget for Thu May 21.

### Steps

1. **Clean install**
   - Extract A0 .zip → double-click .exe → walk through SmartScreen "More info → Run anyway"
   - `[CHECK-15.1]` App launches within 10 seconds of "Run anyway" click

2. **First-launch flow**
   - `[CHECK-15.2]` EULA → privacy → analytics opt-in (default OFF) → MainMenu loads
   - `[CHECK-15.3]` Analytics defaults to OFF (verified `user://legal_consent.cfg` post-acceptance)

3. **Standard 5PFH campaign creation**
   - Run 7-step wizard end-to-end
   - `[CHECK-15.4]` Wizard completes; campaign saves to `user://saves/<campaign_name>.json`

4. **Compendium DLC toggle test (33 flags)**
   - Settings → DLC management → enable Trailblazer's Toolkit (7 flags) → New Campaign → verify Krag/Skulker species appear
   - Toggle OFF → verify they disappear
   - Repeat for FH (17) + FG (9)
   - `[CHECK-15.5]` All 33 flags toggle correctly without crash

5. **Standard 5PFH turn 1**
   - All 9 phases (Story → Travel → Upkeep → Mission → Post-Mission → Advancement → Trading → Character → Retirement) complete without crash
   - Save mid-turn → reload → verify state preserved
   - `[CHECK-15.6]` Turn 1 completes; save/reload roundtrip clean

6. **Battle Simulator standalone**
   - MainMenu → Battle Simulator → 1 battle resolves
   - `[CHECK-15.7]` Battle resolves; results screen shows; return to MainMenu works

7. **Pricing-perception survey**
   - Trigger session-end → survey appears
   - Submit valid responses
   - `[CHECK-15.8]` Modal works as designed; Talo dashboard receives event with no PII

8. **5 conversion mechanisms render**
   - `[CHECK-15.9]` All 5 placements visible per Scenario 14 above

9. **Telemetry consent gate**
   - Settings → disable analytics → trigger phase change
   - `[CHECK-15.10]` Talo receives no new events; re-enable → events resume

10. **GDPR data export**
    - Settings → Privacy → "Export my data"
    - `[CHECK-15.11.a]` JSON manifest written to `user://`

11. **Crash auto-capture**
    - Manually trigger `assert(false)` somewhere (debug-only fault injection)
    - `[CHECK-15.11.b]` Crash log file appears in `user://crash_logs/`; on next launch, dialog with "Open Folder" button appears

**Fail action**: Triage failures into P3.T4 hotfix sprint (Thu May 21). If P0 cannot be fixed by Sun May 24, slip A1 distribution to Mon Jun 1 and notify Modiphius via Gavin sync.

---

## Appendix: MCP Command Templates

### A1: Campaign Creation Shortcut

```gdscript
# run_script: Create campaign programmatically
var gs = get_node("/root/GameState")
var campaign = FiveParsecsCampaignCore.new()
campaign.campaign_name = "QA_Test_" + str(randi())
campaign.difficulty = GlobalEnums.DifficultyLevel.NORMAL
gs.current_campaign = campaign
gs.start_campaign()
return "Campaign created: " + campaign.campaign_name
```

### A2: Turn Advancement Shortcut

```gdscript
# run_script: Advance to next turn
var gs = get_node("/root/GameState")
var cpm = get_node("/root/CampaignPhaseManager")
cpm.advance_to_next_phase()
return "Current phase: " + str(cpm.current_phase)
```

### A3: State Inspection

```gdscript
# run_script: Read current campaign state
var gs = get_node("/root/GameState")
var gsm = get_node("/root/GameStateManager")
var c = gs.current_campaign
return JSON.stringify({
    "credits": gsm.credits,
    "supplies": gsm.supplies,
    "reputation": gsm.reputation,
    "story_progress": gsm.story_progress,
    "turn": c.progress_data.get("turn_number", 0) if c else -1,
    "crew_count": c.crew_data.get("members", []).size() if c else 0,
    "battles_won": c.progress_data.get("battles_won", 0) if c else 0,
    "dual_sync_credits": c.credits if c else -1,
    "pd_credits": c.progress_data.get("credits", -1) if c else -1
}, "\t")
```

### A4: Save File Validation

```gdscript
# run_script: Read and validate save file
var dir = DirAccess.open("user://saves/")
if not dir:
    return "No saves directory"
var files = []
dir.list_dir_begin()
var f = dir.get_next()
while f != "":
    if f.ends_with(".json"):
        files.append(f)
    f = dir.get_next()
if files.is_empty():
    return "No save files found"
var path = "user://saves/" + files[-1]
var data = JSON.parse_string(FileAccess.get_file_as_string(path))
var checks = []
checks.append("equipment_key: " + ("PASS" if "equipment" in data.get("equipment_data", {}) else "FAIL (missing 'equipment' key)"))
var members = data.get("crew_data", {}).get("members", [])
var captain_count = members.filter(func(m): return m.get("is_captain", false)).size()
checks.append("captain_count: " + str(captain_count) + (" PASS" if captain_count == 1 else " FAIL"))
checks.append("difficulty_type: " + str(typeof(data.get("difficulty", null))))
return "\n".join(checks)
```

### A5: Enum Sync Check

```gdscript
# run_script: Compare enum systems
var ge = GlobalEnums
var checks = []
# Check DifficultyLevel values
var dl = GlobalEnums.DifficultyLevel
checks.append("EASY=" + str(dl.EASY) + " NORMAL=" + str(dl.NORMAL) + " CHALLENGING=" + str(dl.CHALLENGING) + " HARDCORE=" + str(dl.HARDCORE) + " INSANITY=" + str(dl.INSANITY))
# Check ContentFlag count
var dlc = get_node_or_null("/root/DLCManager")
if dlc:
    checks.append("ContentFlag count: " + str(dlc.ContentFlag.size()))
return "\n".join(checks)
```

### A6: Weapon Data Cross-Check (Scenario 10)

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    var weapons_file = FileAccess.get_file_as_string("res://data/weapons.json")
    if not weapons_file:
        return {"error": "Cannot read weapons.json"}
    var weapons_json = JSON.parse_string(weapons_file)
    if not weapons_json or not weapons_json.has("weapons"):
        return {"error": "Invalid weapons.json format"}
    var lsc = LootSystemConstants.WEAPON_DEFINITIONS
    var mismatches = []
    for w in weapons_json["weapons"]:
        var wname = w.get("name", "")
        if wname in lsc:
            var lsc_w = lsc[wname]
            if lsc_w.get("range", -1) != w.get("range", -1):
                mismatches.append(wname + " range: JSON=" + str(w.range) + " LSC=" + str(lsc_w.range))
            if lsc_w.get("damage", -1) != w.get("damage", -1):
                mismatches.append(wname + " damage: JSON=" + str(w.damage) + " LSC=" + str(lsc_w.damage))
            if lsc_w.get("shots", -1) != w.get("shots", -1):
                mismatches.append(wname + " shots: JSON=" + str(w.shots) + " LSC=" + str(lsc_w.shots))
    return {"total_mismatches": mismatches.size(), "details": mismatches}
```

### A7: Injury Data Cross-Check (Scenario 10)

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    var injury_file = FileAccess.get_file_as_string("res://data/injury_table.json")
    if not injury_file:
        return {"error": "Cannot read injury_table.json"}
    var injury_json = JSON.parse_string(injury_file)
    var isc_ranges = InjurySystemConstants.INJURY_ROLL_RANGES
    var mismatches = []
    if injury_json.has("injuries"):
        for entry in injury_json["injuries"]:
            var type_name = entry.get("type", "")
            if type_name in isc_ranges:
                var isc_range = isc_ranges[type_name]
                var json_range = [entry.get("min_roll", -1), entry.get("max_roll", -1)]
                if isc_range[0] != json_range[0] or isc_range[1] != json_range[1]:
                    mismatches.append(type_name + ": JSON=" + str(json_range) + " ISC=" + str(isc_range))
    return {"total_mismatches": mismatches.size(), "details": mismatches}
```

### A8: Economy Constants Cross-Check (Scenario 10)

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    var checks = []
    var fpc_upkeep = FiveParsecsConstants.ECONOMY.get("base_upkeep", -1)
    var wem = scene_tree.root.get_node_or_null("/root/WorldEconomyManager")
    var wem_upkeep = wem.BASE_UPKEEP_COST if wem and "BASE_UPKEEP_COST" in wem else -1
    if fpc_upkeep != wem_upkeep:
        checks.append("UPKEEP MISMATCH: FiveParsecsConstants=" + str(fpc_upkeep) + " WorldEconomyManager=" + str(wem_upkeep))
    if checks.is_empty():
        return {"status": "ALL CONSISTENT", "checks_run": 1}
    return {"status": "INCONSISTENCIES FOUND", "details": checks}
```
