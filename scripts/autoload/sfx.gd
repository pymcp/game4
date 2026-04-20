## Sfx
##
## Small autoload that plays one-shot UI/world sound effects. Spawns a
## throw-away [AudioStreamPlayer] per call so overlapping plays don't cut
## each other off. Names map to a curated set of Kenney audio assets.
extends Node

const _CATALOG: Dictionary = {
	&"dungeon_enter": "res://assets/audio/interface/open_001.ogg",
	&"dungeon_exit": "res://assets/audio/interface/close_001.ogg",
	&"loot_pickup": "res://assets/audio/interface/pluck_001.ogg",
}

var _streams: Dictionary = {}  # StringName -> AudioStream
var _bus: StringName = &"Master"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Pre-load streams so the first play doesn't hitch.
	for key in _CATALOG.keys():
		var path: String = _CATALOG[key]
		if not ResourceLoader.exists(path):
			push_warning("[Sfx] missing stream: %s" % path)
			continue
		_streams[key] = load(path)


## Play `key` (must be a registered name in _CATALOG). Returns the
## [AudioStreamPlayer] node (already playing) or null if not found.
func play(key: StringName, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not _streams.has(key):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = _streams[key]
	p.bus = _bus
	p.volume_db = volume_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


func has_key(key: StringName) -> bool:
	return _streams.has(key)
