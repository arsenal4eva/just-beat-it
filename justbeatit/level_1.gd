extends Node2D

const ArrowNoteScript := preload("res://scripts/note.gd")
const BeatmapScript := preload("res://scripts/beatmap.gd")
const GameState := preload("res://scripts/game_state.gd")
const SaveData := preload("res://scripts/save_data.gd")

@export var map_path: String = "res://maps/level_1_easy.json"
@export var end_delay: float = 2.0
@export var load_duration: float = 2.0

const WINDOWS := {"perfect": 15.0, "great": 32.0, "good": 55.0, "ok": 95.0}
const SCORES := {"perfect": 300, "great": 200, "good": 100, "early": 25, "late": 25, "miss": 0}
const DIR_TO_ACTION := {"left": "ui_left", "right": "ui_right", "up": "ui_up", "down": "ui_down"}

var _map: Dictionary = {}
var _fall_speed := 420.0
var _spawn_y := -100.0
var _song_time := 0.0
var _spawn_idx := 0
var _notes: Array = []
var _receptors := {}
var _hit_centers := {}
var _key_textures := {}
var _started := false
var _finished := false

var score := 0
var combo := 0
var max_combo := 0
var counts := {"perfect": 0, "great": 0, "good": 0, "early": 0, "late": 0, "miss": 0}

var _score_label: Label
var _rating_label: Label
var _combo_label: Label
var _info_label: Label
var _rating_tween: Tween
var _music: AudioStreamPlayer
var _music_delay := 0.0
var _use_music_clock := false
var _saved := false
var _back_btn: Button
var _mute_btn: Button
var _vol_slider: HSlider
var _loading := true
var _loading_overlay: ColorRect
var _loading_label: Label

func _ready() -> void:
	GameState.apply_audio()
	_cache_receptors()
	_load_textures()
	_build_hud()
	var chosen := GameState.map_path if GameState.map_path != "" else map_path
	_map = BeatmapScript.load_from_file(chosen)
	if _map.is_empty():
		_rating_label.text = "MAP ERROR - see console"
		return
	_fall_speed = float(_map.get("fall_speed", 420.0))
	_spawn_y = float(_map.get("spawn_y", -100.0))
	_music_delay = float(_map.get("music_delay", 0.0))
	_show_loading()
	_started = false
	await get_tree().create_timer(load_duration).timeout
	_finish_loading()
	_setup_music()
	_started = true

func _show_loading() -> void:
	_loading = true
	_loading_overlay = ColorRect.new()
	_loading_overlay.name = "LoadingOverlay"
	_loading_overlay.color = Color(0, 0, 0, 0.85)
	_loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_loading_overlay)
	_loading_overlay.move_to_front()
	_loading_label = Label.new()
	_loading_label.name = "LoadingLabel"
	_loading_label.text = "LOADING..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_label.add_theme_font_size_override("font_size", 64)
	add_child(_loading_label)
	_loading_label.move_to_front()
	var tw := create_tween().set_loops()
	tw.tween_property(_loading_label, "modulate:a", 0.3, 0.4)
	tw.tween_property(_loading_label, "modulate:a", 1.0, 0.4)

func _finish_loading() -> void:
	_loading = false
	if is_instance_valid(_loading_label):
		_loading_label.queue_free()
	if is_instance_valid(_loading_overlay):
		_loading_overlay.queue_free()

func _setup_music() -> void:
	var path := str(_map.get("music", ""))
	if path == "":
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("Level: could not load music '%s'" % path)
		return
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.stream = stream
	_music.volume_db = float(_map.get("music_volume_db", 0.0))
	add_child(_music)
	if _music_delay > 0.0:
		_song_time = -_music_delay
		var t := get_tree().create_timer(_music_delay)
		t.timeout.connect(_on_music_delay_done)
	else:
		_music.play()
		_use_music_clock = true

func _on_music_delay_done() -> void:
	if is_instance_valid(_music):
		_music.play()
		_use_music_clock = true

func _cache_receptors() -> void:
	for d in ["left", "up", "down", "right"]:
		var r: TextureRect = get_node_or_null(d) as TextureRect
		if r == null:
			for child in get_children():
				if child is TextureRect and str(child.name).to_lower() == d:
					r = child
					break
		if r:
			_receptors[d] = r
			_hit_centers[d] = r.position + r.size * 0.5

func _load_textures() -> void:
	for d in ["left", "up", "down", "right"]:
		_key_textures[d] = load("res://%skey.png" % d) as Texture2D

func _build_hud() -> void:
	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_score_label.position = Vector2(24, 16)
	_score_label.add_theme_font_size_override("font_size", 36)
	_score_label.text = "Score: 0"
	add_child(_score_label)
	_combo_label = Label.new()
	_combo_label.position = Vector2(24, 60)
	_combo_label.add_theme_font_size_override("font_size", 24)
	_combo_label.text = ""
	add_child(_combo_label)
	_rating_label = Label.new()
	_rating_label.position = Vector2(460, 300)
	_rating_label.add_theme_font_size_override("font_size", 48)
	add_child(_rating_label)
	_info_label = Label.new()
	_info_label.position = Vector2(24, 100)
	_info_label.add_theme_font_size_override("font_size", 20)
	_info_label.text = GameState.level_title + " [%s]" % GameState.difficulty if GameState.level_title != "" else ""
	add_child(_info_label)
	_back_btn = Button.new()
	_back_btn.text = "Menu"
	_back_btn.position = Vector2(1050, 16)
	_back_btn.pressed.connect(_to_menu)
	add_child(_back_btn)
	_mute_btn = Button.new()
	_mute_btn.position = Vector2(960, 16)
	_mute_btn.text = _mute_text()
	_mute_btn.pressed.connect(_on_mute_pressed)
	add_child(_mute_btn)
	_vol_slider = HSlider.new()
	_vol_slider.position = Vector2(880, 56)
	_vol_slider.custom_minimum_size = Vector2(220, 24)
	_vol_slider.min_value = 0.0
	_vol_slider.max_value = 100.0
	_vol_slider.step = 1.0
	_vol_slider.value = GameState.volume * 100.0
	_vol_slider.value_changed.connect(_on_volume_changed)
	add_child(_vol_slider)

func _process(delta: float) -> void:
	if _loading or not _started or _finished:
		return
	if _use_music_clock and is_instance_valid(_music) and _music.playing:
		_song_time = _music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	else:
		_song_time += delta
	_spawn_due_notes()
	_check_misses()
	_check_song_end()

func _spawn_due_notes() -> void:
	var notes: Array = _map["notes"]
	while _spawn_idx < notes.size():
		var n: Dictionary = notes[_spawn_idx]
		var hit_time := float(n["time"])
		var receptor_y: float = (_hit_centers[str(n["dir"]) ] as Vector2).y
		var travel := (receptor_y - _spawn_y) / _fall_speed
		if _song_time >= hit_time - travel:
			_spawn_note(str(n["dir"]))
			_spawn_idx += 1
		else:
			break

func _spawn_note(dir: String) -> void:
	var center: Vector2 = _hit_centers[dir]
	var note: TextureRect = ArrowNoteScript.new()
	add_child(note)
	note.setup(dir, _key_textures[dir], Vector2(center.x, _spawn_y), center.y, _fall_speed)
	move_child(note, get_children().size() - 4)
	_notes.append(note)

func _unhandled_input(event: InputEvent) -> void:
	if _loading or not _started or _finished:
		return
	if event.is_action_pressed("ui_left"):
		_judge("left")
	elif event.is_action_pressed("ui_right"):
		_judge("right")
	elif event.is_action_pressed("ui_up"):
		_judge("up")
	elif event.is_action_pressed("ui_down"):
		_judge("down")
	elif event.is_action_pressed("ui_cancel"):
		_to_menu()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_M:
				_on_mute_pressed()
			KEY_MINUS:
				GameState.set_volume(GameState.volume - 0.05)
				_vol_slider.set_value_no_signal(GameState.volume * 100.0)
				_mute_btn.text = _mute_text()
			KEY_EQUAL:
				GameState.set_volume(GameState.volume + 0.05)
				_vol_slider.set_value_no_signal(GameState.volume * 100.0)
				_mute_btn.text = _mute_text()

func _judge(dir: String) -> void:
	var best = null
	var best_abs := 999999.0
	for note in _notes:
		if not is_instance_valid(note) or note.direction != dir or note.was_hit:
			continue
		var a := absf(note.offset())
		if a < best_abs:
			best_abs = a
			best = note
	if best == null:
		_apply_result("miss", null)
		return
	var off: float = best.offset()
	var rating := _rating_for(off)
	_apply_result(rating, best)

func _rating_for(off: float) -> String:
	var a := absf(off)
	if a <= WINDOWS["perfect"]:
		return "perfect"
	if a <= WINDOWS["great"]:
		return "great"
	if a <= WINDOWS["good"]:
		return "good"
	if a <= WINDOWS["ok"]:
		return "early" if off < 0.0 else "late"
	return "miss"

func _apply_result(rating: String, note) -> void:
	counts[rating] = int(counts[rating]) + 1
	if rating == "miss":
		combo = 0
	else:
		combo += 1
		max_combo = maxi(max_combo, combo)
		score += int(SCORES[rating]) + combo * 2
	if note != null and is_instance_valid(note):
		note.was_hit = true
		_notes.erase(note)
		note.queue_free()
	_update_hud(rating)

func _check_misses() -> void:
	for note in _notes.duplicate():
		if not is_instance_valid(note):
			_notes.erase(note)
			continue
		if note.offset() > WINDOWS["ok"]:
			_apply_result("miss", note)

func _check_song_end() -> void:
	var notes: Array = _map["notes"]
	if _spawn_idx >= notes.size() and _notes.is_empty():
		if _song_time >= float(notes.back()["time"]) + end_delay:
			_finished = true
			_show_results()

func _update_hud(last_rating: String) -> void:
	_score_label.text = "Score: %d" % score
	_combo_label.text = "%d COMBO" % combo if combo >= 2 else ""
	if last_rating == "":
		return
	_rating_label.text = last_rating.to_upper()
	_rating_label.add_theme_color_override("font_color", _color_for(last_rating))
	if _rating_tween and _rating_tween.is_valid():
		_rating_tween.kill()
	_rating_label.scale = Vector2.ONE
	_rating_label.modulate.a = 1.0
	_rating_tween = create_tween()
	_rating_tween.tween_property(_rating_label, "scale", Vector2(1.15, 1.15), 0.08)
	_rating_tween.tween_property(_rating_label, "scale", Vector2.ONE, 0.12)

func _color_for(rating: String) -> Color:
	match rating:
		"perfect": return Color(1.0, 0.85, 0.2)
		"great": return Color(0.35, 1.0, 0.5)
		"good": return Color(0.35, 0.8, 1.0)
		"early": return Color(1.0, 0.55, 0.3)
		"late": return Color(0.5,0.5,0.5)
		_: return Color(1.0, 0.3, 0.35)

func _show_results() -> void:
	if is_instance_valid(_music) and _music.playing:
		_music.stop()
	if not _saved:
		_saved = true
		if GameState.level_id != "":
			var is_best: bool = SaveData.record_result(GameState.level_id, GameState.difficulty, score)
			_rating_label.text = "FINISH!\nScore %d  MaxCombo %d%s\nP:%d Gr:%d Go:%d E:%d L:%d M:%d\nLifetime: %d — press Menu" % [
				score, max_combo, "  NEW BEST!" if is_best else "",
				counts["perfect"], counts["great"],
				counts["good"], counts["early"], counts["late"], counts["miss"],
				SaveData.lifetime_score()]
			return
	_rating_label.text = "FINISH!\nScore %d  MaxCombo %d\nP:%d Gr:%d Go:%d E:%d L:%d M:%d" % [
		score, max_combo, counts["perfect"], counts["great"],
		counts["good"], counts["early"], counts["late"], counts["miss"]]

func _mute_text() -> String:
	return "Unmute" if GameState.muted else "Mute"

func _on_mute_pressed() -> void:
	GameState.toggle_mute()
	_mute_btn.text = _mute_text()
	_vol_slider.set_value_no_signal(GameState.volume * 100.0)

func _on_volume_changed(v: float) -> void:
	GameState.set_volume(v / 100.0)
	_mute_btn.text = _mute_text()

func _to_menu() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
