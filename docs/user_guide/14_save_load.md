# Chapter 14: Saving and Loading

> **Quick Start** (for tabletop veterans)
> - Auto-save fires at turn start and after battles
> - Manual save from Dashboard or Save/Load screen anytime
> - 3 rotating backups kept automatically
> - Export/import as .save or .json files for sharing or backup
> - Bug Hunt and standard campaigns have separate save files, auto-detected on load

## Overview

The app saves your campaign data as JSON files. You can rely on auto-save for routine play, create manual saves for checkpoints, and export/import campaign files for backup or sharing.

## Auto-Save

The app automatically saves your campaign at key moments:

- **Turn start** — Before each new turn begins
- **After battles** — When post-battle processing completes
- **Phase transitions** — At major phase boundaries

Auto-saves are named with the turn number (e.g., `turn_5_autosave`) and stored alongside your manual saves.

## Manual Saves

### How to Save

1. From the Campaign Dashboard, access the **Save/Load** screen
2. Your current campaign state is saved with a timestamp
3. You can save at any point between phases

### When to Save

- **Before risky battles** — If the upcoming mission looks dangerous
- **After good loot drops** — Preserve a favorable outcome
- **Before making big decisions** — Spending large amounts of credits, dismissing crew
- **End of each play session** — Even though auto-save exists, a manual save is extra insurance

## Rotating Backups

The app maintains **3 rotating backups** of your campaign:

- Each save creates a new backup
- The oldest backup is removed when a 4th would be created
- Backups let you recover from corruption or unintended changes

## Loading Campaigns

### From the Main Menu

1. Click **Load Campaign** (or **Continue** for your most recent)
2. Browse the list of saved campaigns
3. Each entry shows the campaign name and last-played date
4. Select one to load it

### Campaign Type Detection

The app automatically detects whether a save file is a standard Five Parsecs campaign or a Bug Hunt campaign. It routes to the correct loader based on the save file structure — you don't need to specify which type it is.

## Import and Export

### Exporting

Export your campaign to a file on your computer:

- Saved as `.save` or `.json` format
- Contains all campaign data (crew, equipment, progress, history)
- Useful for backing up to external storage
- Can be shared with others (they'll get your exact campaign state)

### Importing

Import a campaign file from your computer:

1. Click **Import from File** on the Load screen
2. Browse for a `.save` or `.json` file
3. The app validates the file and loads the campaign

Import works with files from any platform — a campaign exported on PC can be imported on mobile and vice versa.

## Campaign Journal

The Campaign Journal is an automatic log maintained alongside your save:

- **Turn-by-turn entries** — What happened each turn
- **Battle summaries** — Combat outcomes and statistics
- **Crew changes** — Injuries, deaths, recruitment
- **Financial log** — Credits earned and spent
- **Event history** — Story events and character events

Access the journal from the Campaign Dashboard. It's useful for reviewing past turns and tracking your campaign's narrative arc.

## Save File Locations

Save files are stored in the app's user data directory:

- **Windows**: `%APPDATA%/Godot/app_userdata/Five Parsecs Campaign Manager/saves/`
- **macOS**: `~/Library/Application Support/Five Parsecs Campaign Manager/saves/`
- **Linux**: `~/.local/share/Five Parsecs Campaign Manager/saves/`
- **Android**: Internal app storage (accessible via export)
- **iOS**: Internal app storage (accessible via export)

## Legacy System

When you complete a campaign (see {{chapter:11}}), it can be archived in the Legacy System:

- Final campaign stats are preserved
- **Stars of Story** earned carry over to future campaigns
- Legacy campaigns appear in a hall of fame
- You can review past campaigns' achievements

## Troubleshooting

### Save file won't load

- Check that the file hasn't been corrupted (should be valid JSON)
- Try loading a backup from the rotating backup system
- Verify the file is from a compatible app version

### Missing auto-saves

- Auto-save requires completing a full phase transition
- If the app crashes mid-phase, the last auto-save will be the previous turn

### Import fails

- Ensure the file is a valid `.save` or `.json` file
- Check that the file was exported from the Five Parsecs Campaign Manager
- Verify file isn't empty or truncated

## What's Next?

- For campaign creation: {{chapter:02}} — Creating a Campaign
- For victory and campaign completion: {{chapter:11}} — Victory Conditions
