#!/bin/bash
# Delete SAFE Manager duplicates only
# These are confirmed duplicates with no unique functionality

PROJECT_ROOT="C:/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager"
BACKUP_DIR="$PROJECT_ROOT/backup/safe_managers_$(date +%Y%m%d_%H%M%S)"

cd "$PROJECT_ROOT"
mkdir -p "$BACKUP_DIR"

echo "========================================="
echo "SAFE MANAGER DELETION"
echo "========================================="
echo ""

# Array of safe-to-delete Manager files
SAFE_DELETES=(
    # Data Manager Duplicates
    "src/core/data/SimplifiedDataManager.gd"
    "src/core/data/LazyDataManager.gd"
    "src/core/character/Management/CharacterDataManager.gd"
    
    # Save Manager Duplicates
    "src/core/validation/SecureSaveManager.gd"
    "src/core/workflow/ProductionSaveManager.gd"
    
    # Campaign Manager Duplicates
    "src/base/campaign/BaseCampaignManager.gd"
    "src/core/campaign/CampaignCreationManager.gd"
    "src/core/campaign/GameCampaignManager.gd"
    "src/ui/screens/campaign/CampaignManager.gd"
    
    # Dice Manager Duplicate
    "src/core/systems/FallbackDiceManager.gd"
    
    # Fallback/Helper Managers
    "src/core/systems/FallbackCampaignManager.gd"
    "src/core/systems/AutoloadManager.gd"
    "src/core/systems/CampaignCreationRollbackManager.gd"
    "src/core/workflow/WorkflowContextManager.gd"
    
    # Character Managers
    "src/core/character/Management/CharacterManager.gd"
    "src/ui/screens/character/AdvancementManager.gd"
    
    # Enemy Managers
    "src/core/managers/EnemyManager.gd"
    "src/core/managers/EnemyDeploymentManager.gd"
    "src/core/managers/EnemyAIManager.gd"
    
    # Battle Managers
    "src/core/battle/BattlefieldManager.gd"
    "src/core/battle/BattlefieldDisplayManager.gd"
    "src/core/battle/BattleResultsManager.gd"
    "src/core/battle/FPCM_BattleManager.gd"
    "src/base/combat/BaseCombatManager.gd"
    "src/base/combat/battlefield/BaseBattlefieldManager.gd"
    
    # Equipment/Ship Managers
    "src/ui/screens/equipment/EquipmentManager.gd"
    "src/ui/screens/ships/ShipManager.gd"
)

echo "Files to delete: ${#SAFE_DELETES[@]}"
echo ""

# Backup and delete
DELETED=0
for file in "${SAFE_DELETES[@]}"; do
    if [ -f "$file" ]; then
        # Backup
        mkdir -p "$BACKUP_DIR/$(dirname "$file")"
        cp "$file" "$BACKUP_DIR/$file"
        
        # Delete
        git rm -f "$file" 2>/dev/null || rm -f "$file"
        echo "✓ Deleted: $file"
        ((DELETED++))
    else
        echo "✗ Not found: $file"
    fi
done

echo ""
echo "========================================="
echo "DELETION COMPLETE"
echo "========================================="
echo "Deleted: $DELETED files"
echo "Backup: $BACKUP_DIR"
echo ""
