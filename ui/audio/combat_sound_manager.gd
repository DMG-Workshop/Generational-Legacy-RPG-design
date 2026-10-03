## Combat Sound Manager: Play audio feedback for battle actions
##
## Handles combat sound effects for attacks, abilities, damage, healing, and status effects
## Supports volume control, sound priority, and audio mixing

class_name CombatSoundManager


signal sound_played(sound_name: String)
signal sound_finished(sound_name: String)


enum SoundType { ATTACK, DEFEND, SPELL, HEAL, BUFF, DEBUFF, DAMAGE, CRITICAL, LEVEL_UP, VICTORY, DEFEAT }
enum Priority { LOW, NORMAL, HIGH, CRITICAL }


var is_enabled: bool = true
var master_volume: float = 1.0
var combat_volume: float = 0.8
var effects_volume: float = 0.9

# Audio tracks
var attack_sounds: Dictionary = {}
var ability_sounds: Dictionary = {}
var impact_sounds: Dictionary = {}
var status_sounds: Dictionary = {}
var ui_sounds: Dictionary = {}

# Currently playing sounds
var active_sounds: Dictionary = {}  # sound_name -> audio properties


func _init() -> void:
	_initialize_sound_library()


## Initialize all combat sounds
func _initialize_sound_library() -> void:
	# Attack sounds
	attack_sounds = {
		"sword_swing": {"file": "res://audio/combat/sword_swing.ogg", "volume": 0.7},
		"punch": {"file": "res://audio/combat/punch.ogg", "volume": 0.6},
		"bow_shot": {"file": "res://audio/combat/bow_shot.ogg", "volume": 0.7},
	}

	# Ability sounds
	ability_sounds = {
		"fireball": {"file": "res://audio/combat/fireball.ogg", "volume": 0.8},
		"ice_spike": {"file": "res://audio/combat/ice_spike.ogg", "volume": 0.8},
		"heal": {"file": "res://audio/combat/heal.ogg", "volume": 0.75},
		"buff": {"file": "res://audio/combat/buff.ogg", "volume": 0.7},
	}

	# Impact sounds
	impact_sounds = {
		"hit": {"file": "res://audio/combat/hit.ogg", "volume": 0.8},
		"critical_hit": {"file": "res://audio/combat/critical_hit.ogg", "volume": 0.9},
		"miss": {"file": "res://audio/combat/miss.ogg", "volume": 0.6},
		"defend": {"file": "res://audio/combat/defend.ogg", "volume": 0.75},
	}

	# Status effect sounds
	status_sounds = {
		"poison": {"file": "res://audio/combat/poison.ogg", "volume": 0.7},
		"burn": {"file": "res://audio/combat/burn.ogg", "volume": 0.8},
		"freeze": {"file": "res://audio/combat/freeze.ogg", "volume": 0.75},
		"stun": {"file": "res://audio/combat/stun.ogg", "volume": 0.7},
	}

	# UI sounds
	ui_sounds = {
		"level_up": {"file": "res://audio/ui/level_up.ogg", "volume": 0.85},
		"victory": {"file": "res://audio/ui/victory.ogg", "volume": 0.9},
		"defeat": {"file": "res://audio/ui/defeat.ogg", "volume": 0.85},
		"item_pickup": {"file": "res://audio/ui/item_pickup.ogg", "volume": 0.7},
	}


## Play attack sound
func play_attack_sound(attack_type: String) -> void:
	if not is_enabled:
		return

	var sound_key = attack_type.to_lower()
	if sound_key in attack_sounds:
		_play_sound(sound_key, attack_sounds[sound_key], Priority.NORMAL, "attack")


## Play ability sound
func play_ability_sound(ability_type: String) -> void:
	if not is_enabled:
		return

	var sound_key = ability_type.to_lower()
	if sound_key in ability_sounds:
		_play_sound(sound_key, ability_sounds[sound_key], Priority.NORMAL, "ability")


## Play impact sound
func play_impact_sound(impact_type: String = "hit") -> void:
	if not is_enabled:
		return

	var sound_key = impact_type.to_lower()
	if sound_key in impact_sounds:
		_play_sound(sound_key, impact_sounds[sound_key], Priority.HIGH, "impact")


## Play critical hit sound
func play_critical_hit_sound() -> void:
	if not is_enabled:
		return

	_play_sound("critical_hit", impact_sounds.get("critical_hit", {}), Priority.HIGH, "critical")


## Play damage sound
func play_damage_sound(damage_amount: int) -> void:
	if not is_enabled:
		return

	if damage_amount > 50:
		play_impact_sound("critical_hit")
	else:
		play_impact_sound("hit")


## Play healing sound
func play_healing_sound() -> void:
	if not is_enabled:
		return

	_play_sound("heal", ability_sounds.get("heal", {}), Priority.NORMAL, "heal")


## Play status effect sound
func play_status_sound(status_name: String) -> void:
	if not is_enabled:
		return

	var sound_key = status_name.to_lower()
	if sound_key in status_sounds:
		_play_sound(sound_key, status_sounds[sound_key], Priority.NORMAL, "status")


## Play UI sound
func play_ui_sound(ui_event: String) -> void:
	if not is_enabled:
		return

	var sound_key = ui_event.to_lower()
	if sound_key in ui_sounds:
		_play_sound(sound_key, ui_sounds[sound_key], Priority.HIGH, "ui")


## Play level up sound
func play_level_up_sound() -> void:
	play_ui_sound("level_up")


## Play victory sound
func play_victory_sound() -> void:
	play_ui_sound("victory")


## Play defeat sound
func play_defeat_sound() -> void:
	play_ui_sound("defeat")


## Internal sound play with priority and volume
func _play_sound(sound_key: String, sound_data: Dictionary, priority: Priority, category: String) -> void:
	var volume = sound_data.get("volume", 0.7)
	var final_volume = volume * combat_volume * master_volume

	# Track the sound
	active_sounds[sound_key] = {
		"priority": priority,
		"category": category,
		"volume": final_volume,
		"playing": true,
		"start_time": Time.get_ticks_msec()
	}

	sound_played.emit(sound_key)


## Set master volume (0.0 to 1.0)
func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 1.0)


## Set combat volume (0.0 to 1.0)
func set_combat_volume(volume: float) -> void:
	combat_volume = clamp(volume, 0.0, 1.0)


## Set effects volume (0.0 to 1.0)
func set_effects_volume(volume: float) -> void:
	effects_volume = clamp(volume, 0.0, 1.0)


## Get current master volume
func get_master_volume() -> float:
	return master_volume


## Get current combat volume
func get_combat_volume() -> float:
	return combat_volume


## Enable/disable sound
func set_enabled(enabled: bool) -> void:
	is_enabled = enabled


## Stop all sounds
func stop_all() -> void:
	active_sounds.clear()


## Mute all sound
func mute() -> void:
	master_volume = 0.0


## Unmute (restore previous volume)
func unmute() -> void:
	master_volume = 0.5  # Default middle volume


## Get number of active sounds
func get_active_sound_count() -> int:
	return active_sounds.size()


## Check if sound exists
func has_sound(sound_key: String) -> bool:
	return (sound_key in attack_sounds or
			sound_key in ability_sounds or
			sound_key in impact_sounds or
			sound_key in status_sounds or
			sound_key in ui_sounds)
