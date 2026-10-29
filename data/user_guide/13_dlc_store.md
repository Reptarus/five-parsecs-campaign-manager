# Chapter 13: DLC and Expansion Content

> **Quick Start** (for tabletop veterans)
> - 3 Compendium packs: Trailblazer's Toolkit, Freelancer's Handbook, Fixer's Guidebook
> - Game modes are unlocked separately: Bug Hunt has its own card on the Store screen
> - Gated features appear when you own the pack that adds them
> - The in-app Store is titled **Expansions**
> - The packs correspond to the physical Compendium supplement

## Overview

The Five Parsecs Campaign Manager supports three DLC packs that add content from the *Five Parsecs from Home Compendium* supplement. Each pack adds new species, mission types, game mechanics, and gameplay options.

DLC content is integrated throughout the app — when you purchase a pack, its features become available everywhere they're relevant (character creation, mission selection, battle mechanics, etc.).

## The Three DLC Packs

### Trailblazer's Toolkit

Unlock alien species, psionics, and advanced gear.

- **New Species**: Krag Species, Skulker Species
- **Psionics**: Psionics System, Psionic Equipment
- **Crew Upgrades**: Advanced Training, Bot Upgrades, New Ship Parts

### Freelancer's Handbook

Master combat variants, difficulty options, and new missions.

- **Difficulty & Scaling**: Progressive Difficulty, Difficulty Toggles, Elite Enemies, Escalating Battles
- **Combat Variants**: Dramatic Combat, No-Minis Combat, Grid-Based Movement, AI Variations, Deployment Variables, Terrain Generation
- **Missions & Connections**: Expanded Missions, Expanded Quests, Expanded Connections
- **Multiplayer & Casualties**: PvP Battles, Co-op Battles, Casualty Tables, Detailed Injuries

### Fixer's Guidebook

New mission types, factions, and world systems.

- **Mission Types**: Stealth Missions, Street Fights, Salvage Jobs
- **World Systems**: Expanded Factions, Fringe World Strife, Expanded Loans, Name Generation
- **Campaign Modes**: Introductory Campaign, Prison Planet Character

The Store screen shows each pack's full feature list under **Show Details**.

## The DLC Store

### Opening the Store

The Store screen is titled **Expansions**. You can reach it from:

- **Browse Expansions** in Settings
- the unlock button on a locked mode's information card on the Main Menu
- an expansion banner shown where an expansion adds something, such as the campaign setup screen
- the dialog that appears when you load a save that needs a pack you do not own

### What the Store Shows

From the top:

- A **bundle** card for the three Compendium packs together, hidden once you own all three
- **Compendium Expansions**: one card for each pack, with its features and a buy button. Once you own a pack, its card lets you manage which of its features are switched on.
- **Game Modes**: a card for Bug Hunt, with a buy button, or a play button once you own it
- A footer with **Restore Purchases**, **Rate This App** and the store status
- **Help** at the top opens this guide

If the app has no store connection, a banner at the top says "Development Mode — No store connection".

### Buying an Expansion

On Android, purchases go through Google Play. Press the buy button on a card and follow the Google Play prompts. When Google Play confirms the purchase, the pack unlocks and the app shows a short notice.

**Restore Purchases** re-checks what your account owns. Use it after reinstalling the app or setting up a new device.

### After Purchase

Once purchased, expansion content activates immediately:
- New species appear in character creation
- New mission types appear in mission selection
- New mechanics are available throughout gameplay
- No restart required

## How DLC Content Integrates

DLC content is gated using the `DLCManager` system. When a feature requires DLC:

- If you **own the DLC**: The feature works normally, fully integrated
- If you **don't own the DLC**: The feature is hidden or shows a "Requires [DLC Name]" message

### Examples of DLC Integration

- **Character Creation**: Krag and Skulker species only appear if their respective DLC is owned
- **Mission Selection**: Stealth, street fight, and salvage missions require their DLC packs
- **Battle Mechanics**: Escalating battles and psionic powers require specific DLC
- **Game Modes**: A mode that is sold separately, such as Bug Hunt, is locked until you own it. Its card on the Main Menu then opens the Store.

## Content Flags

The expansion system gates individual features with content flags. Each flag corresponds to a specific piece of content:

- Character species (Krag, Skulker)
- Mission types (stealth, street fight, salvage)
- Battle mechanics (escalating battles, dramatic combat)
- Equipment categories (compendium gear)
- And more

This keeps the experience clean for players who have not purchased an expansion.

## What's Next?

- For Bug Hunt details: {{chapter:12}} — Bug Hunt Mode
- For character species info: {{chapter:09}} — Characters and Crew
