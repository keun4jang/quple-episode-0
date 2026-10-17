class_name IdleVfx
extends Node2D
## 부드럽게 빛나는 입자 (`particles-vfx` 스킬의 한 번 터지는 버스트 + 색 사라짐·크기 줄어듦 곡선).
## 그림 파일 없이 동그란 빛 무늬를 코드로 만들고, 더하기 섞기(ADD)로 겹칠수록 환해진다.
## 폰(gl_compatibility)에서도 확실히 돌도록 CPUParticles2D 를 쓴다 - 한 번에 수십 개뿐이라 충분하다.

static var _glow: Texture2D
static var _add_mat: CanvasItemMaterial


static func glow_tex() -> Texture2D:
	if _glow == null:
		var g := _grad([0.0, 0.35, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_glow = t
	return _glow


static func add_mat() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


## 점을 한 번에 넣는다. (add_point 뒤에 set_color(1, ..) 을 하면 번호가 밀려 가운데 점이 바뀐다 - 실제로 겪었다)
static func _grad(offs: Array, cols: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	return g


static func _ramp(col: Color, fade_in := false) -> Gradient:
	if fade_in:
		return _grad([0.0, 0.25, 1.0], [Color(col, 0.0), col, Color(col, 0.0)])
	return _grad([0.0, 0.3, 1.0], [Color(col.lightened(0.5), 1.0), col, Color(col, 0.0)])


static func _shrink() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	return c


## 한 번 터지는 빛 조각. up 이면 위로 떠오르고(중력 반대), 아니면 사방으로 튄다.
func burst(p: Vector2, col: Color, amount := 16, speed := 320.0, life := 0.6, size := 0.45,
		up := false, delay := 0.0) -> void:
	if delay > 0.0:
		create_tween().tween_callback(burst.bind(p, col, amount, speed, life, size, up, 0.0)).set_delay(delay)
		return
	var e := CPUParticles2D.new()
	e.position = p
	e.one_shot = true
	e.explosiveness = 0.95
	e.amount = maxi(1, amount)
	e.lifetime = life
	e.texture = glow_tex()
	e.material = add_mat()
	e.local_coords = false
	e.direction = Vector2(0, -1)
	e.spread = 50.0 if up else 180.0
	e.gravity = Vector2(0, -60.0) if up else Vector2(0, 520.0)
	e.initial_velocity_min = speed * 0.35
	e.initial_velocity_max = speed
	e.damping_min = 1.5
	e.damping_max = 4.0
	e.scale_amount_min = size * 0.5
	e.scale_amount_max = size
	e.scale_amount_curve = _shrink()
	e.color_ramp = _ramp(col)
	add_child(e)
	e.emitting = true
	create_tween().tween_callback(e.queue_free).set_delay(life + 0.3)


## 화면 가득 천천히 떠다니는 큰 빛망울 (보케). 구역이 바뀌면 색만 바꾼다.
static func make_bokeh(rect: Vector2) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.amount = 16
	e.lifetime = 9.0
	e.preprocess = 9.0
	e.texture = glow_tex()
	e.material = add_mat()
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = rect * 0.5
	e.position = rect * 0.5
	e.direction = Vector2(-1, -0.3)
	e.spread = 40.0
	e.gravity = Vector2.ZERO
	e.initial_velocity_min = 6.0
	e.initial_velocity_max = 22.0
	e.scale_amount_min = 0.6
	e.scale_amount_max = 2.2
	e.color_ramp = _ramp(Color(1, 1, 1, 0.3), true)
	e.emitting = true
	return e


static func tint_bokeh(e: CPUParticles2D, col: Color) -> void:
	e.color_ramp = _ramp(Color(col, 0.3), true)
