extends RefCounted
## 모서리를 깎은 상자를 만든다.
##
## 이 게임의 물체는 거의 전부 BoxMesh 를 크기만 바꿔 쓴다. 그래서 모든 모서리가
## 정확히 90도다. **빛은 90도 모서리에 걸리지 않는다.** 면과 면 사이가 한 픽셀에서
## 뚝 끊기니 하이라이트가 생길 자리가 없고, 아무리 칠하고 텍스처를 얹어도 형태가
## 안 살아난다. 종이를 오려 붙인 것처럼 보이는 진짜 원인이 이거다.
##
## 실제 물건은 모서리가 미세하게 둥글다. 거기 걸린 가는 하이라이트 한 줄이
## "이건 입체다" 라고 말해 준다. 그 한 줄을 만들어 주는 게 이 파일이다.
##
## 만드는 법: 단위 구의 방향들을 가져와 상자 표면으로 밀어낸다.
##   방향 n 에 대해  p = clamp(n * 큰수, -(h-r), h-r) + r * n
## 안쪽 상자(h-r)의 가장 가까운 점에 반지름 r 만큼 부풀리는 것과 같아서,
## 면은 평평하고 모서리만 r 로 둥글어진다.
##
## 반지름은 **월드 기준**으로 정한다. 큰 벽과 작은 소품의 모서리 둥글기가
## 같아야 같은 세계의 물건으로 보인다. 상자를 늘려서 만들면 큰 물체의 모서리가
## 같이 늘어나 물풍선처럼 보인다.

const SEG := 16          # 가로 분할. 모바일이라 넉넉하게 잡지 않는다.
const RINGS := 8         # 세로 분할
const BIG := 1000.0

## 모서리 반지름은 가장 짧은 변에 비례하되 상한을 둔다.
## 얇은 판(간판·창문)에서 반지름이 두께의 절반을 넘으면 판이 알약이 된다.
## 0.16 / 0.075 로 시작했더니 화분 같은 작은 상자가 깎인 보석처럼 보였다.
## 목표는 "모서리가 둥글다" 가 아니라 "모서리에 가는 하이라이트 한 줄" 이다.
const RADIUS_RATIO := 0.10
const RADIUS_MAX := 0.045
const RADIUS_MIN := 0.008

static var _cache: Dictionary = {}


## 이 크기의 상자에 알맞은 모서리 반지름
static func radius_for(size: Vector3) -> float:
	var shortest: float = minf(size.x, minf(size.y, size.z))
	return clampf(shortest * RADIUS_RATIO, RADIUS_MIN, RADIUS_MAX)


## 크기가 조금씩 다른 상자마다 메시를 새로 만들면 씬 하나에 수백 개가 생긴다.
## 1cm 단위로 뭉쳐서 같은 것끼리 나눠 쓴다.
static func _key(size: Vector3, r: float) -> String:
	return "%.2f_%.2f_%.2f_%.3f" % [size.x, size.y, size.z, r]


static func rounded_box(size: Vector3, radius := -1.0) -> ArrayMesh:
	var r: float = radius if radius > 0.0 else radius_for(size)
	var h := size * 0.5
	# 반지름이 반쪽 변보다 크면 안쪽 상자가 뒤집힌다. 그 전에 막는다.
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.92)
	var key := _key(size, r)
	if _cache.has(key):
		return _cache[key]

	var inner := h - Vector3(r, r, r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 구면 좌표로 격자를 만들고, 각 방향을 상자 표면으로 민다.
	var grid: Array = []
	for i in RINGS + 1:
		var v: float = float(i) / float(RINGS)
		var phi: float = v * PI
		var row: Array = []
		for j in SEG + 1:
			var u: float = float(j) / float(SEG)
			var theta: float = u * TAU
			var n := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var core := Vector3(
				clampf(n.x * BIG, -inner.x, inner.x),
				clampf(n.y * BIG, -inner.y, inner.y),
				clampf(n.z * BIG, -inner.z, inner.z))
			row.append({"p": core + n * r, "n": n, "uv": Vector2(u, v)})
		grid.append(row)

	for i in RINGS:
		for j in SEG:
			var a: Dictionary = grid[i][j]
			var b: Dictionary = grid[i][j + 1]
			var c: Dictionary = grid[i + 1][j + 1]
			var d: Dictionary = grid[i + 1][j]
			_tri(st, a, b, c)
			_tri(st, a, c, d)

	# 면은 평평해야 하고 모서리만 둥글어야 한다. 구 방향을 그대로 법선으로 쓰면
	# 평평한 면까지 둥글게 음영이 지므로, 삼각형 기준으로 다시 계산한다.
	st.generate_normals()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func _tri(st: SurfaceTool, a: Dictionary, b: Dictionary, c: Dictionary) -> void:
	for v in [a, b, c]:
		st.set_uv(v["uv"])
		st.add_vertex(v["p"])


## 캐시를 비운다 (테스트용)
static func clear_cache() -> void:
	_cache.clear()
