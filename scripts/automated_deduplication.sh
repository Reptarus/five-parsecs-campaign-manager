#!/bin/bash
# Automated Deduplication Script for Five Parsecs Campaign Manager
# Fixes massive Framework Bible violations: 260+ files → target 20 files

set -e  # Exit on error

PROJECT_ROOT="C:/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager"
BACKUP_DIR="$PROJECT_ROOT/backup/deduplication_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$PROJECT_ROOT/deduplication.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Create backup directory
log "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Change to project root
cd "$PROJECT_ROOT"

# Count current files
CURRENT_COUNT=$(find src -name "*.gd" -type f | wc -l)
log "Current file count: $CURRENT_COUNT files"

# ============================================================================
# PHASE 1: DELETE ALL MANAGER FILES (161 files)
# ============================================================================
log "========================================="
log "PHASE 1: Deleting Manager Pattern Violations"
log "========================================="

# Find all Manager files
find src -name "*Manager*.gd" -type f > "$BACKUP_DIR/manager_files.txt"
MANAGER_COUNT=$(wc -l < "$BACKUP_DIR/manager_files.txt")
log "Found $MANAGER_COUNT Manager files to delete"

# Backup Manager files
log "Backing up Manager files..."
mkdir -p "$BACKUP_DIR/managers"
while IFS= read -r file; do
    cp "$file" "$BACKUP_DIR/managers/$(basename "$file")"
done < "$BACKUP_DIR/manager_files.txt"

# Delete Manager files
log "Deleting Manager files..."
DELETED_COUNT=0
while IFS= read -r file; do
    if [ -f "$file" ]; then
        git rm -f "$file" 2>/dev/null || rm -f "$file"
        ((DELETED_COUNT++))
        log "Deleted: $file"
    fi
done < "$BACKUP_DIR/manager_files.txt"

log "Phase 1 Complete: Deleted $DELETED_COUNT Manager files"

# ============================================================================
# PHASE 2: CONSOLIDATE CHARACTER FILES (31 → 5)
# ============================================================================
log "========================================="
log "PHASE 2: Consolidating Character Files"
log "========================================="

# Define canonical character files
CANONICAL_CHARACTER="src/core/character/Character.gd"
CANONICAL_GENERATION="src/core/character/CharacterGeneration.gd"

# Files to keep
declare -a KEEP_CHARACTER=(
    "src/core/character/Character.gd"
    "src/core/character/CharacterGeneration.gd"
    "src/ui/components/character/CharacterSheet.gd"
    "src/ui/screens/character/CharacterBox.gd"
    "src/ui/screens/character/CharacterProgression.gd"
)

# Find all character files
find src -name "*Character*.gd" -type f > "$BACKUP_DIR/character_files.txt"

# Backup all character files
log "Backing up character files..."
mkdir -p "$BACKUP_DIR/character"
while IFS= read -r file; do
    cp "$file" "$BACKUP_DIR/character/$(basename "$file")"
done < "$BACKUP_DIR/character_files.txt"

# Delete duplicate character files (not in KEEP list)
log "Deleting duplicate character files..."
CHAR_DELETED=0
while IFS= read -r file; do
    # Check if file is in keep list
    KEEP=0
    for keep_file in "${KEEP_CHARACTER[@]}"; do
        if [ "$file" == "$keep_file" ]; then
            KEEP=1
            break
        fi
    done
    
    if [ $KEEP -eq 0 ] && [ -f "$file" ]; then
        git rm -f "$file" 2>/dev/null || rm -f "$file"
        ((CHAR_DELETED++))
        log "Deleted duplicate: $file"
    fi
done < "$BACKUP_DIR/character_files.txt"

log "Phase 2 Complete: Deleted $CHAR_DELETED duplicate character files"

# ============================================================================
# PHASE 3: CONSOLIDATE ENEMY FILES (14 → 3)
# ============================================================================
log "========================================="
log "PHASE 3: Consolidating Enemy Files"
log "========================================="

# Files to keep
declare -a KEEP_ENEMY=(
    "src/core/enemy/base/Enemy.gd"
    "src/ui/components/mission/EnemyInfoPanel.gd"
    "src/data/resources/EnemyDatabase.gd"
)

find src -name "*Enemy*.gd" -type f > "$BACKUP_DIR/enemy_files.txt"

# Backup
log "Backing up enemy files..."
mkdir -p "$BACKUP_DIR/enemy"
while IFS= read -r file; do
    cp "$file" "$BACKUP_DIR/enemy/$(basename "$file")"
done < "$BACKUP_DIR/enemy_files.txt"

# Delete duplicates
log "Deleting duplicate enemy files..."
ENEMY_DELETED=0
while IFS= read -r file; do
    KEEP=0
    for keep_file in "${KEEP_ENEMY[@]}"; do
        if [ "$file" == "$keep_file" ]; then
            KEEP=1
            break
        fi
    done
    
    if [ $KEEP -eq 0 ] && [ -f "$file" ]; then
        git rm -f "$file" 2>/dev/null || rm -f "$file"
        ((ENEMY_DELETED++))
        log "Deleted duplicate: $file"
    fi
done < "$BACKUP_DIR/enemy_files.txt"

log "Phase 3 Complete: Deleted $ENEMY_DELETED duplicate enemy files"

# ============================================================================
# PHASE 4: CONSOLIDATE MISSION FILES (23 → 13)
# ============================================================================
log "========================================="
log "PHASE 4: Consolidating Mission Files"
log "========================================="

# Files to keep
declare -a KEEP_MISSION=(
    "src/core/systems/Mission.gd"
    "src/core/mission/MissionObjective.gd"
    "src/game/missions/StreetFightMission.gd"
    "src/game/missions/StealthMission.gd"
    "src/game/missions/SalvageMission.gd"
    "src/game/missions/opportunity/RaidMission.gd"
    "src/game/missions/patron/InvestigationMission.gd"
    "src/game/missions/patron/EscortMission.gd"
    "src/game/missions/patron/DeliveryMission.gd"
    "src/game/missions/patron/BountyHuntingMission.gd"
    "src/ui/screens/world/MissionSelectionUI.gd"
    "src/ui/screens/world/components/MissionPrepPanel.gd"
    "src/ui/components/mission/MissionSummaryPanel.gd"
)

find src -name "*Mission*.gd" -type f > "$BACKUP_DIR/mission_files.txt"

# Backup
log "Backing up mission files..."
mkdir -p "$BACKUP_DIR/mission"
while IFS= read -r file; do
    cp "$file" "$BACKUP_DIR/mission/$(basename "$file")"
done < "$BACKUP_DIR/mission_files.txt"

# Delete duplicates
log "Deleting duplicate mission files..."
MISSION_DELETED=0
while IFS= read -r file; do
    KEEP=0
    for keep_file in "${KEEP_MISSION[@]}"; do
        if [ "$file" == "$keep_file" ]; then
            KEEP=1
            break
        fi
    done
    
    if [ $KEEP -eq 0 ] && [ -f "$file" ]; then
        git rm -f "$file" 2>/dev/null || rm -f "$file"
        ((MISSION_DELETED++))
        log "Deleted duplicate: $file"
    fi
done < "$BACKUP_DIR/mission_files.txt"

log "Phase 4 Complete: Deleted $MISSION_DELETED duplicate mission files"

# ============================================================================
# SUMMARY & FINAL REPORT
# ============================================================================
log "========================================="
log "DEDUPLICATION COMPLETE"
log "========================================="

FINAL_COUNT=$(find src -name "*.gd" -type f | wc -l)
TOTAL_DELETED=$((CURRENT_COUNT - FINAL_COUNT))

log ""
log "DEDUPLICATION SUMMARY:"
log "  Starting files:     $CURRENT_COUNT"
log "  Manager files:      -$DELETED_COUNT"
log "  Character files:    -$CHAR_DELETED"
log "  Enemy files:        -$ENEMY_DELETED"
log "  Mission files:      -$MISSION_DELETED"
log "  ----------------------------------------"
log "  Total deleted:      $TOTAL_DELETED"
log "  Final file count:   $FINAL_COUNT"
log ""
log "Reduction: $((TOTAL_DELETED * 100 / CURRENT_COUNT))%"
log ""
if [ $FINAL_COUNT -gt 20 ]; then
    warn "Still above Framework Bible limit of 20 files!"
    warn "Additional consolidation required: $((FINAL_COUNT - 20)) files to merge"
else
    log "✅ Framework Bible compliance achieved: $FINAL_COUNT files (≤20 limit)"
fi

log ""
log "Backup location: $BACKUP_DIR"
log "Log file: $LOG_FILE"
log ""
log "Next steps:"
log "1. Review deleted files in: $BACKUP_DIR"
log "2. Update references: run scripts/update_references.sh"
log "3. Test compilation: run Godot headless check"
log "4. Commit changes: git commit -m 'fix: massive deduplication - 260→$FINAL_COUNT files'"
log ""
log "Deduplication complete! 🎉"
