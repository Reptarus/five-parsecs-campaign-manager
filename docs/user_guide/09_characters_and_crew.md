# Chapter 9: Characters and Crew

> **Quick Start** (for tabletop veterans)
> - Six flat stats: Combat, Reaction, Speed, Toughness, Savvy, Luck (no sub-objects)
> - Captain gets min 3 in Combat/Toughness/Savvy, +1 HP, 2 Luck
> - Implants: up to 3 per character, 6 types, auto-installed from loot
> - Species affect stat caps, abilities, and upgrade methods (Bots use credits, not XP)
> - Character events fire during the Character Phase of each turn

## Overview

Your crew members are the heart of your campaign. Each character has stats, equipment, skills, and a personal history that develops over the course of play. Understanding how characters work helps you make better tactical and strategic decisions.

## Character Stats

Every character has six core attributes:

| Stat | Range | What It Does |
|------|-------|-------------|
| **Combat** | 0-5 | Ranged and melee attack accuracy |
| **Reaction** | 1-6 | Initiative order and response speed |
| **Speed** | 4-8 | Movement distance per activation |
| **Toughness** | 2-8 | Base durability; health = Toughness + modifier |
| **Savvy** | 0-5 | Technical checks, awareness, non-combat actions |
| **Luck** | 0-3 | Reroll tokens; spent to redo bad dice results |

Stats are stored as flat properties on each character — there is no nested "stats" sub-object. Health is derived from Toughness: captains get Toughness + 3, crew members get Toughness + 2.

### Species and Stat Caps

Different species have different maximum stat values:

| Species | Combat | Reaction | Speed | Toughness | Savvy | Luck | Special |
|---------|--------|----------|-------|-----------|-------|------|---------|
| Human | 5 | 6 | 8 | 6 | 5 | 3 | Standard |
| Bot | 4 | 4 | 6 | 8 | 3 | 0 | Credits for upgrades |
| K'Erin | 5 | 5 | 7 | 7 | 4 | 2 | Combat bonus |
| Soulless | 4 | 6 | 7 | 5 | 6 | 1 | Cannot train skills |
| Engineer | 4 | 5 | 7 | 5 | 6 | 3 | Tech bonus |
| Precursor | 5 | 5 | 7 | 6 | 5 | 2 | Credits for upgrades |
| Krag (DLC) | 6 | 4 | 6 | 8 | 3 | 1 | Heavy fighter |
| Skulker (DLC) | 4 | 6 | 8 | 4 | 5 | 2 | Stealth bonus |

## Backgrounds and Motivations

### Backgrounds

Your character's background represents their life before joining the crew. Backgrounds provide:
- Starting skill bonuses
- Stat modifiers
- Sometimes starting equipment

Common backgrounds include colonist, military, spacer, technician, trader, and outcast. The specific bonuses are applied automatically during character creation.

### Motivations

A character's motivation drives their personal goals. Motivations can trigger special events during the Character Phase and affect certain dice rolls. Examples include wealth, revenge, exploration, fame, and survival.

## Implants

Cybernetic implants are permanent upgrades installed in your crew members.

### Rules
- Maximum **3 implants** per character
- **6 types** available
- Implants are **auto-installed from loot** when found — the `LOOT_TO_IMPLANT_MAP` pipeline handles this
- Cannot be removed once installed
- Provide permanent stat or ability bonuses

### Decision Guidance

Since implants are permanent and limited to 3, be strategic about which characters receive them. Frontline fighters benefit most from combat and toughness implants, while support characters benefit from savvy and reaction implants.

## Managing Your Crew

### Crew Management Screen

Access from the Campaign Dashboard to:
- View detailed character sheets
- Reassign equipment between members
- Review skills and advancement history
- Check injury status and recovery countdown
- Compare crew member stats side-by-side

### Hiring and Firing

During certain campaign events or World Phase tasks, you can:
- **Recruit new crew members** — Generated with random stats and background
- **Dismiss crew members** — Remove them from your roster (equipment is returned to stash)

Crew size affects upkeep costs (1 credit per member per turn) and tactical options (more members = more deployed in battle).

### Injury Recovery

When a crew member is injured:
- Recovery time is shown in turns remaining
- Injured members can only **Rest** or **Guard** during crew tasks
- Resting speeds recovery
- Some injuries have permanent effects (stat reduction)
- Medical skill on another crew member improves recovery

## Character Events

During the Character Phase of each turn, crew members may experience personal events:

- **Positive**: Make a new contact, learn a secret, find a lead
- **Negative**: Pick up an addiction, make a personal enemy, romantic complication
- **Neutral**: Philosophical reflection, nostalgic memory, unusual encounter

These events are generated from the `character_events.gd` system and add narrative depth to your crew's story.

## Captain Privileges

Your captain has special status:

- Minimum stats of 3 in Combat, Toughness, and Savvy
- +1 bonus health (Toughness + 3 vs crew's Toughness + 2)
- 2 Luck points (crew gets 1)
- Captain death has severe morale consequences
- Legacy system tracks captain achievements across campaigns

If your captain dies, you must promote another crew member to captain. The promoted member gains captain health but not the minimum stat bonuses.

## What's Next?

- For equipment loadouts: {{chapter:10}} — Equipment and Weapons
- For stat upgrades: {{chapter:08}} — Advancement and Trading
- For species with DLC: {{chapter:13}} — DLC and Expansion Content
