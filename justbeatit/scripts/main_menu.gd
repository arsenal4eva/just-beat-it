extends Control

const LevelRegistry := preload("res://scripts/level_registry.gd")
const GameState := preload("res://scripts/game_state.gd")
const SaveData := preload("res://scripts/save_data.gd")

var _levels: Array = []
var _selected_level: int = 0
var _selected_diff: String = "easy"

var _title_box: VBoxContainer
var _select_box: VBoxContainer
var _level_buttons: Array = []
var _diff_buttons: Dictionary = {}
var _stats_label: Label
var _best_label: Label
var _info_label: Label

func _ready() -> void:
	GameState.apply_audio()
	_levels = LevelRegistry.load_levels()
	_build()
	_build_audio_bar()
	_show_title()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_title_box = _center_box()
	var title := Label.new()
	title.text = "JUST BEAT IT"
	title.add_theme_font_size_override("font_size", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(title)
	var start := Button.new()
	start.text = "START"
	start.add_theme_font_size_override("font_size", 32)
	start.pressed.connect(_show_select)
	_title_box.add_child(start)
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(_stats_label)
	_best_label = Label.new()
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(_best_label)

	_select_box = _center_box()
	var h := Label.new()
	h.text = "CHOOSE LEVEL  (default difficulty: easy)"
	h.add_theme_font_size_override("font_size", 28)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_select_box.add_child(h)
	for i in _levels.size():
		var lv: Dictionary = _levels[i]
		var b := Button.new()
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_pick_level.bind(i))
		_select_box.add_child(b)
		_level_buttons.append(b)
	var dh := Label.new()
	dh.text = "DIFFICULTY"
	dh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_select_box.add_child(dh)
	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_select_box.add_child(diff_row)
	for d in ["easy", "normal", "hard"]:
		var db := Button.new()
		db.text = d.capitalize()
		db.toggle_mode = true
		db.pressed.connect(_pick_diff.bind(d))
		diff_row.add_child(db)
		_diff_buttons[d] = db
	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_select_box.add_child(_info_label)
	var play := Button.new()
	play.text = "PLAY"
	play.add_theme_font_size_override("font_size", 32)
	play.pressed.connect(_play)
	_select_box.add_child(play)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_show_title)
	_select_box.add_child(back)

func _build_audio_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "AudioBar"
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 12)
	_title_box.add_child(bar)
	var vol := HSlider.new()
	var mute := Button.new()
	mute.name = "MuteBtn"
	mute.text = "Unmute" if GameState.muted else "Mute"
	mute.pressed.connect(func() -> void:
		GameState.toggle_mute()
		mute.text = "Unmute" if GameState.muted else "Mute"
		vol.set_value_no_signal(GameState.volume * 100.0)
	)
	bar.add_child(mute)
	vol.custom_minimum_size = Vector2(220, 24)
	vol.min_value = 0.0
	vol.max_value = 100.0
	vol.step = 1.0
	vol.value = GameState.volume * 100.0
	vol.value_changed.connect(func(v: float) -> void:
		GameState.set_volume(v / 100.0)
		mute.text = "Unmute" if GameState.muted else "Mute"
	)
	bar.add_child(vol)
	var hint := Label.new()
	hint.text = "M: mute  -/+: volume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(hint)

func _center_box() -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	c.add_child(v)
	return v

func _show_title() -> void:
	_title_box.get_parent().visible = true
	_select_box.get_parent().visible = false
	_stats_label.text = "Lifetime score: %d   |   Games played: %d" % [SaveData.lifetime_score(), SaveData.games_played()]
	_best_label.text = "Best score: %d (%s)\n\nTOP MAPS:\n%s" % [
		SaveData.best_score(), SaveData.best_score_label(), _best_maps_text()]

func _best_maps_text() -> String:
	var rows := SaveData.best_maps(_levels)
	if rows.is_empty():
		return "no plays yet — go set a record!"
	var lines: Array = []
	for i in mini(rows.size(), 5):
		lines.append("%d. %s — %d" % [i + 1, rows[i]["label"], int(rows[i]["score"])])
	return "\n".join(lines)

func _show_select() -> void:
	_title_box.get_parent().visible = false
	_select_box.get_parent().visible = true
	if _levels.is_empty():
		_info_label.text = "No levels found (see levels.json)"
		return
	_selected_level = clampi(_selected_level, 0, _levels.size() - 1)
	_selected_diff = LevelRegistry.default_difficulty(_levels[_selected_level])
	_refresh_select()

func _pick_level(i: int) -> void:
	_selected_level = i
	_selected_diff = LevelRegistry.default_difficulty(_levels[i])
	_refresh_select()

func _pick_diff(d: String) -> void:
	_selected_diff = d
	_refresh_select()

func _refresh_select() -> void:
	var lv: Dictionary = _levels[_selected_level]
	var diffs: Dictionary = lv.get("difficulties", {})
	for i in _level_buttons.size():
		var l2: Dictionary = _levels[i]
		var best := SaveData.best_for(str(l2["id"]), LevelRegistry.default_difficulty(l2))
		_level_buttons[i].text = "%s   (best: %d)%s" % [
			l2.get("title", l2["id"]), best, "  <<<<" if i == _selected_level else ""]
	for d in _diff_buttons.keys():
		var btn: Button = _diff_buttons[d]
		btn.button_pressed = (d == _selected_diff)
		btn.disabled = not diffs.has(d)
		var b2 := SaveData.best_for(str(lv["id"]), str(d))
		btn.text = "%s (%d)" % [str(d).capitalize(), b2]
	_info_label.text = "Playing: %s  [%s]" % [lv.get("title"), _selected_diff]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		GameState.toggle_mute()
		var b := _title_box.get_node_or_null("AudioBar/MuteBtn") as Button
		if b:
			b.text = "Unmute" if GameState.muted else "Mute"

func _play() -> void:
	if _levels.is_empty():
		return
	var lv: Dictionary = _levels[_selected_level]
	GameState.level_id = str(lv["id"])
	GameState.level_title = str(lv.get("title", lv["id"]))
	GameState.difficulty = _selected_diff
	GameState.map_path = LevelRegistry.map_for(lv, _selected_diff)
	get_tree().change_scene_to_file(str(lv.get("scene", "res://level_1.tscn")))
