GdUnit Test Client connected with id: -9223208283441874645
Run Test Suite: res://tests/unit/battle/ai/test_enemy_ai.gd
test_enemy_ai > test_ai_initialization                                              PASSED 21ms
test_enemy_ai > test_target_selection                                               PASSED 20ms
test_enemy_ai > test_movement_decisions                                             PASSED 21ms
test_enemy_ai > test_combat_behavior                                                PASSED 20ms
test_enemy_ai > test_tactical_analysis                                              PASSED 20ms
test_enemy_ai > test_ai_performance                                                 PASSED 20ms
test_enemy_ai > test_error_handling                                                 PASSED 20ms
Statistics: 7 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 250ms

Run Test Suite: res://tests/unit/battle/ai/test_enemy_state.gd
test_enemy_state > test_basic_state                                                 PASSED 14ms
test_enemy_state > test_state_persistence                                           PASSED 22ms
test_enemy_state > test_group_state_persistence                                     PASSED 35ms
test_enemy_state > test_combat_state_persistence                                    PASSED 21ms
test_enemy_state > test_ai_state_persistence                                        PASSED 21ms
test_enemy_state > test_equipment_persistence                                       PASSED 20ms
test_enemy_state > test_invalid_state_handling                                      PASSED 20ms
Statistics: 7 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 259ms

Run Test Suite: res://tests/unit/battle/scaling/test_enemy_scaling.gd
test_enemy_scaling > test_base_values                                               PASSED 15ms
test_enemy_scaling > test_easy_difficulty_scaling                                   PASSED 20ms
test_enemy_scaling > test_normal_difficulty_scaling                                 PASSED 20ms
test_enemy_scaling > test_hard_difficulty_scaling                                   PASSED 20ms
test_enemy_scaling > test_elite_difficulty_scaling                                  PASSED 20ms
test_enemy_scaling > test_hardcore_difficulty_scaling                               PASSED 21ms
test_enemy_scaling > test_green_zone_scaling                                        PASSED 20ms
test_enemy_scaling > test_red_zone_scaling                                          PASSED 20ms
test_enemy_scaling > test_black_zone_scaling                                        PASSED 20ms
test_enemy_scaling > test_level_scaling                                             PASSED 20ms
test_enemy_scaling > test_combined_scaling                                          PASSED 21ms
test_enemy_scaling > test_extreme_scaling_combination                               PASSED 34ms
Statistics: 12 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 431ms

Run Test Suite: res://tests/unit/battle/test_battlefield_generator_crew.gd
test_battlefield_generator_crew > test_initial_setup                                PASSED 37ms
test_battlefield_generator_crew > test_character_components                         PASSED 13ms
test_battlefield_generator_crew > test_health_bar_setup                             PASSED 7ms
test_battlefield_generator_crew > test_character_script                             PASSED 9ms
test_battlefield_generator_crew > test_systems_setup                                PASSED 9ms
test_battlefield_generator_crew > test_component_initialization_performance         PASSED 13ms
Statistics: 6 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 232ms

Run Test Suite: res://tests/unit/battle/test_battlefield_generator_enemy.gd
test_battlefield_generator_enemy > test_initial_setup                               PASSED 25ms
test_battlefield_generator_enemy > test_enemy_components                            PASSED 25ms
test_battlefield_generator_enemy > test_health_bar_setup                            PASSED 15ms
test_battlefield_generator_enemy > test_enemy_script                                PASSED 14ms
test_battlefield_generator_enemy > test_systems_setup                               PASSED 8ms
test_battlefield_generator_enemy > test_component_initialization_performance        PASSED 14ms
Statistics: 6 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 220ms

Run Test Suite: res://tests/unit/battle/test_battle_event_types.gd
test_battle_event_types > test_battle_event_definitions                             PASSED 22ms
test_battle_event_types > test_critical_hit_event                                   PASSED 20ms
test_battle_event_types > test_weapon_jam_event                                     PASSED 35ms
test_battle_event_types > test_take_cover_event                                     PASSED 33ms
test_battle_event_types > test_check_event_requirements                             PASSED 29ms
test_battle_event_types > test_compare_value                                        PASSED 34ms
test_battle_event_types > test_invalid_event_handling                               PASSED 21ms
test_battle_event_types > test_event_processing_performance                         PASSED 34ms
Statistics: 8 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 354ms

Run Test Suite: res://tests/unit/battle/test_battle_state_machine.gd
test_battle_state_machine > test_battle_state_initialization                        PASSED 28ms
test_battle_state_machine > test_start_battle                                       PASSED 27ms
test_battle_state_machine > test_end_battle                                         PASSED 34ms
test_battle_state_machine > test_phase_transitions                                  PASSED 34ms
test_battle_state_machine > test_add_combatant                                      PASSED 28ms
test_battle_state_machine > test_save_and_load_state                                PASSED 35ms
test_battle_state_machine > test_rapid_state_transitions                            PASSED 21ms
test_battle_state_machine > test_invalid_phase_transition                           PASSED 34ms
test_battle_state_machine > test_invalid_battle_start                               PASSED 34ms
test_battle_state_machine > test_phase_transition_signals                           PASSED 20ms
Statistics: 10 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 458ms

Run Test Suite: res://tests/unit/battle/test_combat_flow.gd
test_combat_flow > test_battle_phase_transitions                                    PASSED 28ms
test_combat_flow > test_combat_actions                                              PASSED 26ms
test_combat_flow > test_state_management                                            PASSED 34ms
test_combat_flow > test_battle_signals                                              PASSED 35ms
test_combat_flow > test_round_management                                            PASSED 20ms
test_combat_flow > test_combatant_management                                        PASSED 43ms
test_combat_flow > test_save_load_state                                             PASSED 20ms
test_combat_flow > test_invalid_transitions                                         PASSED 34ms
test_combat_flow > test_action_processing_performance                               PASSED 20ms
Statistics: 9 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 409ms

Run Test Suite: res://tests/unit/battle/test_enemy_tactical_ai.gd
test_enemy_tactical_ai > test_ai_personality_types                                  PASSED 15ms
test_enemy_tactical_ai > test_group_tactic_types                                    PASSED 35ms
test_enemy_tactical_ai > test_decision_making_signals                               PASSED 35ms
test_enemy_tactical_ai > test_tactic_change_signals                                 PASSED 35ms
test_enemy_tactical_ai > test_group_coordination_signals                            PASSED 34ms
test_enemy_tactical_ai > test_enemy_personality_tracking                            PASSED 34ms
test_enemy_tactical_ai > test_group_assignment_tracking                             PASSED 20ms
test_enemy_tactical_ai > test_tactical_state_tracking                               PASSED 20ms
test_enemy_tactical_ai > test_ai_decision_making                                    PASSED 33ms
test_enemy_tactical_ai > test_group_coordination                                    PASSED 34ms
test_enemy_tactical_ai > test_invalid_enemy_handling                                PASSED 27ms
test_enemy_tactical_ai > test_decision_making_performance                           PASSED 34ms
Statistics: 12 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 561ms

Run Test Suite: res://tests/unit/battle/test_objective_marker.gd
test_objective_marker > test_initial_setup                                          PASSED 20ms
test_objective_marker > test_unit_enters_objective                                  PASSED 34ms
test_objective_marker > test_enemy_unit_triggers_fail                               PASSED 42ms
test_objective_marker > test_unit_exits_objective                                   PASSED 35ms
test_objective_marker > test_objective_completion                                   PASSED 33ms
test_objective_marker > test_progress_tracking                                      PASSED 35ms
test_objective_marker > test_multiple_units_interaction                             PASSED 35ms
test_objective_marker > test_invalid_area_handling                                  PASSED 34ms
test_objective_marker > test_turn_processing_performance                            PASSED 20ms
Statistics: 9 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 437ms

Run Test Suite: res://tests/unit/campaign/test_campaign_state.gd
test_campaign_state > test_initial_state                                            PASSED 28ms
test_campaign_state > test_campaign_creation                                        PASSED 21ms
test_campaign_state > test_campaign_settings                                        PASSED 21ms
Statistics: 3 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 127ms

Run Test Suite: res://tests/unit/campaign/test_campaign_system.gd
test_campaign_system > test_campaign_initialization                                 PASSED 21ms
test_campaign_system > test_resource_management                                     PASSED 20ms
test_campaign_system > test_reputation_system                                       PASSED 13ms
test_campaign_system > test_mission_tracking                                        PASSED 21ms
test_campaign_system > test_rapid_mission_completion                                PASSED 20ms
test_campaign_system > test_invalid_mission_handling                                PASSED 14ms
test_campaign_system > test_resource_signals                                        PASSED 14ms
test_campaign_system > test_resource_boundaries                                     PASSED 13ms
Statistics: 8 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 286ms

Run Test Suite: res://tests/unit/campaign/test_game_state_manager.gd
test_game_state_manager > test_initial_state                                        FAILED 28ms
Report:
line <n/a>: Expecting emit signal: 'state_changed()' but timed out after 2s 0ms

test_game_state_manager > test_difficulty_change                                    PASSED 14ms
test_game_state_manager > test_resource_management                                  PASSED 13ms
test_game_state_manager > test_game_state_transitions                               PASSED 13ms
test_game_state_manager > test_campaign_phase_transitions                           PASSED 13ms
test_game_state_manager > test_resource_limits                                      PASSED 20ms
test_game_state_manager > test_rapid_state_changes                                  PASSED 21ms
test_game_state_manager > test_invalid_state_transitions                            PASSED 13ms
Statistics: 8 tests cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans | FAILED 293ms

Run Test Suite: res://tests/unit/campaign/test_resource_system.gd
test_resource_system > test_system_initialization                                   PASSED 8ms
test_resource_system > test_resource_management                                     PASSED 20ms
test_resource_system > test_resource_types                                          PASSED 15ms
test_resource_system > test_resource_limits                                         PASSED 14ms
test_resource_system > test_resource_conversion                                     PASSED 14ms
test_resource_system > test_resource_generation                                     PASSED 13ms
test_resource_system > test_resource_consumption                                    PASSED 14ms
test_resource_system > test_resource_state                                          PASSED 13ms
test_resource_system > test_resource_persistence                                    PASSED 14ms
test_resource_system > test_error_handling                                          PASSED 13ms
test_resource_system > test_system_state                                            PASSED 14ms
Statistics: 11 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 376ms

Run Test Suite: res://tests/unit/campaign/test_rival.gd
test_rival > test_initialization                                                    PASSED 7ms
test_rival > test_hostility_management                                              PASSED 13ms
test_rival > test_threat_level_management                                           PASSED 21ms
test_rival > test_resource_management                                               PASSED 21ms
test_rival > test_activity_status                                                   PASSED 14ms
test_rival > test_encounter_generation                                              PASSED 14ms
test_rival > test_serialization                                                     PASSED 13ms
Statistics: 7 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 237ms

Run Test Suite: res://tests/unit/campaign/test_rival_system.gd
test_rival_system > test_initialization                                             PASSED 9ms
test_rival_system > test_create_rival                                               PASSED 13ms
test_rival_system > test_create_rival_with_defaults                                 PASSED 20ms
test_rival_system > test_rival_defeat                                               PASSED 20ms
test_rival_system > test_rival_escape                                               PASSED 21ms
test_rival_system > test_modify_rival_reputation                                    PASSED 20ms
test_rival_system > test_rival_encounters                                           PASSED 20ms
test_rival_system > test_serialization                                              PASSED 21ms
Statistics: 8 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 272ms

Run Test Suite: res://tests/unit/campaign/test_ship_component_system.gd
test_ship_component_system > test_component_initialization                          PASSED 9ms
test_ship_component_system > test_component_management                              PASSED 21ms
test_ship_component_system > test_component_types                                   PASSED 20ms
test_ship_component_system > test_component_slots                                   PASSED 14ms
test_ship_component_system > test_component_installation                            PASSED 14ms
test_ship_component_system > test_component_status                                  PASSED 13ms
test_ship_component_system > test_component_power                                   PASSED 20ms
Statistics: 7 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 231ms

Run Test Suite: res://tests/unit/campaign/test_ship_component_unit.gd
test_ship_component_unit > test_initialization                                      PASSED 8ms
test_ship_component_unit > test_component_status                                    PASSED 14ms
Statistics: 2 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 65ms

Run Test Suite: res://tests/unit/campaign/test_story_quest_data.gd
test_story_quest_data > test_initialization                                         PASSED 15ms
test_story_quest_data > test_objective_management                                   PASSED 13ms
test_story_quest_data > test_reward_management                                      PASSED 13ms
test_story_quest_data > test_prerequisite_management                                PASSED 21ms
test_story_quest_data > test_serialization                                          PASSED 21ms
Statistics: 5 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 173ms

Run Test Suite: res://tests/unit/campaign/test_unified_story_system.gd
test_unified_story_system > test_initial_setup                                      PASSED 22ms
test_unified_story_system > test_story_initialization                               PASSED 21ms
test_unified_story_system > test_quest_addition                                     PASSED 13ms
test_unified_story_system > test_quest_completion                                   PASSED 14ms
test_unified_story_system > test_quest_failure                                      PASSED 13ms
test_unified_story_system > test_quest_dependencies                                 PASSED 14ms
test_unified_story_system > test_quest_state_persistence                            PASSED 13ms
test_unified_story_system > test_invalid_quest_operations                           PASSED 13ms
test_unified_story_system > test_quest_validation                                   PASSED 13ms
Statistics: 9 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 313ms

Run Test Suite: res://tests/unit/character/test_advancement_rules.gd
test_advancement_rules > test_bot_experience_rules                                  PASSED 34ms
test_advancement_rules > test_experience_limits                                     PASSED 20ms
test_advancement_rules > test_soulless_training_restrictions                        PASSED 22ms
test_advancement_rules > test_training_progression                                  PASSED 14ms
test_advancement_rules > test_engineer_toughness_limit                              PASSED 20ms
test_advancement_rules > test_rapid_experience_gain                                 PASSED 14ms
test_advancement_rules > test_invalid_training_transitions                          PASSED 21ms
test_advancement_rules > test_invalid_experience_values                             PASSED 21ms
Statistics: 8 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 299ms

Run Test Suite: res://tests/unit/character/test_character_data_manager.gd
test_character_data_manager > test_initial_state                                    PASSED 56ms
test_character_data_manager > test_save_and_load_character                          PASSED 138ms
test_character_data_manager > test_batch_character_operations                       PASSED 138ms
test_character_data_manager > test_character_limit                                  PASSED 131ms
test_character_data_manager > test_signal_emission_order                            PASSED 132ms
test_character_data_manager > test_invalid_character_operations                     PASSED 138ms
Statistics: 6 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 835ms

Run Test Suite: res://tests/unit/character/test_character_manager.gd
test_character_manager > test_create_character                                      PASSED 21ms
test_character_manager > test_add_relationship                                      PASSED 34ms
test_character_manager > test_asymmetric_relationships                              PASSED 35ms
test_character_manager > test_nonexistent_relationship                              PASSED 33ms
test_character_manager > test_calculate_crew_morale                                 PASSED 34ms
Statistics: 5 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 241ms

Run Test Suite: res://tests/unit/character/test_crew_equipment.gd
test_crew_equipment > test_equipment_slots                                          PASSED 77ms
test_crew_equipment > test_equipment_stats                                          PASSED 117ms
test_crew_equipment > test_equipment_requirements                                   PASSED 117ms
test_crew_equipment > test_equipment_effects                                        PASSED 118ms
test_crew_equipment > test_equipment_durability                                     PASSED 117ms
Statistics: 5 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 636ms

Run Test Suite: res://tests/unit/core/test_core_features.gd
test_core_features > test_initial_state                                             PASSED 29ms
test_core_features > test_game_state_transitions                                    PASSED 21ms
test_core_features > test_campaign_phase_transitions                                PASSED 13ms
test_core_features > test_combat_phase_transitions                                  PASSED 13ms
test_core_features > test_invalid_state_transitions                                 PASSED 13ms
test_core_features > test_rapid_state_transitions                                   PASSED 21ms
test_core_features > test_state_dependencies                                        PASSED 21ms
Statistics: 7 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 259ms

Run Test Suite: res://tests/unit/core/test_error_logger.gd
test_error_logger > test_basic_error_logging                                        PASSED 8ms
test_error_logger > test_error_with_context                                         PASSED 14ms
test_error_logger > test_multiple_errors                                            PASSED 13ms
test_error_logger > test_error_categories                                           PASSED 13ms
test_error_logger > test_error_severity                                             PASSED 14ms
test_error_logger > test_initial_state                                              PASSED 21ms
test_error_logger > test_log_error                                                  PASSED 21ms
test_error_logger > test_clear_errors                                               PASSED 13ms
test_error_logger > test_error_severity_levels                                      PASSED 13ms
test_error_logger > test_phase_transition_errors                                    PASSED 14ms
test_error_logger > test_combat_validation_errors                                   PASSED 14ms
test_error_logger > test_verification_errors                                        PASSED 13ms
test_error_logger > test_empty_message_handling                                     PASSED 14ms
test_error_logger > test_invalid_category_handling                                  PASSED 13ms
test_error_logger > test_large_error_count                                          PASSED 13ms
test_error_logger > test_concurrent_operations                                      PASSED 14ms
test_error_logger > test_error_signal_payload                                       PASSED 14ms
test_error_logger > test_multiple_error_signals                                     PASSED 13ms
Statistics: 18 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 603ms

Run Test Suite: res://tests/unit/core/test_game_settings.gd
test_game_settings > test_initialization                                            PASSED 7ms
test_game_settings > test_difficulty_settings                                       PASSED 21ms
test_game_settings > test_campaign_settings                                         PASSED 21ms
test_game_settings > test_tutorial_settings                                         PASSED 13ms
test_game_settings > test_auto_save_settings                                        PASSED 14ms
test_game_settings > test_audio_settings                                            PASSED 14ms
test_game_settings > test_serialization                                             PASSED 21ms
Statistics: 7 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 234ms

Run Test Suite: res://tests/unit/core/test_game_state.gd
test_game_state > test_create_game_state                                            PASSED 34ms
test_game_state > test_phase_management                                             PASSED 21ms
test_game_state > test_turn_management                                              PASSED 20ms
test_game_state > test_resource_management                                          PASSED 13ms
test_game_state > test_quest_management                                             PASSED 13ms
test_game_state > test_location_management                                          PASSED 14ms
test_game_state > test_ship_management                                              PASSED 19ms
test_game_state > test_state_serialization                                          PASSED 22ms
test_game_state > test_state_validation                                             PASSED 13ms
Statistics: 9 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 327ms

Run Test Suite: res://tests/unit/core/test_game_state_adapter.gd
test_game_state_adapter > test_can_create_game_state_instance                       PASSED 22ms
test_game_state_adapter > test_can_create_default_test_state                        PASSED 21ms
test_game_state_adapter > test_can_deserialize_from_dict                            PASSED 14ms
Statistics: 3 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 127ms

Run Test Suite: res://tests/unit/core/test_house_rules_core.gd
test_house_rules_core > test_rule_registration                                      PASSED 7ms
test_house_rules_core > test_rule_enabling                                          PASSED 14ms
test_house_rules_core > test_rule_settings                                          PASSED 13ms
test_house_rules_core > test_invalid_rule_handling                                  PASSED 12ms
test_house_rules_core > test_rule_performance                                       PASSED 20ms
Statistics: 5 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 160ms

Run Test Suite: res://tests/unit/core/test_override_core.gd
test_override_core > test_override_registration                                     PASSED 8ms
test_override_core > test_override_enabling                                         PASSED 14ms
test_override_core > test_override_settings                                         PASSED 14ms
test_override_core > test_invalid_override_handling                                 PASSED 13ms
test_override_core > test_override_performance                                      PASSED 13ms
Statistics: 5 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 169ms

Run Test Suite: res://tests/unit/core/test_save_manager.gd
test_save_manager > test_initialization                                             PASSED 7ms
test_save_manager > test_save_file_management                                       PASSED 14ms
test_save_manager > test_auto_save_functionality                                    PASSED 20ms
test_save_manager > test_save_data_validation                                       PASSED 13ms
test_save_manager > test_save_backup_management                                     PASSED 14ms
test_save_manager > test_save_metadata                                              PASSED 13ms
test_save_manager > test_save_compression                                           PASSED 21ms
Statistics: 7 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 231ms

Run Test Suite: res://tests/unit/core/test_sector_manager.gd
test_sector_manager > test_initialization                                           PASSED 14ms
test_sector_manager > test_sector_generation                                        PASSED 21ms
test_sector_manager > test_sector_connections                                       PASSED 21ms
test_sector_manager > test_serialization                                            PASSED 21ms
test_sector_manager > test_generate_sector                                          PASSED 21ms
test_sector_manager > test_get_planet_at_coordinates                                PASSED 20ms
test_sector_manager > test_sector_serialization                                     PASSED 20ms
test_sector_manager > test_migration_utility                                        FAILED 21ms
Report:
line <n/a>: Expecting: 'true' but is 'false'

Statistics: 8 tests cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans | FAILED 278ms

Run Test Suite: res://tests/unit/core/test_serializable_resource.gd
test_serializable_resource > test_initialization                                    PASSED 14ms
test_serializable_resource > test_serialization                                     PASSED 13ms
test_serializable_resource > test_id_uniqueness                                     PASSED 13ms
test_serializable_resource > test_resource_initialization                           PASSED 14ms
test_serializable_resource > test_resource_serialization                            PASSED 20ms
test_serializable_resource > test_resource_deserialization                          PASSED 22ms
test_serializable_resource > test_resource_null_deserialization                     PASSED 21ms
test_serializable_resource > test_resource_invalid_deserialization                  PASSED 21ms
test_serializable_resource > test_factory_method                                    PASSED 20ms
Statistics: 9 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 306ms

Run Test Suite: res://tests/unit/ships/test_ship.gd
test_ship > test_ship_initialization                                                PASSED 22ms
test_ship > test_ship_components                                                    PASSED 8ms
test_ship > test_ship_crew_capacity                                                 PASSED 14ms
test_ship > test_ship_damage_system                                                 PASSED 13ms
test_ship > test_ship_repair_system                                                 PASSED 21ms
test_ship > test_ship_power_system                                                  PASSED 21ms
Statistics: 6 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 210ms

Run Test Suite: res://tests/unit/ui/campaign/test_campaign_phase_ui.gd
test_campaign_phase_ui > test_ui_initialization                                     PASSED 23ms
test_campaign_phase_ui > test_phase_display                                         PASSED 55ms
test_campaign_phase_ui > test_phase_buttons                                         PASSED 34ms
test_campaign_phase_ui > test_phase_transitions                                     PASSED 35ms
test_campaign_phase_ui > test_phase_actions                                         PASSED 35ms
test_campaign_phase_ui > test_phase_information                                     PASSED 33ms
test_campaign_phase_ui > test_phase_validation                                      PASSED 34ms
test_campaign_phase_ui > test_ui_state                                              PASSED 103ms
test_campaign_phase_ui > test_error_handling                                        PASSED 21ms
Statistics: 9 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 522ms

Run Test Suite: res://tests/unit/ui/campaign/test_phase_indicator.gd
test_phase_indicator > test_initialization                                          PASSED 16ms
test_phase_indicator > test_phase_display                                           PASSED 35ms
test_phase_indicator > test_phase_icon                                              PASSED 41ms
test_phase_indicator > test_phase_progress                                          PASSED 34ms
test_phase_indicator > test_phase_state                                             PASSED 34ms
test_phase_indicator > test_phase_description                                       PASSED 34ms
test_phase_indicator > test_phase_transition                                        PASSED 34ms
test_phase_indicator > test_phase_validation                                        PASSED 34ms
test_phase_indicator > test_ui_state                                                PASSED 48ms
test_phase_indicator > test_theme                                                   PASSED 34ms
Statistics: 10 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 514ms

Run Test Suite: res://tests/unit/ui/campaign/test_resource_item.gd
test_resource_item > test_item_initialization                                       PASSED 28ms
test_resource_item > test_resource_value                                            PASSED 20ms
test_resource_item > test_resource_type                                             PASSED 35ms
test_resource_item > test_resource_label                                            PASSED 21ms
test_resource_item > test_resource_state                                            PASSED 35ms
test_resource_item > test_resource_tooltip                                          PASSED 20ms
test_resource_item > test_resource_animation                                        PASSED 35ms
test_resource_item > test_resource_interaction                                      PASSED 20ms
test_resource_item > test_resource_validation                                       PASSED 34ms
test_resource_item > test_ui_state                                                  PASSED 21ms
test_resource_item > test_theme_handling                                            PASSED 35ms
Statistics: 11 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 478ms

Run Test Suite: res://tests/unit/ui/campaign/test_resource_panel.gd
test_resource_panel > test_panel_initialization                                     PASSED 33ms
test_resource_panel > test_resource_display                                         PASSED 34ms
test_resource_panel > test_resource_groups                                          PASSED 35ms
test_resource_panel > test_resource_states                                          PASSED 34ms
test_resource_panel > test_resource_layout                                          PASSED 35ms
test_resource_panel > test_resource_filters                                         PASSED 28ms
test_resource_panel > test_resource_sorting                                         PASSED 34ms
test_resource_panel > test_resource_selection                                       PASSED 33ms
test_resource_panel > test_resource_validation                                      PASSED 34ms
test_resource_panel > test_ui_state                                                 PASSED 34ms
test_resource_panel > test_theme_handling                                           PASSED 27ms
Statistics: 11 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 559ms

Run Test Suite: res://tests/unit/ui/components/campaign/test_action_button.gd
test_action_button > test_initial_state                                             PASSED 22ms
test_action_button > test_button_click                                              PASSED 34ms
test_action_button > test_disabled_state                                            PASSED 34ms
test_action_button > test_button_text                                               PASSED 35ms
test_action_button > test_button_icon                                               PASSED 35ms
test_action_button > test_button_style                                              PASSED 34ms
test_action_button > test_button_size_configuration                                 PASSED 34ms
test_action_button > test_button_tooltip                                            PASSED 35ms
test_action_button > test_component_structure                                       PASSED 35ms
test_action_button > test_component_theme                                           PASSED 34ms
test_action_button > test_component_accessibility                                   PASSED 34ms
Statistics: 11 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 559ms

Run Test Suite: res://tests/unit/ui/components/character/test_character_progression.gd
test_character_progression > test_initial_state                                     PASSED 29ms
test_character_progression > test_progression_update                                PASSED 34ms
test_character_progression > test_visibility                                        PASSED 34ms
test_character_progression > test_child_nodes                                       PASSED 34ms
test_character_progression > test_signals                                           PASSED 35ms
test_character_progression > test_state_updates                                     PASSED 33ms
test_character_progression > test_child_management                                  PASSED 35ms
test_character_progression > test_panel_initialization                              PASSED 34ms
test_character_progression > test_panel_nodes                                       PASSED 34ms
test_character_progression > test_experience_gain                                   PASSED 35ms
test_character_progression > test_stat_updates                                      PASSED 35ms
Statistics: 11 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 562ms

Run Test Suite: res://tests/unit/ui/components/combat/test_validation_panel.gd
test_validation_panel > test_initial_state                                          PASSED 27ms
test_validation_panel > test_validation_complete                                    PASSED 34ms
test_validation_panel > test_visibility                                             PASSED 34ms
test_validation_panel > test_child_nodes                                            PASSED 27ms
test_validation_panel > test_signals                                                PASSED 35ms
test_validation_panel > test_state_updates                                          PASSED 34ms
test_validation_panel > test_child_management                                       PASSED 35ms
test_validation_panel > test_panel_initialization                                   PASSED 34ms
test_validation_panel > test_panel_nodes                                            PASSED 35ms
test_validation_panel > test_panel_properties                                       PASSED 34ms
test_validation_panel > test_validation_message                                     PASSED 49ms
test_validation_panel > test_validation_state                                       PASSED 33ms
Statistics: 12 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 631ms

Run Test Suite: res://tests/unit/ui/controllers/test_battle_phase_controller.gd
test_battle_phase_controller > test_initial_state                                   PASSED 19ms
test_battle_phase_controller > test_initialize_phase                                PASSED 21ms
test_battle_phase_controller > test_handle_setup_state                              PASSED 20ms
test_battle_phase_controller > test_handle_deployment_phase                         PASSED 21ms
test_battle_phase_controller > test_handle_battle_phase                             PASSED 21ms
test_battle_phase_controller > test_handle_resolution_phase                         PASSED 21ms
test_battle_phase_controller > test_handle_cleanup_phase                            PASSED 20ms
test_battle_phase_controller > test_controller_state                                PASSED 20ms
test_battle_phase_controller > test_controller_signals                              PASSED 20ms
test_battle_phase_controller > test_phase_transitions                               PASSED 68ms
test_battle_phase_controller > test_controller_performance                          PASSED 21ms
Statistics: 11 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 435ms

Run Test Suite: res://tests/unit/ui/controllers/test_combat_state_controller.gd
test_combat_state_controller > test_initialization                                  PASSED 27ms
test_combat_state_controller > test_verification_rules                              PASSED 35ms
test_combat_state_controller > test_add_verification_rule                           PASSED 33ms
test_combat_state_controller > test_remove_verification_rule                        PASSED 33ms
test_combat_state_controller > test_verification_request                            PASSED 28ms
test_combat_state_controller > test_auto_verify_toggle                              PASSED 35ms
test_combat_state_controller > test_controller_initialization                       PASSED 34ms
test_combat_state_controller > test_controller_state                                PASSED 35ms
test_combat_state_controller > test_controller_signals                              PASSED 33ms
Statistics: 9 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 448ms

Run Test Suite: res://tests/unit/ui/controllers/test_house_rules_controller.gd
test_house_rules_controller > test_initial_state                                    PASSED 15ms
test_house_rules_controller > test_add_rule                                         PASSED 21ms
test_house_rules_controller > test_modify_rule                                      PASSED 35ms
test_house_rules_controller > test_remove_rule                                      PASSED 20ms
test_house_rules_controller > test_apply_rule                                       PASSED 20ms
test_house_rules_controller > test_validate_rule                                    PASSED 20ms
Statistics: 6 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 225ms

Run Test Suite: res://tests/unit/ui/controllers/test_override_ui_controller.gd
test_override_ui_controller > test_initial_state                                    PASSED 30ms
test_override_ui_controller > test_request_override                                 PASSED 26ms
test_override_ui_controller > test_apply_override                                   PASSED 34ms
test_override_ui_controller > test_cancel_override                                  PASSED 34ms
test_override_ui_controller > test_validate_override                                PASSED 43ms
test_override_ui_controller > test_combat_system_setup                              PASSED 34ms
test_override_ui_controller > test_controller_signals                               PASSED 35ms
test_override_ui_controller > test_controller_state                                 PASSED 34ms
test_override_ui_controller > test_override_sequence                                PASSED 28ms
test_override_ui_controller > test_controller_performance                           PASSED 34ms
test_override_ui_controller > test_invalid_overrides                                PASSED 35ms
test_override_ui_controller > test_combat_system_cleanup                            PASSED 34ms
Statistics: 12 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 616ms

Run Test Suite: res://tests/unit/ui/controllers/test_state_verification_controller.gd
test_state_verification_controller > test_initial_setup                             PASSED 27ms
test_state_verification_controller > test_basic_verification                        PASSED 47ms
test_state_verification_controller > test_state_validation                          PASSED 35ms
test_state_verification_controller > test_error_detection                           PASSED 35ms
test_state_verification_controller > test_state_repair                              PASSED 48ms
test_state_verification_controller > test_verification_modes                        PASSED 34ms
test_state_verification_controller > test_consistency_checks                        PASSED 34ms
test_state_verification_controller > test_performance_monitoring                    PASSED 49ms
test_state_verification_controller > test_error_handling                            PASSED 34ms
test_state_verification_controller > test_logging_functionality                     PASSED 42ms
Statistics: 10 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 563ms

Run Test Suite: res://tests/unit/ui/dialogs/test_difficulty_option.gd
test_difficulty_option > test_initial_setup                                         PASSED 21ms
test_difficulty_option > test_setup_with_difficulty                                 PASSED 35ms
test_difficulty_option > test_difficulty_options                                    PASSED 34ms
test_difficulty_option > test_get_set_difficulty                                    PASSED 35ms
test_difficulty_option > test_difficulty_change_signal                              PASSED 33ms
test_difficulty_option > test_component_theme                                       PASSED 34ms
test_difficulty_option > test_component_layout                                      PASSED 34ms
test_difficulty_option > test_component_performance                                 PASSED 34ms
test_difficulty_option > test_difficulty_interaction                                PASSED 35ms
test_difficulty_option > test_accessibility                                         PASSED 33ms
Statistics: 10 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 503ms

Run Test Suite: res://tests/unit/ui/dialogs/test_quick_start_dialog.gd
Statistics: 0 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 0ms

Run Test Suite: res://tests/unit/ui/dialogs/test_settings_dialog.gd
Statistics: 0 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 0ms

Run Test Suite: res://tests/unit/ui/overlays/test_grid_overlay.gd
Statistics: 0 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 1ms

Run Test Suite: res://tests/unit/ui/overlays/test_terrain_overlay.gd
test_terrain_overlay > test_initial_setup                                           PASSED 28ms
test_terrain_overlay > test_terrain_update                                          PASSED 33ms
test_terrain_overlay > test_highlight_cell                                          PASSED 35ms
test_terrain_overlay > test_clear_highlight                                         PASSED 34ms
test_terrain_overlay > test_terrain_interaction                                     PASSED 26ms
test_terrain_overlay > test_terrain_effects                                         PASSED 28ms
test_terrain_overlay > test_grid_drawing                                            PASSED 34ms
test_terrain_overlay > test_performance                                             PASSED 34ms
Statistics: 8 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 411ms

Run Test Suite: res://tests/unit/ui/overlays/test_terrain_tooltip.gd
Statistics: 0 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 0ms

Run Test Suite: res://tests/unit/ui/panels/test_combat_log_panel.gd
test_combat_log_panel > test_initial_setup                                          PASSED 21ms
test_combat_log_panel > test_filter_options_setup                                   PASSED 34ms
test_combat_log_panel > test_log_entry_addition                                     PASSED 35ms
test_combat_log_panel > test_max_entries_limit                                      PASSED 34ms
test_combat_log_panel > test_clear_functionality                                    PASSED 34ms
test_combat_log_panel > test_filter_functionality                                   PASSED 35ms
test_combat_log_panel > test_auto_scroll_functionality                              PASSED 49ms
test_combat_log_panel > test_panel_structure                                        PASSED 34ms
test_combat_log_panel > test_panel_theme                                            PASSED 34ms
test_combat_log_panel > test_panel_accessibility                                    PASSED 27ms
Statistics: 10 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 520ms

Run Test Suite: res://tests/unit/ui/panels/test_house_rules_panel.gd
test_house_rules_panel > test_panel_initialization                                  PASSED 29ms
test_house_rules_panel > test_panel_structure                                       PASSED 34ms
test_house_rules_panel > test_rules_list_functionality                              PASSED 27ms
test_house_rules_panel > test_rule_addition                                         PASSED 34ms
test_house_rules_panel > test_rule_modification                                     PASSED 33ms
test_house_rules_panel > test_rule_removal                                          PASSED 34ms
test_house_rules_panel > test_active_rules_management                               PASSED 34ms
test_house_rules_panel > test_rule_validation                                       PASSED 34ms
test_house_rules_panel > test_rule_application                                      PASSED 34ms
test_house_rules_panel > test_rule_templates                                        PASSED 34ms
test_house_rules_panel > test_ui_interactions                                       PASSED 34ms
test_house_rules_panel > test_error_handling                                        PASSED 34ms
Statistics: 12 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 618ms

Run Test Suite: res://tests/unit/ui/panels/test_manual_override_panel.gd
test_manual_override_panel > test_panel_initialization                              PASSED 214ms
test_manual_override_panel > test_panel_structure                                   PASSED 133ms
test_manual_override_panel > test_initial_properties                                PASSED 140ms
test_manual_override_panel > test_show_override_functionality                       PASSED 126ms
test_manual_override_panel > test_context_label_conversion                          PASSED 126ms
test_manual_override_panel > test_current_value_display                             FAILED 126ms
Report:
line <n/a>: Expecting emit signal: 'log_entry_added()' but timed out after 2s 0ms

test_manual_override_panel > test_spinbox_configuration                             FAILED 125ms
Report:
line <n/a>: Expecting emit signal: 'filter_changed()' but timed out after 2s 0ms
Report:
line <n/a>: Property 'value' should equal expected value
Report:
line <n/a>: Property 'min_value' should equal expected value
Report:
line <n/a>: Property 'max_value' should equal expected value
Report:
line <n/a>: Expecting emit signal: 'auto_scroll_toggled()' but timed out after 2s 0ms

test_manual_override_panel > test_apply_button_functionality                        PASSED 119ms
test_manual_override_panel > test_cancel_button_functionality                       PASSED 126ms
test_manual_override_panel > test_value_change_behavior                             PASSED 149ms
test_manual_override_panel > test_multiple_contexts                                 PASSED 189ms
test_manual_override_panel > test_edge_case_values                                  PASSED 119ms
test_manual_override_panel > test_ui_state_consistency                              PASSED 126ms
test_manual_override_panel > test_signal_emission_with_correct_values               PASSED 146ms
ui_test > test_responsive_layout                                                    SKIPPED 0ms
Report:
line 83: This test is skipped!
  Reason: 'Unknown test case argument's ["control"] found.'

ui_test > test_accessibility                                                        SKIPPED 0ms
Report:
line 123: This test is skipped!
  Reason: 'Unknown test case argument's ["control"] found.'

ui_test > test_animations                                                           SKIPPED 0ms
Report:
line 142: This test is skipped!
  Reason: 'Unknown test case argument's ["control"] found.'

Statistics: 17 tests cases | 0 errors | 2 failures | 0 flaky | 3 skipped | 0 orphans | FAILED 2s 626ms

Run Test Suite: res://tests/unit/ui/panels/test_mission_info_panel.gd
test_mission_info_panel > test_setup_with_mission_data                              PASSED 30ms
test_mission_info_panel > test_get_difficulty_text                                  PASSED 33ms
test_mission_info_panel > test_format_rewards                                       PASSED 35ms
test_mission_info_panel > test_accept_button_signal                                 PASSED 27ms
test_mission_info_panel > test_panel_accessibility                                  PASSED 34ms
test_mission_info_panel > test_panel_theme                                          PASSED 34ms
test_mission_info_panel > test_panel_layout                                         PASSED 35ms
Statistics: 7 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 355ms

Run Test Suite: res://tests/unit/ui/panels/test_mission_summary_panel.gd
test_mission_summary_panel > test_initial_setup                                     PASSED 21ms
test_mission_summary_panel > test_setup_with_mission_data                           PASSED 35ms
test_mission_summary_panel > test_get_outcome_text                                  PASSED 28ms
test_mission_summary_panel > test_get_victory_type_text                             PASSED 34ms
test_mission_summary_panel > test_update_stats                                      PASSED 35ms
test_mission_summary_panel > test_update_rewards                                    PASSED 35ms
test_mission_summary_panel > test_continue_button                                   PASSED 26ms
Statistics: 7 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 354ms

Run Test Suite: res://tests/unit/ui/panels/test_state_verification_panel.gd
test_state_verification_panel > test_panel_initialization                           PASSED 28ms
test_state_verification_panel > test_panel_structure                                PASSED 35ms
test_state_verification_panel > test_state_properties                               PASSED 35ms
test_state_verification_panel > test_state_categories                               PASSED 34ms
test_state_verification_panel > test_state_updates                                  PASSED 35ms
test_state_verification_panel > test_expected_state_updates                         PASSED 28ms
test_state_verification_panel > test_state_verification                             PASSED 34ms
test_state_verification_panel > test_state_mismatch_detection                       PASSED 34ms
test_state_verification_panel > test_auto_verify_functionality                      PASSED 34ms
test_state_verification_panel > test_verify_button_interaction                      PASSED 34ms
test_state_verification_panel > test_auto_verify_checkbox                           PASSED 48ms
test_state_verification_panel > test_manual_correction_request                      FAILED 34ms
Report:
line <n/a>: Expecting emit signal: 'override_applied()' but timed out after 2s 0ms

test_state_verification_panel > test_state_tree_display                             PASSED 35ms
test_state_verification_panel > test_export_verification_results                    PASSED 27ms
test_state_verification_panel > test_error_handling                                 PASSED 35ms
Statistics: 15 tests cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans | FAILED 774ms

Run Test Suite: res://tests/unit/ui/panels/test_terrain_action_panel.gd
test_terrain_action_panel > test_initial_setup                                      PASSED 21ms
test_terrain_action_panel > test_terrain_move                                       PASSED 26ms
test_terrain_action_panel > test_terrain_use                                        PASSED 21ms
test_terrain_action_panel > test_terrain_interact                                   PASSED 34ms
test_terrain_action_panel > test_action_availability                                PASSED 20ms
test_terrain_action_panel > test_panel_update                                       PASSED 35ms
test_terrain_action_panel > test_panel_performance                                  PASSED 21ms
Statistics: 7 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 278ms

Run Test Suite: res://tests/unit/ui/resource/test_resource_display.gd
test_resource_display > test_initial_setup                                          PASSED 15ms
test_resource_display > test_resource_addition                                      PASSED 35ms
test_resource_display > test_resource_update                                        PASSED 14ms
test_resource_display > test_resource_removal                                       PASSED 35ms
test_resource_display > test_multiple_resources                                     PASSED 14ms
test_resource_display > test_resource_layout                                        PASSED 14ms
test_resource_display > test_invalid_resource_type                                  PASSED 14ms
test_resource_display > test_negative_values                                        PASSED 34ms
test_resource_display > test_resource_clear                                         PASSED 20ms
Statistics: 9 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 360ms

Run Test Suite: res://tests/unit/ui/screens/character/test_character_sheet.gd
test_character_sheet > test_initial_setup                                           PASSED 27ms
test_character_sheet > test_character_data_loading                                  FAILED 34ms
Report:
line <n/a>: Expecting emit signal: 'setup_completed()' but timed out after 2s 0ms

test_character_sheet > test_character_data_saving                                   PASSED 34ms
test_character_sheet > test_character_deletion                                      PASSED 34ms
test_character_sheet > test_validation                                              FAILED 34ms
Report:
line <n/a>: Expecting emit signal: 'stats_updated()' but timed out after 2s 0ms

test_character_sheet > test_stat_limits                                             FAILED 34ms
Report:
line <n/a>: Expecting emit signal: 'rewards_updated()' but timed out after 2s 0ms

test_character_sheet > test_equipment_management                                    PASSED 27ms
test_character_sheet > test_class_specific_stats                                    PASSED 35ms
test_character_sheet > test_character_reset                                         PASSED 34ms
test_character_sheet > test_ui_updates                                              PASSED 28ms
Statistics: 10 tests cases | 0 errors | 3 failures | 0 flaky | 0 skipped | 0 orphans | FAILED 513ms

Run Test Suite: res://tests/unit/ui/screens/combat/test_combat_log_controller.gd
test_combat_log_controller > test_initial_state                                     PASSED 22ms
test_combat_log_controller > test_add_log_entry                                     PASSED 34ms
test_combat_log_controller > test_multiple_entry_types                              PASSED 34ms
test_combat_log_controller > test_filter_change                                     PASSED 35ms
test_combat_log_controller > test_filtered_entries                                  PASSED 34ms
test_combat_log_controller > test_clear_log                                         PASSED 34ms
test_combat_log_controller > test_entry_validation                                  FAILED 34ms
Report:
line <n/a>: Expecting emit signal: 'button_clicked()' but timed out after 2s 0ms

test_combat_log_controller > test_filter_persistence                                FAILED 27ms
Report:
line <n/a>: Expecting emit signal: 'toggled([true])' but timed out after 2s 0ms

test_combat_log_controller > test_display_update                                    PASSED 34ms
Statistics: 9 tests cases | 0 errors | 2 failures | 0 flaky | 0 skipped | 0 orphans | FAILED 458ms

Run Test Suite: res://tests/unit/ui/base/component_test_base.gd
component_test_base > test_component_structure                                      PASSED 20ms
component_test_base > test_component_theme                                          PASSED 14ms
component_test_base > test_component_focus                                          PASSED 14ms
component_test_base > test_component_visibility                                     PASSED 14ms
component_test_base > test_component_size                                           PASSED 14ms
component_test_base > test_component_layout                                         PASSED 18ms
component_test_base > test_component_animations                                     PASSED 13ms
component_test_base > test_component_accessibility                                  PASSED 14ms
component_test_base > test_component_performance                                    PASSED 14ms
Statistics: 9 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 318ms

Run Test Suite: res://tests/unit/ui/base/controller_test_base.gd
Statistics: 0 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 0ms

Run Test Suite: res://tests/unit/ui/base/panel_test_base.gd
Statistics: 0 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 1ms

Run Test Suite: res://tests/unit/ui/base/test_campaign_responsive_layout.gd
test_campaign_responsive_layout > test_initial_setup                                PASSED 28ms
test_campaign_responsive_layout > test_screen_size_detection                        PASSED 21ms
test_campaign_responsive_layout > test_responsive_scaling                           PASSED 21ms
test_campaign_responsive_layout > test_margin_adjustments                           FAILED 21ms
Report:
line <n/a>: Expecting emit signal: 'resource_updated()' but timed out after 2s 0ms
Report:
line <n/a>: Expecting emit signal: 'resource_added()' but timed out after 2s 0ms
Report:
line <n/a>: Expecting emit signal: 'resource_updated()' but timed out after 2s 0ms
Report:
line <n/a>: Expecting emit signal: 'resource_added()' but timed out after 2s 0ms
Report:
line <n/a>: Expecting emit signal: 'resource_updated()' but timed out after 2s 0ms
Report:
line <n/a>: Expecting emit signal: 'resource_added()' but timed out after 2s 0ms
Report:
line <n/a>: Expecting emit signal: 'resource_updated()' but timed out after 2s 0ms
Report:
line <n/a>: Expecting emit signal: 'resource_added()' but timed out after 2s 0ms

test_campaign_responsive_layout > test_layout_adaptation                            PASSED 20ms
test_campaign_responsive_layout > test_performance_constraints                      PASSED 21ms
test_campaign_responsive_layout > test_breakpoint_thresholds                        PASSED 15ms
test_campaign_responsive_layout > test_layout_persistence                           PASSED 21ms
test_campaign_responsive_layout > test_error_handling                               PASSED 20ms
Statistics: 9 tests cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans | FAILED 326ms

Run Test Suite: res://tests/unit/ui/base/ui_test_base.gd
Statistics: 0 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 0ms

Run Test Suite: res://tests/unit/ui/test_base_container.gd
test_base_container > test_horizontal_layout                                        FAILED 29ms
Report:
line <n/a>: Expecting emit signal: 'resource_updated()' but timed out after 2s 0ms

test_base_container > test_vertical_layout                                          PASSED 35ms
test_base_container > test_spacing_property                                         PASSED 34ms
test_base_container > test_orientation_property                                     PASSED 34ms
test_base_container > test_minimum_size                                             PASSED 35ms
test_base_container > test_component_structure                                      PASSED 34ms
Statistics: 6 tests cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans | FAILED 291ms

Run Test Suite: res://tests/unit/ui/test_logbook.gd
Statistics: 0 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 0ms

Run Test Suite: res://tests/unit/ui/test_responsive_container.gd
test_responsive_container > test_initial_setup                                      PASSED 28ms
test_responsive_container > test_landscape_mode                                     PASSED 27ms
test_responsive_container > test_portrait_mode_by_ratio                             PASSED 19ms
test_responsive_container > test_portrait_mode_by_min_width                         PASSED 34ms
test_responsive_container > test_orientation_change                                 PASSED 35ms
test_responsive_container > test_custom_threshold                                   PASSED 35ms
test_responsive_container > test_custom_min_width                                   PASSED 34ms
test_responsive_container > test_component_theme                                    PASSED 34ms
test_responsive_container > test_component_layout                                   FAILED 45ms
Report:
line <n/a>: Expecting emit signal: 'log_updated()' but timed out after 2s 0ms
Report:
line 125: Godot Runtime Error !
	'at: test_component_layout (res://tests/unit/ui/test_responsive_container.gd:125)'
Error: 'Invalid call. Nonexistent function 'get_viewport_size' in base 'Resource (MockResponsiveContainer)'.'

test_responsive_container > test_component_performance                              PASSED 27ms
test_responsive_container > test_container_interaction                              FAILED 41ms
Report:
line <n/a>: Expecting emit signal: 'filter_changed()' but timed out after 2s 0ms
Report:
line 140: Godot Runtime Error !
	'at: test_container_interaction (res://tests/unit/ui/test_responsive_container.gd:140)'
Error: 'Invalid assignment of property or key 'threshold_width' with value of type 'int' on a base object of type 'Resource (MockResponsiveContainer)'.'

test_responsive_container > test_accessibility                                      PASSED 35ms
test_responsive_container > test_theme_manager_integration                          FAILED 34ms
Report:
line <n/a>: Expecting emit signal: 'log_updated()' but timed out after 2s 0ms

test_responsive_container > test_ui_scale_response                                  PASSED 27ms
test_responsive_container > test_breakpoint_calculation_with_scale                  PASSED 34ms
test_responsive_container > test_adaptive_margins_with_scale                        PASSED 34ms
test_responsive_container > test_theme_property_inheritance                         PASSED 34ms
component_test_base > test_component_structure                                      PASSED 33ms
component_test_base > test_component_focus                                          PASSED 35ms
component_test_base > test_component_visibility                                     PASSED 34ms
component_test_base > test_component_size                                           PASSED 33ms
component_test_base > test_component_animations                                     PASSED 35ms
component_test_base > test_component_accessibility                                  PASSED 26ms
Statistics: 23 tests cases | 2 errors | 3 failures | 0 flaky | 0 skipped | 0 orphans | FAILED 1s 155ms

Run Test Suite: res://tests/unit/ui/test_rule_editor.gd
Statistics: 0 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 1ms

Run Test Suite: res://tests/unit/enemy/test_enemy.gd
test_enemy > test_enemy_initialization                                              PASSED 21ms
test_enemy > test_enemy_movement                                                    PASSED 20ms
test_enemy > test_enemy_combat                                                      PASSED 21ms
test_enemy > test_enemy_health_system                                               PASSED 21ms
test_enemy > test_enemy_death                                                       PASSED 13ms
test_enemy > test_enemy_turn_system                                                 PASSED 13ms
test_enemy > test_enemy_combat_rating                                               PASSED 13ms
test_enemy > test_enemy_error_handling                                              PASSED 21ms
test_enemy > test_enemy_mobile_performance                                          PASSED 20ms
test_enemy > test_enemy_touch_interaction                                           PASSED 14ms
test_enemy > test_enemy_state_changes                                               PASSED 13ms
test_enemy > test_enemy_signals                                                     PASSED 14ms
Statistics: 12 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 423ms

Run Test Suite: res://tests/unit/enemy/test_enemy_campaign_flow.gd
test_enemy_campaign_flow > test_enemy_persistence                                   PASSED 28ms
test_enemy_campaign_flow > test_enemy_progression                                   PASSED 19ms
test_enemy_campaign_flow > test_rival_integration                                   PASSED 20ms
test_enemy_campaign_flow > test_campaign_phase_effects                              PASSED 20ms
test_enemy_campaign_flow > test_enemy_faction_behavior                              PASSED 21ms
Statistics: 5 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 189ms

Run Test Suite: res://tests/unit/enemy/test_enemy_combat.gd
test_enemy_combat > test_enemy_combat_initialization                                PASSED 14ms
test_enemy_combat > test_enemy_basic_attack                                         PASSED 27ms
test_enemy_combat > test_enemy_attack_cooldown                                      PASSED 21ms
test_enemy_combat > test_enemy_attack_range                                         PASSED 34ms
test_enemy_combat > test_enemy_attack_angle                                         PASSED 28ms
test_enemy_combat > test_enemy_damage_dealing                                       PASSED 21ms
test_enemy_combat > test_enemy_target_selection                                     PASSED 20ms
test_enemy_combat > test_enemy_combat_performance                                   PASSED 20ms
Statistics: 8 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 298ms

Run Test Suite: res://tests/unit/enemy/test_enemy_data.gd
test_enemy_data > test_basic_initialization                                         PASSED 20ms
test_enemy_data > test_stats_configuration                                          PASSED 21ms
test_enemy_data > test_equipment_handling                                           PASSED 34ms
test_enemy_data > test_enemy_type_behaviors                                         PASSED 21ms
test_enemy_data > test_loot_tables                                                  PASSED 34ms
test_enemy_data > test_experience_rewards                                           PASSED 21ms
test_enemy_data > test_enemy_traits                                                 PASSED 20ms
Statistics: 7 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 279ms

Run Test Suite: res://tests/unit/enemy/test_enemy_deployment.gd
test_enemy_deployment > test_deployment_type_selection                              PASSED 15ms
test_enemy_deployment > test_standard_deployment                                    PASSED 34ms
test_enemy_deployment > test_line_deployment                                        PASSED 20ms
test_enemy_deployment > test_ambush_deployment                                      PASSED 19ms
test_enemy_deployment > test_scattered_deployment                                   PASSED 21ms
test_enemy_deployment > test_defensive_deployment                                   PASSED 21ms
test_enemy_deployment > test_infiltration_deployment                                PASSED 20ms
test_enemy_deployment > test_reinforcement_deployment                               PASSED 20ms
test_enemy_deployment > test_deployment_validation                                  PASSED 21ms
test_enemy_deployment > test_invalid_deployment_type                                PASSED 21ms
test_enemy_deployment > test_deployment_pattern_matching                            PASSED 34ms
Statistics: 11 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 417ms

Run Test Suite: res://tests/unit/enemy/test_enemy_group_behavior.gd
test_enemy_group_behavior > test_group_formation                                    PASSED 14ms
test_enemy_group_behavior > test_group_coordination                                 PASSED 36ms
test_enemy_group_behavior > test_leader_following                                   PASSED 34ms
test_enemy_group_behavior > test_group_combat_behavior                              PASSED 34ms
test_enemy_group_behavior > test_group_morale                                       PASSED 21ms
test_enemy_group_behavior > test_group_dispersion                                   PASSED 34ms
test_enemy_group_behavior > test_group_reformation                                  PASSED 21ms
Statistics: 7 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 308ms

Run Test Suite: res://tests/unit/enemy/test_enemy_group_tactics.gd
test_enemy_group_tactics > test_group_formation                                     PASSED 14ms
test_enemy_group_tactics > test_group_movement                                      PASSED 27ms
test_enemy_group_tactics > test_focus_fire                                          PASSED 20ms
test_enemy_group_tactics > test_flanking_behavior                                   PASSED 21ms
test_enemy_group_tactics > test_group_coordination                                  PASSED 35ms
test_enemy_group_tactics > test_group_state_tracking                                PASSED 20ms
Statistics: 6 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 230ms

Run Test Suite: res://tests/unit/enemy/test_enemy_pathfinding.gd
test_enemy_pathfinding > test_pathfinding_initialization                            PASSED 14ms
test_enemy_pathfinding > test_path_calculation                                      PASSED 28ms
test_enemy_pathfinding > test_path_following                                        PASSED 21ms
test_enemy_pathfinding > test_obstacle_avoidance                                    PASSED 21ms
test_enemy_pathfinding > test_path_recalculation                                    PASSED 35ms
test_enemy_pathfinding > test_movement_cost                                         PASSED 20ms
test_enemy_pathfinding > test_invalid_path                                          PASSED 35ms
test_enemy_pathfinding > test_path_cost                                             PASSED 20ms
test_enemy_pathfinding > test_path_validation                                       PASSED 20ms
test_enemy_pathfinding > test_path_simplification                                   PASSED 20ms
Statistics: 10 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 382ms

Run Test Suite: res://tests/unit/terrain/test_battlefield_generator_terrain.gd
test_battlefield_generator_terrain > test_terrain_generation                        PASSED 14ms
test_battlefield_generator_terrain > test_terrain_feature_distribution              PASSED 27ms
test_battlefield_generator_terrain > test_terrain_validation                        PASSED 34ms
test_battlefield_generator_terrain > test_environment_specific_generation           PASSED 21ms
test_battlefield_generator_terrain > test_terrain_connectivity                      PASSED 34ms
Statistics: 5 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 204ms

Run Test Suite: res://tests/unit/terrain/test_terrain_layout.gd
test_terrain_layout > test_layout_initialization                                    PASSED 14ms
test_terrain_layout > test_tile_placement                                           PASSED 21ms
test_terrain_layout > test_out_of_bounds_handling                                   PASSED 34ms
test_terrain_layout > test_walkability_queries                                      PASSED 20ms
test_terrain_layout > test_line_of_sight_queries                                    PASSED 20ms
test_terrain_layout > test_area_queries                                             PASSED 21ms
test_terrain_layout > test_serialization                                            PASSED 21ms
test_terrain_layout > test_layout_validation                                        PASSED 21ms
test_terrain_layout > test_flood_fill_operations                                    PASSED 20ms
Statistics: 9 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 325ms

Run Test Suite: res://tests/unit/terrain/test_terrain_system.gd
test_terrain_system > test_initialize_grid                                          PASSED 14ms
test_terrain_system > test_set_and_get_terrain_type                                 PASSED 21ms
test_terrain_system > test_invalid_position                                         PASSED 34ms
test_terrain_system > test_grid_size                                                PASSED 20ms
test_terrain_system > test_terrain_effect_application                               PASSED 35ms
test_terrain_system > test_multiple_effects                                         PASSED 20ms
Statistics: 6 tests cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 238ms

GdUnit Test Client disconnected with id: -9223208283441874645
Overall Summary: 639 tests cases | 2 errors | 15 failures | 0 flaky | 3 skipped | 0 orphans |
Executed test suites: (83/83)
Executed test cases : (639/639)
Total execution time: 30s 167ms
 