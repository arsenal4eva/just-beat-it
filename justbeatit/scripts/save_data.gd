extends RefCounted

class_name SaveData

const PATH := "user://justbeatit_save.cfg"
const SECTION := "stats"

static func _cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(PATH)
	return c

static func _save(c: ConfigFile) -> void:
	c.save(PATH)

static func _key(level_id: String, difficulty: String) -> String:
	return "best_%s_%s" % [level_id, difficulty]

static func record_result(level_id: String, difficulty: String, score: int) -> bool:
	var c := _cfg()
	var lifetime := int(c.get_value(SECTION, "lifetime_score", 0)) + score
	c.set_value(SECTION, "lifetime_score", lifetime)
	c.set_value(SECTION, "games_played", int(c.get_value(SECTION, "games_played", 0)) + 1)
	var k := _key(level_id, difficulty)
	var prev := int(c.get_value(SECTION, k, 0))
	var is_best := score > prev
	if is_best:
		c.set_value(SECTION, k, score)
	if score > int(c.get_value(SECTION, "best_score", 0)):
		c.set_value(SECTION, "best_score", score)
		c.set_value(SECTION, "best_score_label", "%s [%s]" % [level_id, difficulty])
	_save(c)
	return is_best

static func lifetime_score() -> int:
	return int(_cfg().get_value(SECTION, "lifetime_score", 0))

static func games_played() -> int:
	return int(_cfg().get_value(SECTION, "games_played", 0))

static func best_score() -> int:
	return int(_cfg().get_value(SECTION, "best_score", 0))

static func best_score_label() -> String:
	return str(_cfg().get_value(SECTION, "best_score_label", "-"))

static func best_for(level_id: String, difficulty: String) -> int:
	return int(_cfg().get_value(SECTION, _key(level_id, difficulty), 0))

static func best_maps(levels: Array) -> Array:
	var out: Array = []
	for lv in levels:
		for diff in (lv.get("difficulties", {}) as Dictionary).keys():
			var s := best_for(str(lv["id"]), str(diff))
			if s > 0:
				out.append({
					"label": "%s [%s]" % [lv.get("title", lv["id"]), diff],
					"score": s,
				})
	out.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	return out
