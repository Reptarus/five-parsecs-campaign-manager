class_name JobGenerator
extends Resource

signal jobs_generated(jobs: Array)
signal job_accepted(job: Dictionary)
signal job_completed(job: Dictionary, result: Dictionary)

var game_state: GameState
var available_jobs: Array = []
var active_jobs: Array = []
var completed_jobs: Array = []

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func generate_available_jobs() -> Array:
    var jobs = []
    var world = game_state.current_world
    
    if not world:
        return jobs
    
    # Generate jobs based on world type and conditions
    jobs.append_array(_generate_world_specific_jobs(world))
    jobs.append_array(_generate_faction_jobs(world))
    jobs.append_array(_generate_random_jobs(world))
    
    # Filter out jobs that don't meet requirements
    jobs = jobs.filter(func(job): return _validate_job_requirements(job))
    
    available_jobs = jobs
    jobs_generated.emit(jobs)
    return jobs

func accept_job(job: Dictionary) -> bool:
    if not _can_accept_job(job):
        return false
    
    available_jobs.erase(job)
    active_jobs.append(job)
    job_accepted.emit(job)
    return true

func complete_job(job: Dictionary, outcome: Dictionary) -> void:
    if job in active_jobs:
        active_jobs.erase(job)
        completed_jobs.append(job)
        
        var result = _process_job_completion(job, outcome)
        job_completed.emit(job, result)

func get_active_jobs() -> Array:
    return active_jobs

func get_completed_jobs() -> Array:
    return completed_jobs

func get_available_jobs() -> Array:
    return available_jobs

func get_job_requirements(job: Dictionary) -> Dictionary:
    return {
        "crew_size": job.get("required_crew", 1),
        "skills": job.get("required_skills", {}),
        "equipment": job.get("required_equipment", []),
        "reputation": job.get("required_reputation", 0),
        "resources": job.get("required_resources", [])
    }

func get_job_rewards(job: Dictionary) -> Dictionary:
    var base_rewards = job.get("rewards", {})
    var bonus_rewards = {}
    
    # Calculate bonus rewards based on conditions
    if _check_bonus_conditions(job):
        bonus_rewards = _generate_bonus_rewards(job)
    
    return {
        "base": base_rewards,
        "bonus": bonus_rewards,
        "total": _combine_rewards(base_rewards, bonus_rewards)
    }

# Helper Functions
func _generate_world_specific_jobs(world) -> Array:
    var jobs = []
    
    match world.type:
        "INDUSTRIAL":
            jobs.append_array(_generate_industrial_jobs(world))
        "AGRICULTURAL":
            jobs.append_array(_generate_agricultural_jobs(world))
        "MILITARY":
            jobs.append_array(_generate_military_jobs(world))
        "COMMERCIAL":
            jobs.append_array(_generate_commercial_jobs(world))
        "FRONTIER":
            jobs.append_array(_generate_frontier_jobs(world))
    
    return jobs

func _generate_faction_jobs(world) -> Array:
    var jobs = []
    
    for faction in world.active_factions:
        if faction.has_available_jobs:
            jobs.append_array(_generate_jobs_for_faction(faction))
    
    return jobs

func _generate_random_jobs(world) -> Array:
    var jobs = []
    var num_jobs = randi_range(2, 5)
    
    for i in range(num_jobs):
        var job = _generate_random_job(world)
        if job:
            jobs.append(job)
    
    return jobs

func _validate_job_requirements(job: Dictionary) -> bool:
    var requirements = get_job_requirements(job)
    
    # Check crew size
    if game_state.crew.size() < requirements.crew_size:
        return false
    
    # Check skills
    for skill in requirements.skills:
        var required_level = requirements.skills[skill]
        if not game_state.crew.has_skill_level(skill, required_level):
            return false
    
    # Check equipment
    for equipment in requirements.equipment:
        if not game_state.has_equipment(equipment):
            return false
    
    # Check reputation
    if game_state.reputation < requirements.reputation:
        return false
    
    # Check resources
    for resource in requirements.resources:
        if not game_state.has_resource(resource.type, resource.amount):
            return false
    
    return true

func _can_accept_job(job: Dictionary) -> bool:
    # Check if job is still available
    if job not in available_jobs:
        return false
    
    # Check if we have too many active jobs
    if active_jobs.size() >= game_state.max_active_jobs:
        return false
    
    # Validate requirements again in case something changed
    return _validate_job_requirements(job)

func _process_job_completion(job: Dictionary, outcome: Dictionary) -> Dictionary:
    var result = {
        "success": outcome.success,
        "rewards": {},
        "reputation_change": 0,
        "faction_relations": {}
    }
    
    if outcome.success:
        # Apply rewards
        var rewards = get_job_rewards(job)
        result.rewards = rewards.total
        _apply_rewards(rewards.total)
        
        # Update reputation
        result.reputation_change = job.get("reputation_gain", 10)
        game_state.adjust_reputation(result.reputation_change)
        
        # Update faction relations
        if "faction" in job:
            var faction_gain = job.get("faction_reputation_gain", 5)
            game_state.adjust_faction_relation(job.faction, faction_gain)
            result.faction_relations[job.faction] = faction_gain
    else:
        # Apply penalties
        result.reputation_change = job.get("reputation_loss", -5)
        game_state.adjust_reputation(result.reputation_change)
        
        if "faction" in job:
            var faction_loss = job.get("faction_reputation_loss", -3)
            game_state.adjust_faction_relation(job.faction, faction_loss)
            result.faction_relations[job.faction] = faction_loss
    
    return result

func _check_bonus_conditions(job: Dictionary) -> bool:
    var conditions = job.get("bonus_conditions", {})
    
    for condition in conditions:
        match condition.type:
            "TIME_LIMIT":
                if game_state.get_job_time(job) > condition.value:
                    return false
            "NO_CASUALTIES":
                if game_state.had_casualties_during_job(job):
                    return false
            "STEALTH":
                if not game_state.maintained_stealth_during_job(job):
                    return false
            "SPECIFIC_CREW":
                if not game_state.crew.has_member_with_traits(condition.traits):
                    return false
    
    return true

func _generate_bonus_rewards(job: Dictionary) -> Dictionary:
    var bonus_rewards = {}
    var bonus_types = job.get("possible_bonus_rewards", [])
    
    for bonus in bonus_types:
        if randf() <= bonus.chance:
            if bonus.type in bonus_rewards:
                bonus_rewards[bonus.type] += bonus.amount
            else:
                bonus_rewards[bonus.type] = bonus.amount
    
    return bonus_rewards

func _combine_rewards(base: Dictionary, bonus: Dictionary) -> Dictionary:
    var total = base.duplicate()
    
    for reward_type in bonus:
        if reward_type in total:
            total[reward_type] += bonus[reward_type]
        else:
            total[reward_type] = bonus[reward_type]
    
    return total

func _apply_rewards(rewards: Dictionary) -> void:
    for reward_type in rewards:
        match reward_type:
            "credits":
                game_state.add_credits(rewards.credits)
            "items":
                for item in rewards.items:
                    game_state.inventory.add_item(item)
            "resources":
                for resource in rewards.resources:
                    game_state.add_resource(resource.type, resource.amount)
            "equipment":
                for equipment in rewards.equipment:
                    game_state.add_equipment(equipment)

func _generate_industrial_jobs(world) -> Array:
    return [
        {
            "id": "factory_security",
            "type": "SECURITY",
            "name": "Factory Security",
            "description": "Provide security for an industrial complex",
            "required_crew": 2,
            "required_skills": {"combat": 2},
            "rewards": {
                "credits": 500,
                "reputation_gain": 15
            },
            "duration": 48,  # Hours
            "risk_level": "MEDIUM"
        },
        {
            "id": "machinery_transport",
            "type": "TRANSPORT",
            "name": "Machinery Transport",
            "description": "Transport sensitive industrial equipment",
            "required_crew": 1,
            "required_skills": {"technical": 1},
            "rewards": {
                "credits": 300,
                "reputation_gain": 10
            },
            "duration": 24,
            "risk_level": "LOW"
        }
    ]

func _generate_agricultural_jobs(world) -> Array:
    return [
        {
            "id": "pest_control",
            "type": "COMBAT",
            "name": "Pest Control",
            "description": "Clear dangerous pests from farmland",
            "required_crew": 2,
            "required_skills": {"combat": 1},
            "rewards": {
                "credits": 400,
                "reputation_gain": 10,
                "resources": [{"type": "FOOD", "amount": 5}]
            },
            "duration": 24,
            "risk_level": "MEDIUM"
        },
        {
            "id": "harvest_protection",
            "type": "SECURITY",
            "name": "Harvest Protection",
            "description": "Protect valuable harvest from raiders",
            "required_crew": 3,
            "required_skills": {"combat": 2},
            "rewards": {
                "credits": 600,
                "reputation_gain": 20
            },
            "duration": 72,
            "risk_level": "HIGH"
        }
    ]

func _generate_military_jobs(world) -> Array:
    return [
        {
            "id": "training_exercise",
            "type": "TRAINING",
            "name": "Training Exercise",
            "description": "Participate in military training exercise",
            "required_crew": 2,
            "required_skills": {"combat": 2},
            "rewards": {
                "credits": 300,
                "reputation_gain": 15,
                "skill_progress": {"combat": 20}
            },
            "duration": 24,
            "risk_level": "LOW"
        },
        {
            "id": "weapon_escort",
            "type": "ESCORT",
            "name": "Weapon Shipment Escort",
            "description": "Escort military weapon shipment",
            "required_crew": 3,
            "required_skills": {"combat": 3},
            "rewards": {
                "credits": 800,
                "reputation_gain": 25
            },
            "duration": 48,
            "risk_level": "HIGH"
        }
    ]

func _generate_commercial_jobs(world) -> Array:
    return [
        {
            "id": "valuable_cargo",
            "type": "TRANSPORT",
            "name": "Valuable Cargo Transport",
            "description": "Transport high-value commercial goods",
            "required_crew": 2,
            "required_skills": {"negotiation": 1},
            "rewards": {
                "credits": 400,
                "reputation_gain": 15
            },
            "duration": 24,
            "risk_level": "MEDIUM"
        },
        {
            "id": "market_security",
            "type": "SECURITY",
            "name": "Market Security",
            "description": "Provide security for busy market district",
            "required_crew": 2,
            "required_skills": {"combat": 1, "negotiation": 1},
            "rewards": {
                "credits": 300,
                "reputation_gain": 10
            },
            "duration": 48,
            "risk_level": "LOW"
        }
    ]

func _generate_frontier_jobs(world) -> Array:
    return [
        {
            "id": "exploration",
            "type": "EXPLORATION",
            "name": "Frontier Exploration",
            "description": "Explore and map unknown territory",
            "required_crew": 2,
            "required_skills": {"survival": 2},
            "rewards": {
                "credits": 600,
                "reputation_gain": 20,
                "bonus_conditions": [
                    {"type": "DISCOVERY", "reward": {"credits": 200}}
                ]
            },
            "duration": 72,
            "risk_level": "HIGH"
        },
        {
            "id": "settlement_defense",
            "type": "DEFENSE",
            "name": "Settlement Defense",
            "description": "Defend frontier settlement from threats",
            "required_crew": 3,
            "required_skills": {"combat": 2, "survival": 1},
            "rewards": {
                "credits": 700,
                "reputation_gain": 25
            },
            "duration": 48,
            "risk_level": "HIGH"
        }
    ]

func _generate_jobs_for_faction(faction) -> Array:
    var jobs = []
    var faction_jobs = faction.get_available_jobs()
    
    for job_template in faction_jobs:
        var job = job_template.duplicate(true)
        job.faction = faction.id
        job.faction_reputation_gain = faction.job_reputation_gain
        job.faction_reputation_loss = faction.job_reputation_loss
        jobs.append(job)
    
    return jobs

func _generate_random_job(world) -> Dictionary:
    var job_types = ["ESCORT", "DELIVERY", "SECURITY", "EXPLORATION", "COMBAT"]
    var selected_type = job_types[randi() % job_types.size()]
    
    var base_job = {
        "id": "random_" + str(randi()),
        "type": selected_type,
        "name": _generate_job_name(selected_type),
        "description": _generate_job_description(selected_type),
        "required_crew": randi_range(1, 3),
        "required_skills": _generate_required_skills(selected_type),
        "rewards": _generate_rewards(selected_type),
        "duration": randi_range(24, 72),
        "risk_level": _generate_risk_level()
    }
    
    return base_job

func _generate_job_name(job_type: String) -> String:
    var prefixes = ["Urgent ", "Routine ", "Special ", "Priority "]
    var prefix = prefixes[randi() % prefixes.size()]
    
    match job_type:
        "ESCORT":
            return prefix + "Escort Mission"
        "DELIVERY":
            return prefix + "Delivery Contract"
        "SECURITY":
            return prefix + "Security Detail"
        "EXPLORATION":
            return prefix + "Exploration Task"
        "COMBAT":
            return prefix + "Combat Operation"
        _:
            return prefix + "Mission"

func _generate_job_description(job_type: String) -> String:
    match job_type:
        "ESCORT":
            return "Provide escort services for a valuable target"
        "DELIVERY":
            return "Deliver important cargo to specified location"
        "SECURITY":
            return "Provide security services for a client"
        "EXPLORATION":
            return "Explore and document specified area"
        "COMBAT":
            return "Engage in combat operations"
        _:
            return "Complete specified mission objectives"

func _generate_required_skills(job_type: String) -> Dictionary:
    var skills = {}
    
    match job_type:
        "ESCORT", "COMBAT":
            skills["combat"] = randi_range(1, 3)
        "DELIVERY":
            skills["technical"] = randi_range(1, 2)
        "SECURITY":
            skills["combat"] = randi_range(1, 2)
            skills["negotiation"] = 1
        "EXPLORATION":
            skills["survival"] = randi_range(1, 2)
    
    return skills

func _generate_rewards(job_type: String) -> Dictionary:
    var base_credits = randi_range(200, 1000)
    var reputation_gain = randi_range(5, 25)
    
    var rewards = {
        "credits": base_credits,
        "reputation_gain": reputation_gain
    }
    
    # Add bonus rewards based on type
    match job_type:
        "COMBAT":
            rewards.credits *= 1.5
        "EXPLORATION":
            rewards["bonus_conditions"] = [
                {"type": "DISCOVERY", "reward": {"credits": base_credits * 0.5}}
            ]
    
    return rewards

func _generate_risk_level() -> String:
    var roll = randf()
    if roll < 0.4:
        return "LOW"
    elif roll < 0.8:
        return "MEDIUM"
    else:
        return "HIGH"
