extends Place
## 🏡 고향. 이 게임에서 이름이 없는 유일한 곳.
##
## `docs/story-journey.md` 5절. 작아야 한다 — 마당에 서면 집도 밭도 감나무도
## 한눈에 들어와야 하고, 끝에서 끝까지 스무 걸음이면 된다.
##
## 여기에는 **쿼- 낱말이 하나도 안 나온다** (`docs/world-quo.md` 5절).
## 가게도 상표도 없는 곳이라 붙일 게 없고, 그래서 다른 데보다 조용하다.

func place_name() -> String:
	return "고향"


func _init() -> void:
	legend = {
		"g": "grass",         # 바깥 풀밭
		".": "dry-grass",     # 마당과 풀밭 사이, 밟혀서 누런 데
		"y": "dirt",          # 마당. 비질한 마른 흙
		"s": "stone-slab",    # 집 앞 디딤돌
		"f": "tilled-soil",   # 밭고랑
	}


## 산과 밭 사이의 낮은 집, 마당, 감나무 한 그루, 평상.
##
## 화면 서너 개 분량. 처음엔 24x18 로 만들었더니 지도가 화면보다 작아
## 카메라 바깥의 빈 색이 드러났다. 넓히되, 끝에서 끝까지 스무 걸음을
## 넘기지는 않는다 — 고향은 작아야 한다.
func ground_map() -> String:
	return """
gggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
ggg......................................ggg
ggg......................................ggg
ggg....yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy....ggg
ggg....yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy....ggg
ggg....yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy....ggg
ggg....yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy....ggg
ggg....yyyyyyyyyyyyyssssyyyyyyyyyyyyy....ggg
ggg....yyyyyyyyyyyyyssssyyyyyyyyyyyyy....ggg
ggg....yyyyyyyyyyyyyssssyyyyyyyyyyyyy....ggg
ggg....yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy....ggg
ggg....yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy....ggg
ggg....yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy....ggg
ggg....yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy....ggg
ggg....yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy....ggg
ggg....yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy....ggg
ggg......................................ggg
ggg....ffffff............................ggg
ggg....ffffff............................ggg
ggg......................................ggg
ggg......................................ggg
ggg......................................ggg
gggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
"""


func props() -> Array:
	return [
		# 집. 문이 디딤돌 바로 위에 오게 맞춘다 — 디딤돌은 x 20~23
		[21, 8, "home-house", true],
		# 감나무는 마당 왼쪽. 뒤로 걸어 들어가면 가려진다
		[9, 13, "home-persimmon", true],
		# 평상은 오른쪽. 엔딩에서 여기 앉는다
		[31, 14, "home-deck", false],
		# 밭
		[8, 20, "home-garden", false],
		[11, 20, "home-garden", false],
		# 마당 밖을 조금 꾸민다. 담장은 오른쪽 풀밭 경계에
		[5, 17, "flower-pots", true],
		[38, 10, "fence", true],
		[38, 11, "fence", true],
		[38, 12, "fence", true],
		[4, 4, "shrub", false],
		[36, 21, "boulder", true],
		[24, 22, "pebbles", false],
		[15, 4, "shrub", false],

		# 마당 살림. 시골집 마당에 실제로 있는 것들만 둔다
		[33, 8, "jars", true],           # 장독대는 볕 드는 쪽
		[13, 7, "clothesline", true],    # 빨랫줄
		[28, 6, "pump", true],           # 펌프는 집 옆
		[7, 9, "firewood", true],        # 장작은 처마 밑
		[16, 17, "washtub", false],      # 대야는 굴러다닌다
		[6, 19, "tools", true],          # 연장은 밭 가는 길목
	]


## 감나무 밑에 감이 떨어져 있고, 마당 구석에 이런저런 것이 있다.
##
## 여덟 개는 많다. **다섯 개만** 둔다 — 다 줍는 데 1분이면 되고,
## 다 주웠다는 느낌이 있어야 다음에 왔을 때 다른 게 반갑다.
func pickups() -> Array:
	return [
		[8, 15, "p-persimmon"],      # 감나무 밑
		[10, 16, "p-persimmon"],
		[26, 19, "p-flower"],        # 마당 가장자리
		[34, 18, "p-pebble"],
		[19, 21, "p-acorn"],         # 밭 쪽
	]


## 마당 아래쪽, 집을 올려다보는 자리에서 시작한다.
func spawn_tile() -> Vector2i:
	return Vector2i(21, 14)


func on_built() -> void:
	# 엄마는 마당에서 뭘 널고 있고, 아빠는 밭 옆에서 뭘 고치고 있고,
	# 동생은 평상에 앉아 있다. 셋이 흩어져 있어야 마당이 넓어 보인다.
	put_folk(Vector2i(17, 12), "mom", Vector2.DOWN)
	put_folk(Vector2i(11, 21), "dad", Vector2.RIGHT)
	put_folk(Vector2i(32, 15), "sibling", Vector2.LEFT)
