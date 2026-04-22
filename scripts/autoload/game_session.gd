## GameSession
##
## Holds per-session game state that isn't world-specific: which save slot is
## loaded, current scene transitions, autosave timer, in-game time, etc.
##
## Phase 0 placeholder.
extends Node

signal new_game_started(seed_value: int)

var current_save_slot: String = ""
var in_game_seconds: float = 0.0
## When non-empty, the next time Game._ready runs it will load this slot
## instead of generating a fresh world. Cleared after consumption.
var pending_load_slot: String = ""

## Per-player appearance options. Keys match CharacterBuilder.build() opts
## (skin, torso_color, torso_style, torso_row, hair_color, hair_style,
## hair_variant, face_color, face_variant). Empty dict = use scene defaults.
var p1_appearance: Dictionary = {}
var p2_appearance: Dictionary = {}


## Build a random appearance dict using the given RNG.
## Keys match CharacterBuilder.build() options.
static func randomize_appearance(rng: RandomNumberGenerator) -> Dictionary:
	var skin_tones: Array[StringName] = [&"light", &"tan", &"dark", &"goblin"]
	var torso_colors: Array[StringName] = [
		&"orange", &"teal", &"purple", &"green", &"tan", &"black",
	]
	var hair_colors: Array[StringName] = [
		&"brown", &"blonde", &"white", &"ginger", &"gray",
	]
	var hair_styles: Array[int] = [
		CharacterAtlas.HairStyle.SHORT,
		CharacterAtlas.HairStyle.LONG,
		CharacterAtlas.HairStyle.ACCESSORY,
	]
	var opts: Dictionary = {
		"skin": skin_tones[rng.randi() % skin_tones.size()],
		"torso_color": torso_colors[rng.randi() % torso_colors.size()],
		"torso_style": rng.randi() % 4,
		"torso_row": rng.randi() % 5,
		"hair_color": hair_colors[rng.randi() % hair_colors.size()],
		"hair_style": hair_styles[rng.randi() % hair_styles.size()],
		"hair_variant": rng.randi() % 4,
	}
	# 1-in-4 chance of facial hair.
	if (rng.randi() % 4) == 0:
		opts["face_color"] = hair_colors[rng.randi() % hair_colors.size()]
		opts["face_variant"] = rng.randi() % 4
	return opts


func get_appearance(player_id: int) -> Dictionary:
	return p1_appearance if player_id == 0 else p2_appearance


func set_appearance(player_id: int, opts: Dictionary) -> void:
	if player_id == 0:
		p1_appearance = opts
	else:
		p2_appearance = opts


func start_new_game(seed_value: int = 0) -> void:
	WorldManager.reset(seed_value)
	in_game_seconds = 0.0
	# Randomize player appearances from world seed.
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldManager.world_seed ^ 0xA11CE
	p1_appearance = randomize_appearance(rng)
	p2_appearance = randomize_appearance(rng)
	new_game_started.emit(WorldManager.world_seed)


func _process(delta: float) -> void:
	if not get_tree().paused:
		in_game_seconds += delta
