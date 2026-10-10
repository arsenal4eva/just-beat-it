extends TextureRect

class_name ArrowNote

var direction: String = "left"
var fall_speed: float = 400.0
var hit_y: float = 0.0
var was_hit: bool = false

func setup(p_direction: String, tex: Texture2D, start_pos: Vector2, p_hit_y: float, p_speed: float) -> void:
	direction = p_direction
	fall_speed = p_speed
	hit_y = p_hit_y
	texture = tex
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	size = Vector2(120, 120) if (direction == "left" or direction == "right") else Vector2(120, 120)
	position = start_pos - size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if was_hit:
		return
	position.y += fall_speed * delta

func offset() -> float:
	return (position.y + size.y * 0.5) - hit_y
