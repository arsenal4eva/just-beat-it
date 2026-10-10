extends RefCounted

class_name Beatmap

const DIRS := ["left", "up", "down", "right"]

static func load_from_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Beatmap: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Beatmap: invalid JSON in %s" % path)
		return {}
	var map: Dictionary = parsed
	var err := validate(map)
	if err != "":
		push_error("Beatmap %s invalid: %s" % [path, err])
		return {}
	map["notes"].sort_custom(func(a, b): return a["time"] < b["time"])
	return map

static func validate(map: Dictionary) -> String:
	if not map.has("fall_speed") or float(map["fall_speed"]) <= 0.0:
		return "fall_speed must be > 0"
	if not map.has("notes") or not (map["notes"] is Array) or map["notes"].is_empty():
		return "notes must be a non-empty array"
	var seen := {}
	for n in map["notes"]:
		if not (n is Dictionary) or not n.has("time") or not n.has("dir"):
			return "each note needs {time, dir}"
		var d := str(n["dir"]).to_lower()
		if d not in DIRS:
			return "bad direction '%s', use left/up/down/right" % d
		n["dir"] = d
		if float(n["time"]) < 0.0:
			return "note time must be >= 0"
		seen[d] = true
	for d in DIRS:
		if not seen.has(d):
			return "map must contain left, up, down AND right at least once (missing %s)" % d
	if map.has("music") and str(map["music"]) != "":
		var mp := str(map["music"])
		if not (mp.ends_with(".mp3") or mp.ends_with(".ogg") or mp.ends_with(".wav")):
			return "music must be an .mp3/.ogg/.wav file path"
		if not ResourceLoader.exists(mp):
			return "music file not found: %s (put it in the project, e.g. res://music/song.mp3)" % mp
	if map.has("music_volume_db"):
		var v := float(map["music_volume_db"])
		if v < -60.0 or v > 6.0:
			return "music_volume_db should be between -60 and +6"
	if map.has("music_delay") and float(map["music_delay"]) < 0.0:
		return "music_delay must be >= 0"
	return ""
