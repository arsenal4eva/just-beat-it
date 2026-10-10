extends RefCounted

class_name LevelRegistry

const PATH := "res://levels.json"
const DEFAULT_DIFFICULTY := "easy"

static func load_levels() -> Array:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("LevelRegistry: cannot open %s" % PATH)
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("levels"):
		push_error("LevelRegistry: %s must be {\"levels\": [...]}" % PATH)
		return []
	return parsed["levels"]

static func default_difficulty(level: Dictionary) -> String:
	var diffs: Dictionary = level.get("difficulties", {})
	if diffs.has(DEFAULT_DIFFICULTY):
		return DEFAULT_DIFFICULTY
	var keys := diffs.keys()
	return str(keys[0]) if not keys.is_empty() else DEFAULT_DIFFICULTY

static func map_for(level: Dictionary, difficulty: String) -> String:
	var diffs: Dictionary = level.get("difficulties", {})
	if diffs.has(difficulty):
		return str(diffs[difficulty])
	return str(diffs.get(default_difficulty(level), ""))
