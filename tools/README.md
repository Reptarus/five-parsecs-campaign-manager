# DLC Content Migration Tools

This directory contains tools for migrating existing content to the DLC system format, validating content against schemas, and testing DLC system integration.

## Tools Overview

### 1. migrate_dlc_content.gd

Command-line tool for performing content migrations, validations, and audits.

**Usage:**

```bash
godot --headless --script tools/migrate_dlc_content.gd -- <command> [options]
```

**Commands:**

- `migrate <input> <output> <type> <dlc_id>` - Migrate single file to DLC format
- `migrate-core <input> <output> <type>` - Mark file as core content
- `batch` - Run batch migration using predefined plan
- `validate <file>` - Validate file against schemas
- `audit <file>` - Audit file for DLC content distribution
- `test` - Test all DLC autoloads
- `help` - Show help message

**Examples:**

```bash
# Migrate Trailblazer's Toolkit species
godot --headless --script tools/migrate_dlc_content.gd -- migrate \
  data/dlc/tt_species.json \
  data/migrated/tt_species.json \
  species \
  trailblazers_toolkit

# Mark core content
godot --headless --script tools/migrate_dlc_content.gd -- migrate-core \
  data/species.json \
  data/migrated/species_core.json \
  species

# Run full batch migration
godot --headless --script tools/migrate_dlc_content.gd -- batch

# Validate migrated file
godot --headless --script tools/migrate_dlc_content.gd -- validate \
  data/migrated/tt_species.json

# Audit existing file
godot --headless --script tools/migrate_dlc_content.gd -- audit \
  data/species.json

# Test autoloads
godot --headless --script tools/migrate_dlc_content.gd -- test
```

## Utility Classes

### DLCContentMigrator

Located at `src/core/utils/DLCContentMigrator.gd`

**Purpose:** Migrate existing content to DLC system format by adding metadata and validating structure.

**Key Methods:**

- `add_dlc_metadata(item, content_type, dlc_id)` - Add DLC metadata to item
- `mark_as_core_content(item)` - Mark item as core content
- `migrate_content_array(items, content_type, dlc_id, is_core)` - Migrate array of items
- `validate_content(item, content_type)` - Validate against schema
- `audit_file(file_path)` - Audit file for DLC distribution
- `migrate_file(input, output, content_type, dlc_id, is_core)` - Migrate entire file
- `batch_migrate(migration_plan)` - Migrate multiple files

**Usage Example:**

```gdscript
var migrator := DLCContentMigrator.new()

# Migrate single item
var species = {"name": "Krag", "playable": true}
var migrated = migrator.add_dlc_metadata(species, "species", "trailblazers_toolkit")

# Migrate file
migrator.migrate_file(
    "res://data/tt_species.json",
    "res://data/migrated/tt_species.json",
    "species",
    "trailblazers_toolkit"
)

# Audit file
var audit = migrator.audit_file("res://data/species.json")
migrator.print_audit_report(audit)
```

### DLCContentValidator

Located at `src/core/utils/DLCContentValidator.gd`

**Purpose:** Validate DLC content against schemas and game rules for consistency and correctness.

**Key Methods:**

- `validate_item(item, content_type)` - Validate single item
- `validate_file(file_path)` - Validate entire file
- `validate_cross_dlc_reference(item, referenced_dlc)` - Check cross-DLC references
- `check_dlc_completeness(available_dlc)` - Check if all required DLC are present
- `batch_validate(file_paths)` - Validate multiple files
- `validate_dependencies(dlc_id, available_dlc)` - Validate DLC dependencies

**Usage Example:**

```gdscript
var validator := DLCContentValidator.new()

# Validate file
var validation = validator.validate_file("res://data/tt_species.json")
validator.print_validation_report(validation)

# Validate item
var errors = validator.validate_item(species_item, "species")
if errors.is_empty():
    print("Item is valid!")

# Batch validate
var files = [
    "res://data/species.json",
    "res://data/equipment.json",
    "res://data/enemies.json"
]
var batch_results = validator.batch_validate(files)
validator.print_batch_report(batch_results)
```

### DLCAutoloadSetup

Located at `src/core/utils/DLCAutoloadSetup.gd`

**Purpose:** Verify and configure DLC system autoloads.

**Key Methods:**

- `verify_autoloads()` - Check all required autoloads are registered
- `print_autoload_config()` - Print config for project.godot
- `get_autoload_config_string()` - Get config as string
- `get_diagnostics()` - Get diagnostic information
- `test_autoloads()` - Test all autoload functionality

**Usage Example:**

```gdscript
var setup := DLCAutoloadSetup.new()

# Verify autoloads
if setup.verify_autoloads():
    print("All autoloads configured!")
else:
    setup.print_autoload_config()

# Test functionality
setup.test_autoloads()

# Get diagnostics
var diag = setup.get_diagnostics()
print("Registered: %d/%d" % [diag.registered, diag.total_required])
```

## Migration Workflow

### Step 1: Audit Existing Content

First, audit your existing content to identify what needs to be migrated:

```bash
godot --headless --script tools/migrate_dlc_content.gd -- audit data/species.json
```

This will show you:
- Total items in file
- How many are core vs DLC
- Distribution by DLC
- Items missing metadata

### Step 2: Run Batch Migration

Use the batch migration command to migrate all known files:

```bash
godot --headless --script tools/migrate_dlc_content.gd -- batch
```

This will:
- Create `data/migrated/` directory
- Migrate all files according to predefined plan
- Add DLC metadata to all items
- Validate migrated content

### Step 3: Validate Migrated Content

Validate the migrated files to ensure correctness:

```bash
godot --headless --script tools/migrate_dlc_content.gd -- validate data/migrated/tt_species.json
```

This will check:
- All required fields are present
- Field types are correct
- Enum values are valid
- Custom validation rules pass

### Step 4: Test Autoloads

Verify DLC systems are properly configured:

```bash
godot --headless --script tools/migrate_dlc_content.gd -- test
```

This will:
- Check all autoloads are registered
- Test each system's functionality
- Report any configuration issues

### Step 5: Manual Review

Review the migration log and validation reports:

```gdscript
# In your code
var migrator := DLCContentMigrator.new()
migrator.batch_migrate(migrator.generate_migration_plan())
migrator.print_migration_log()
```

## Migration Plan

The default migration plan includes:

**Core Content:**
- `data/species.json` → `data/migrated/species_core.json`
- `data/equipment.json` → `data/migrated/equipment_core.json`
- `data/enemies.json` → `data/migrated/enemies_core.json`

**Trailblazer's Toolkit:**
- `data/dlc/trailblazers_toolkit_species.json` → `data/migrated/tt_species.json`
- `data/dlc/trailblazers_toolkit_psionic_powers.json` → `data/migrated/tt_psionic_powers.json`

**Freelancer's Handbook:**
- `data/dlc/freelancers_handbook_elite_enemies.json` → `data/migrated/fh_elite_enemies.json`
- `data/dlc/freelancers_handbook_difficulty_modifiers.json` → `data/migrated/fh_difficulty_modifiers.json`

**Fixer's Guidebook:**
- `data/dlc/fixers_guidebook_missions.json` → `data/migrated/fg_missions.json`

## Custom Migration Plan

To create a custom migration plan:

```gdscript
var migrator := DLCContentMigrator.new()

var custom_plan := [
    {
        "input": "res://my_data/species.json",
        "output": "res://migrated/species.json",
        "content_type": "species",
        "dlc_id": "trailblazers_toolkit"
    },
    {
        "input": "res://my_data/equipment.json",
        "output": "res://migrated/equipment.json",
        "content_type": "equipment",
        "is_core": true
    }
]

var results = migrator.batch_migrate(custom_plan)
```

## Validation Rules

The validator checks:

### Schema Validation

- Required fields are present
- Field types match schema
- Enum values are valid

### Content-Specific Validation

**Species:**
- Playable species have starting_bonus
- Trait count is reasonable (≤5)

**Psionic Powers:**
- Target type is valid (self/enemy/any)
- Activation has required fields

**Elite Enemies:**
- Deployment points are reasonable (1-10)
- Special abilities have name and effect

**Difficulty Modifiers:**
- Category is valid
- Mechanical changes are defined

**Mission Templates:**
- Has at least one objective
- Rewards structure is complete

### Cross-DLC Validation

- Cross-DLC references are valid
- Required DLC dependencies are met
- Bundle content includes all required DLC

## Troubleshooting

### "Failed to open file"

**Solution:** Check file path is correct and file exists. Use `res://` for project-relative paths.

### "JSON parse error"

**Solution:** Validate JSON syntax. Common issues:
- Missing commas between items
- Trailing commas
- Unescaped quotes in strings

### "Missing required field"

**Solution:** Check schema in `docs/schemas/dlc_data_schemas.json` for required fields.

### "Invalid value for dlc_required"

**Solution:** Use one of the valid DLC IDs:
- `trailblazers_toolkit`
- `freelancers_handbook`
- `fixers_guidebook`
- `bug_hunt`
- `null` (for core content)

### "Autoload not found"

**Solution:** Run test command to check autoload configuration:

```bash
godot --headless --script tools/migrate_dlc_content.gd -- test
```

Then add missing autoloads to `project.godot` as shown in the output.

## Best Practices

1. **Always backup before migrating**
   ```bash
   cp -r data/ data_backup/
   ```

2. **Audit before migrating**
   - Understand current content distribution
   - Identify items needing migration

3. **Validate after migrating**
   - Ensure all content meets schema requirements
   - Fix any validation errors

4. **Test incrementally**
   - Migrate one DLC at a time
   - Test game functionality after each migration

5. **Keep migration log**
   - Review migration log for issues
   - Document any manual changes needed

6. **Version control**
   - Commit before migration
   - Review diffs after migration
   - Create separate branch for migration work

## See Also

- [DLC Systems Integration Guide](../docs/DLC_SYSTEMS_INTEGRATION_GUIDE.md)
- [Expansion Addon Architecture](../docs/planning/EXPANSION_ADDON_ARCHITECTURE.md)
- [DLC Data Schemas](../docs/schemas/dlc_data_schemas.json)
- [Example DLC Data](../docs/schemas/example_dlc_data/)
