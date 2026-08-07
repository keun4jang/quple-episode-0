extends Node3D
class_name PaperDoll
## 도안 그림을 그대로 3D 공간에 세운다.
##
## 그동안 쿼카는 코드가 구를 쌓아 만들었다. 도안을 재서 비율·색·소품을 맞춰
## 왔지만 "비슷하다" 에서 멈췄다 — 털의 부드러움, 모자 챙의 곡선, 카메라의
## 금속 질감 같은 것은 구를 몇 개 더 쌓는다고 나오지 않는다.
##
## 그래서 **그리지 않고 그림을 쓴다.** 삼면도를 잘라 카메라 쪽으로 세우고,
## 캐릭터가 향한 방향에 따라 정면·옆·뒤 그림을 갈아 끼운다. 옆모습은 좌우를
## 뒤집어 반대쪽으로도 쓴다.
##
## 이 방식의 한계는 분명하다 — 대각선에서 보면 그림이 살짝 미끄러지고,
## 팔다리를 따로 움직일 수 없다. 대신 화면에 나오는 것이 도안 **그 자체**다.
## 이 게임의 카메라는 대체로 뒤 위에서 내려다보고 캐릭터는 100px 남짓이라,
## 그 한계보다 "도안과 똑같다" 는 쪽이 훨씬 크게 남는다.

## 캐릭터 키(미터). 그림 높이를 여기에 맞춰 줄인다.
@export var height: float = 1.15
## 그림 파일 앞부분. `<prefix>-front.png` 식으로 셋을 찾는다.
@export var prefix: String = "res://assets/mascots/sheet/leader"
## 바닥 그림자를 깔지. 그림은 그림자를 못 드리우므로 대신 깔아 준다.
@export var blob_shadow: bool = true

var _sprite: Sprite3D
var _shadow: MeshInstance3D
var _front: Texture2D
var _side: Texture2D
var _back: Texture2D
var _t := 0.0
var _bob := 0.0


func _ready() -> void:
	_front = _load("front")
	_side = _load("side")
	_back = _load("back")
	if _front == null:
		push_warning("PaperDoll: %s-front.png 을 찾을 수 없다" % prefix)
		return

	_sprite = Sprite3D.new()
	_sprite.name = "Sheet"
	_sprite.texture = _front
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.shaded = false
	_sprite.double_sided = true
	# 반투명 정렬 대신 알파 컷을 쓴다. 안 그러면 바닥 그림자·표시 원과
	# 서로 앞뒤가 뒤집혀 캐릭터가 바닥에 잘려 보인다.
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.pixel_size = height / float(_front.get_height())
	# 발바닥이 원점에 오게 올린다. 안 그러면 허리까지 바닥에 묻힌다.
	_sprite.offset = Vector2(0, _front.get_height() * 0.5)
	add_child(_sprite)

	if blob_shadow:
		_build_shadow()


func _load(which: String) -> Texture2D:
	var path := "%s-%s.png" % [prefix, which]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _build_shadow() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "BlobShadow"
	var q := QuadMesh.new()
	q.size = Vector2(height * 0.52, height * 0.30)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0.28)
	m.albedo_texture = _soft_blob()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.rotation_degrees.x = -90.0
	mi.position.y = 0.02
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_shadow = mi


## 가운데가 진하고 가장자리로 갈수록 사라지는 원.
func _soft_blob(size: int = 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) - c, float(y) - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_face(cam)
	# 숨쉬기. 그림이라 팔다리를 못 움직이니 이것이 유일한 생기다.
	_bob = sin(_t * 1.9) * 0.006
	_sprite.position.y = _bob


## 얇은 물체에 그림이 잘리지 않게 카메라 쪽으로 조금 띄우는 거리(미터).
##
## 그림은 두께가 없는 판이라, 앞에 얇은 것이 하나만 있어도 몸 한가운데가
## 통째로 잘린다. 실제로 사무실에서 파트너가 의자 등받이에 가려 가슴부터
## 허리까지 검은 사각형이 됐다 — 입체였을 때는 의자 옆으로 몸이 삐져나와
## 티가 안 나던 것이다.
##
## 판을 카메라 쪽으로 조금 당기면 그런 얇은 가림막을 넘어선다. 캐릭터가
## 실제 위치에서 이만큼 어긋나 보이지만, 20cm 도 안 되는 데다 카메라가
## 멀어서 눈에 띄지 않는다. 잘리는 쪽이 훨씬 나쁘다.
const CAMERA_LIFT := 0.16


## 카메라가 이 캐릭터를 어느 쪽에서 보고 있는지에 따라 그림을 고른다.
func _face(cam: Camera3D) -> void:
	var to_cam := cam.global_position - global_position
	to_cam.y = 0.0
	if to_cam.length_squared() < 0.0001:
		return
	to_cam = to_cam.normalized()

	var basis := global_transform.basis
	var fwd := -basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return
	fwd = fwd.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()

	var facing := to_cam.dot(fwd)      #  1 = 카메라가 앞에 있다
	var side := to_cam.dot(right)

	# 경계에서 그림이 딸깍거리지 않게 정면·뒤 구간을 넉넉히 잡는다.
	_sprite.position.x = to_cam.x * CAMERA_LIFT
	_sprite.position.z = to_cam.z * CAMERA_LIFT

	if facing > 0.45:
		_sprite.texture = _front
		_sprite.flip_h = false
	elif facing < -0.45:
		_sprite.texture = _back
		_sprite.flip_h = false
	else:
		_sprite.texture = _side
		# 옆모습 원본은 오른쪽을 본다. 왼쪽에서 보면 뒤집는다.
		_sprite.flip_h = side < 0.0


## 걸을 때 살짝 눌렸다 펴진다.
func set_walking(on: bool) -> void:
	if _sprite == null:
		return
	var s := 1.0 + (sin(_t * 11.0) * 0.035 if on else 0.0)
	_sprite.scale = Vector3(2.0 - s, s, 1.0)
