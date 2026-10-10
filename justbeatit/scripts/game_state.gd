extends RefCounted

class_name GameState

static var level_id: String = ""
static var level_title: String = ""
static var difficulty: String = "easy"
static var map_path: String = ""
static var muted: bool = false
static var volume: float = 1.0

static func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, muted)
	var v := clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus, -80.0 if v <= 0.001 else linear_to_db(v))

static func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	if volume > 0.001:
		muted = false
	apply_audio()

static func toggle_mute() -> bool:
	muted = not muted
	apply_audio()
	return muted
