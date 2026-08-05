extends Node
## 코드로 합성하는 효과음. 외부 사운드 파일을 쓰지 않는다.
## 짧은 파형을 AudioStreamWAV 로 직접 만들어 재생한다.

const SAMPLE_RATE := 22050
const BGM_RATE := 22050        # 음이 매끄럽게 이어지도록 넉넉하게
const LP_ALPHA := 0.26         # 저역통과 세기 (작을수록 부드럽고 덜 날카롭다)
const BUS_SFX := "master"

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}
var _sfx_volume: float = 0.9
var _bgm_volume: float = 0.7
var _bgm_player: AudioStreamPlayer = null
var _bgm_current: String = ""
var _bgm_cache: Dictionary = {}
var _bgm_tween: Tween = null
var _bgm_building: Dictionary = {}
var _quitting: bool = false
var _bgm_tasks: Array[int] = []
# 앰비언트(환경음)는 BGM 과 완전히 독립된 플레이어를 쓴다.
# 여행지가 바뀔 때 배경음악을 건드리지 않고 분위기만 갈아끼우기 위해서다.
var _amb_player: AudioStreamPlayer = null
var _amb_current: String = ""
var _amb_cache: Dictionary = {}
var _amb_building: Dictionary = {}
var _amb_volume: float = 0.8

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_shutdown()

## 종료 전에 배경음 합성 스레드가 끝나기를 기다린다.
## 기다리지 않으면 이미 해제된 객체를 스레드가 건드려 오류가 난다.
func _shutdown() -> void:
	if _quitting:
		return
	_quitting = true
	for id in _bgm_tasks:
		if WorkerThreadPool.is_task_completed(id):
			continue
		WorkerThreadPool.wait_for_task_completion(id)
	_bgm_tasks.clear()

func _ready() -> void:
	tree_exiting.connect(_shutdown)
	# 동시에 여러 소리가 나도 끊기지 않게 풀을 만든다
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)

func set_sfx_volume(v: float) -> void:
	_sfx_volume = clampf(v, 0.0, 1.0)

func set_bgm_volume(v: float) -> void:
	_bgm_volume = clampf(v, 0.0, 1.0)
	if _bgm_player and _bgm_player.playing:
		_bgm_player.volume_db = _bgm_db()

func _bgm_db() -> float:
	if _bgm_volume <= 0.001:
		return -80.0
	return -16.0 + linear_to_db(_bgm_volume)

# ── 배경음악 ────────────────────────────────────────────────────────────

## 배경음악을 튼다. 같은 곡이면 아무것도 하지 않는다.
##   "menu" / "episode0" / "travel" / "room"
func play_bgm(track: String) -> void:
	if track == _bgm_current and _bgm_player and _bgm_player.playing:
		return
	_bgm_current = track
	if not BGM_TRACKS.has(track):
		return
	var cached: AudioStreamWAV = _bgm_cache.get(track, null)
	if cached != null:
		_start_bgm(track, cached)
		return
	if _bgm_building.has(track):
		return   # 이미 만드는 중
	# 합성에 1~2초가 걸리므로 백그라운드에서 만든다 (게임이 끊기지 않게)
	_bgm_building[track] = true
	_bgm_tasks.append(WorkerThreadPool.add_task(_build_bgm_async.bind(track)))

func _build_bgm_async(track: String) -> void:
	# 앱이 종료되는 중이면 이미 해제된 객체를 건드리게 되므로 그만둔다
	if _quitting or not is_instance_valid(self):
		return
	var stream := _build_bgm(track)
	if _quitting or not is_instance_valid(self):
		return
	call_deferred("_on_bgm_built", track, stream)

func _on_bgm_built(track: String, stream: AudioStreamWAV) -> void:
	_bgm_building.erase(track)
	if stream == null:
		return
	_bgm_cache[track] = stream
	# 만드는 사이에 다른 곡으로 넘어갔다면 재생하지 않는다
	if track == _bgm_current:
		_start_bgm(track, stream)

func _start_bgm(track: String, stream: AudioStreamWAV) -> void:
	if _bgm_player == null:
		_bgm_player = AudioStreamPlayer.new()
		_bgm_player.bus = BUS_SFX
		add_child(_bgm_player)
	_bgm_player.stream = stream
	_bgm_player.volume_db = -80.0
	_bgm_player.play()
	_fade_bgm_to(_bgm_db(), 1.6)

func stop_bgm(fade := 0.9) -> void:
	_bgm_current = ""
	if _bgm_player == null or not _bgm_player.playing:
		return
	_fade_bgm_to(-80.0, fade)
	await get_tree().create_timer(fade).timeout
	if _bgm_player:
		_bgm_player.stop()

func _fade_bgm_to(db: float, dur: float) -> void:
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", db, dur)

# ── 공개 API ────────────────────────────────────────────────────────────

func footstep() -> void:
	_play("footstep", -14.0, randf_range(0.92, 1.08))

func shutter() -> void:
	_play("shutter", -6.0)

func ui_click() -> void:
	_play("click", -12.0)

func ui_confirm() -> void:
	_play("confirm", -10.0)

func message_arrive() -> void:
	_play("chime", -9.0)

func souvenir_get() -> void:
	_play("sparkle", -8.0)

# ── 재생 ────────────────────────────────────────────────────────────────

func _play(kind: String, db: float, pitch: float = 1.0) -> void:
	if _sfx_volume <= 0.001:
		return
	var stream: AudioStreamWAV = _cache.get(kind, null)
	if stream == null:
		stream = _build(kind)
		if stream == null:
			return
		_cache[kind] = stream
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = db + linear_to_db(maxf(_sfx_volume, 0.0001))
	p.play()

# ── 파형 합성 ───────────────────────────────────────────────────────────

func _build(kind: String) -> AudioStreamWAV:
	match kind:
		"footstep":  return _make(0.09, _footstep_wave)
		"shutter":   return _make(0.16, _shutter_wave)
		"click":     return _make(0.05, _click_wave)
		"confirm":   return _make(0.22, _confirm_wave)
		"chime":     return _make(0.55, _chime_wave)
		"sparkle":   return _make(0.45, _sparkle_wave)
	return null

## 부드럽고 낮은 툭 소리 (발소리)
func _footstep_wave(t: float, dur: float) -> float:
	var env := exp(-t * 42.0)
	var body := sin(TAU * 118.0 * t) * 0.6
	var noise := (randf() * 2.0 - 1.0) * 0.35 * exp(-t * 70.0)
	return (body + noise) * env

## 찰칵 (사진)
func _shutter_wave(t: float, dur: float) -> float:
	var click1 := (randf() * 2.0 - 1.0) * exp(-t * 160.0)
	var click2 := (randf() * 2.0 - 1.0) * exp(-maxf(0.0, t - 0.055) * 130.0) * (1.0 if t > 0.055 else 0.0)
	var tone := sin(TAU * 1750.0 * t) * 0.22 * exp(-t * 55.0)
	return clampf(click1 * 0.75 + click2 * 0.6 + tone, -1.0, 1.0)

## 짧은 UI 클릭
func _click_wave(t: float, dur: float) -> float:
	return sin(TAU * 880.0 * t) * exp(-t * 90.0) * 0.8

## 확인음 (두 음 상승)
func _confirm_wave(t: float, dur: float) -> float:
	var f := 660.0 if t < dur * 0.45 else 990.0
	var env := exp(-fmod(t, dur * 0.45) * 20.0) * (1.0 - t / dur)
	return sin(TAU * f * t) * env * 0.7

## 소식 도착 (부드러운 3음 종소리)
func _chime_wave(t: float, dur: float) -> float:
	var v := 0.0
	var freqs := [784.0, 988.0, 1319.0]
	for i in range(freqs.size()):
		var start := float(i) * 0.09
		if t < start:
			continue
		var lt := t - start
		v += sin(TAU * float(freqs[i]) * lt) * exp(-lt * 7.0) * 0.34
	return clampf(v, -1.0, 1.0)

## 반짝임 (기념품 획득)
func _sparkle_wave(t: float, dur: float) -> float:
	var sweep := 1200.0 + 1400.0 * (t / dur)
	var env := exp(-t * 9.0) * (1.0 - t / dur)
	var shimmer := sin(TAU * sweep * t) + sin(TAU * sweep * 1.5 * t) * 0.4
	return clampf(shimmer * env * 0.5, -1.0, 1.0)

# ── 배경음악 합성 ───────────────────────────────────────────────────────
#
# 음색이 단조롭지 않도록 악기를 여러 개 만들고 층을 쌓는다.
#   선율(멜로디) + 대선율(아르페지오) + 베이스 + 화음패드
#
# 악기는 모두 코드로 합성한다. 외부 음원 파일이 없다.

const REST := -99

## 악기는 피아노 하나로 통일한다.
## 여러 음색을 섞으면 서로 따로 놀아서, 음역과 세기만 달리해 한 악기로 층을 쌓는다.
##   melody(중음, 또렷) / arp(고음, 여리게) / bass(저음, 길게)

# ── 퍼블릭 도메인 선율 ──────────────────────────────────────────────────
# 저작권이 만료됐거나 작곡자가 없는(전래) 곡만 쓴다. 선율만 기악으로 편곡한다.
const PD_MELODIES := {
	"arirang": {
		"title": "아리랑 (전래민요 · 작곡자 미상)",
		"bpm": 68.0,
		"notes": [
			[9, 1.0], [9, 0.5], [12, 0.5], [9, 1.0],
			[9, 1.0], [9, 0.5], [12, 0.5], [9, 1.0],
			[9, 1.0], [7, 0.5], [4, 0.5], [7, 1.0], [9, 1.5], [REST, 0.5],
			[12, 1.0], [12, 0.5], [12, 0.5], [14, 1.0],
			[12, 1.0], [9, 0.5], [7, 0.5], [9, 1.0],
			[7, 1.0], [4, 0.5], [2, 0.5], [0, 1.5], [REST, 0.5],
		],
	},
	"doraji": {
		"title": "도라지 타령 (전래민요 · 작곡자 미상)",
		"bpm": 76.0,
		"notes": [
			[0, 1.0], [0, 0.5], [2, 0.5], [4, 1.0], [4, 1.0],
			[7, 1.0], [7, 0.5], [9, 0.5], [7, 1.0], [4, 1.0],
			[2, 1.0], [4, 0.5], [2, 0.5], [0, 1.5], [REST, 0.5],
			[7, 1.0], [9, 0.5], [12, 0.5], [9, 1.0], [7, 1.0],
			[4, 1.0], [7, 0.5], [4, 0.5], [2, 1.0], [0, 1.5], [REST, 0.5],
		],
	},
	"gohyang": {
		"title": "고향의 봄 (홍난파, 1927 · 1991 만료)",
		"bpm": 62.0,
		"notes": [
			[7, 0.5], [7, 0.5], [12, 0.5], [12, 0.5], [9, 0.5], [9, 0.5], [7, 1.0],
			[9, 0.5], [7, 0.5], [4, 0.5], [0, 1.5], [REST, 0.5],
			[4, 0.5], [4, 0.5], [7, 0.5], [7, 0.5], [9, 0.5], [9, 0.5], [7, 1.0],
			[4, 0.5], [2, 0.5], [0, 1.5], [REST, 0.5],
			[4, 0.5], [7, 0.5], [9, 0.5], [12, 0.5], [9, 0.5], [7, 0.5], [4, 1.0],
			[2, 0.5], [2, 0.5], [0, 2.0], [REST, 0.5],
		],
	},
	"gaeguri": {
		"title": "개구리 (홍난파 · 1991 만료)",
		"bpm": 104.0,
		"notes": [
			[0, 0.5], [0, 0.5], [2, 0.5], [2, 0.5], [4, 0.5], [4, 0.5], [0, 1.0],
			[2, 0.5], [2, 0.5], [4, 0.5], [0, 1.5], [REST, 0.5],
			[4, 0.5], [4, 0.5], [5, 0.5], [5, 0.5], [7, 0.5], [7, 0.5], [4, 1.0],
			[5, 0.5], [4, 0.5], [2, 0.5], [0, 1.5], [REST, 0.5],
		],
	},
}

## 곡 편성 — 한 사람이 피아노 앞에 앉아 치는 것으로 본다.
##   오른손: 선율
##   왼손  : 화음 반주 (마디마다 근음 → 화음 → 화음)
## 지속되는 배경음(패드)은 사람이 낼 수 없으므로 쓰지 않는다.
const BGM_TRACKS := {
	"arirang": {
		"melody": "arirang", "root": 261.63, "dur": 31.76, "octave": 1,
		"bars": 8, "chords": [[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7]],
		"lh": "ballad", "rubato": 0.020,
	},
	"doraji": {
		"melody": "doraji", "root": 261.63, "dur": 28.42, "octave": 1,
		"bars": 8, "chords": [[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7]],
		"lh": "ballad", "rubato": 0.018,
	},
	"gohyang": {
		"melody": "gohyang", "root": 233.08, "dur": 34.84, "octave": 1,
		"bars": 8, "chords": [[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7]],
		"lh": "waltz", "rubato": 0.024,
	},
	"gaeguri": {
		"melody": "gaeguri", "root": 261.63, "dur": 18.46, "octave": 1,
		"bars": 6, "chords": [[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7],[0,4,7]],
		"lh": "ballad", "rubato": 0.012,
	},
	# 선율이 없는 곡 — 즉흥으로 조용히 친다
	"episode0": {
		"melody": "", "root": 220.00, "dur": 26.0, "octave": 1,
		"chords": [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]],
		"lh": "sparse", "rubato": 0.028,
		"scale": [0, 2, 4, 7, 9, 12], "notes_per_bar": 2,
	},
	"room": {
		"melody": "", "root": 220.00, "dur": 20.0, "octave": 1,
		"chords": [[0, 4, 7], [5, 9, 12], [0, 4, 7], [7, 11, 14]],
		"lh": "waltz", "rubato": 0.022,
		"scale": [0, 2, 4, 7, 9, 12], "notes_per_bar": 2,
	},
}

## 장조에서 쓸 수 있는 화음들 (으뜸음 기준 반음)
const CHORD_CANDIDATES := [
	{"name": "I",   "tones": [0, 4, 7]},
	{"name": "ii",  "tones": [2, 5, 9]},
	{"name": "iii", "tones": [4, 7, 11]},
	{"name": "IV",  "tones": [5, 9, 12]},
	{"name": "V",   "tones": [7, 11, 14]},
	{"name": "vi",  "tones": [9, 12, 16]},
]

## 선율을 듣고 마디마다 가장 잘 맞는 화음을 고른다.
## 임의로 정한 화음은 선율과 부딪히기 때문에, 실제로 울리는 음에서 역산한다.
func _auto_chords(notes: Array, dur: float, bar_count: int, root: float) -> Array:
	var bar := dur / float(bar_count)
	var out: Array = []
	for bi in range(bar_count):
		var t0 := float(bi) * bar
		var t1 := t0 + bar
		# 이 마디에서 울리는 선율 음을 음이름(12음)별로 모은다. 오래 울릴수록 무겁게 센다.
		var weight := {}
		for note in notes:
			var ns: float = float(note.t)
			var ne: float = ns + float(note.len)
			var overlap: float = minf(ne, t1) - maxf(ns, t0)
			if overlap <= 0.0:
				continue
			# 주파수 → 으뜸음 기준 반음 → 음이름
			var semi: int = int(round(12.0 * log(float(note.f) / root) / log(2.0)))
			var pc: int = ((semi % 12) + 12) % 12
			# 마디 앞쪽 음이 화음을 더 강하게 결정한다
			var w: float = overlap * (1.4 if ns < t0 + bar * 0.5 else 1.0)
			weight[pc] = float(weight.get(pc, 0.0)) + w

		var best := 0
		var best_score := -9999.0
		var prev: int = int(out.size() > 0 and out[out.size() - 1] != null)
		# 직전 두 마디에 어떤 화음을 썼는지 (같은 화음만 이어지면 단조롭다)
		var prev1 := -1
		var prev2 := -1
		if out.size() >= 1: prev1 = _chord_index(out[out.size() - 1])
		if out.size() >= 2: prev2 = _chord_index(out[out.size() - 2])
		for i in range(CHORD_CANDIDATES.size()):
			var tones: Array = CHORD_CANDIDATES[i].tones
			var pcs := []
			for tn in tones:
				pcs.append(((int(tn) % 12) + 12) % 12)
			var score := 0.0
			for pc in weight.keys():
				var w: float = float(weight[pc])
				if pcs.has(pc):
					score += w * 2.2          # 화음에 든 음이면 크게 가산
				elif pcs.has((int(pc) + 9) % 12) or pcs.has((int(pc) + 3) % 12):
					score += w * 0.3          # 6도·3도 어울림은 약하게 인정
				else:
					score -= w * 1.6          # 부딪히는 음은 감점
			# 첫 마디와 마지막 마디는 으뜸화음으로 안정되게
			if (bi == 0 or bi == bar_count - 1) and i == 0:
				score += 1.2
			# 같은 화음이 계속 이어지면 지루하다 — 조금씩 감점
			if i == prev1:
				score -= 0.9
				if i == prev2:
					score -= 1.4
			# 마지막 직전 마디는 V 로 가면 마무리가 자연스럽다
			if bi == bar_count - 2 and i == 4:
				score += 0.8
			if score > best_score:
				best_score = score
				best = i
		out.append(CHORD_CANDIDATES[best].tones.duplicate())
	return out

func _chord_index(tones: Array) -> int:
	for i in range(CHORD_CANDIDATES.size()):
		if CHORD_CANDIDATES[i].tones == tones:
			return i
	return -1

func _semi(root: float, n: float) -> float:
	return root * pow(2.0, n / 12.0)

## 루프 안에서 정수 번 진동하도록 보정 (이음매 제거)
func _loopable(f: float, dur: float) -> float:
	return maxf(1.0, round(f * dur)) / dur

# ── 악기별 음 하나를 버퍼에 그린다 ──────────────────────────────────────

func _voice(buf: PackedFloat32Array, start: int, f: float, dur_s: float,
		gain: float, role: String) -> void:
	var len_i := int(dur_s * float(BGM_RATE))
	_piano(buf, start, f, len_i, gain, role)

## 피아노 한 음.
##   - 배음이 정수배보다 아주 조금씩 높다(inharmonicity). 이게 피아노 특유의 울림이다.
##   - 높은 배음일수록 빨리 사라진다. 그래서 칠 때는 밝고 곧 둥글어진다.
##   - 낮은 음은 길게, 높은 음은 짧게 울린다.
func _piano(buf: PackedFloat32Array, start: int, f: float, len_i: int,
		gain: float, role: String) -> void:
	var n := buf.size()
	# 음이 높을수록 빨리 사그라든다 (실제 피아노와 같다)
	var base_decay: float = 1.05 + f / 620.0
	if role == "bass":
		base_decay = 0.62
	elif role == "arp":
		base_decay = 2.2
	# 배음 구성: 세기와 감쇠 속도
	# 고배음을 줄여 귀에 찌르지 않게 한다
	var amps  := [1.00, 0.34, 0.15, 0.07, 0.035]
	var decays := [1.00, 1.60, 2.60, 4.00, 6.00]
	var inharm := 0.00042      # 배음이 살짝 높아지는 정도

	# 망치 소리(어택)를 위해 아주 짧은 잡음을 섞는다
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f * 13.0) + 3

	for i in range(len_i):
		var pos := start + i
		if pos >= n:
			break
		var t := float(i) / float(BGM_RATE)
		var v := 0.0
		for k in range(amps.size()):
			var kn := float(k + 1)
			var fk: float = f * kn * (1.0 + inharm * kn * kn)
			if fk > 3600.0:
				break
			v += sin(TAU * fk * t) * float(amps[k]) * exp(-t * base_decay * float(decays[k]))
		# 망치 타격음 (2ms)
		if t < 0.002:
			v += rng.randf_range(-1.0, 1.0) * 0.07 * (1.0 - t / 0.002)
		# 아주 짧은 어택으로 클릭 방지
		var atk := minf(1.0, t / 0.0025)
		buf[pos] += v * atk * _tail_fade(i, len_i) * gain * 0.55

## 끝 15% 구간을 0 으로 닫아 "툭" 소리를 막는다
func _tail_fade(i: int, len_i: int) -> float:
	var tail := maxi(1, int(float(len_i) * 0.15))
	var left := len_i - i
	if left >= tail:
		return 1.0
	return float(left) / float(tail)

# ── 곡 만들기 ───────────────────────────────────────────────────────────

func _build_bgm(track: String) -> AudioStreamWAV:
	var cfg: Dictionary = BGM_TRACKS.get(track, {})
	if cfg.is_empty():
		return null
	var root: float = cfg.root
	var chords: Array = cfg.chords
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(track)
	var rubato: float = float(cfg.get("rubato", 0.02))

	# ── 박자 격자 ──
	# 왼손과 오른손이 같은 격자를 써야 박이 맞는다.
	# 마디 길이는 곡의 빠르기에서 나온다. 전체 길이는 마디의 정수배로 맞춘다.
	var mel_id0: String = str(cfg.get("melody", ""))
	var beats_per_bar: int = 3 if str(cfg.get("lh", "ballad")) == "waltz" else 4
	var dur: float = float(cfg.get("dur", 24.0))
	var bar: float = dur / float(chords.size())
	if mel_id0 != "" and PD_MELODIES.has(mel_id0):
		var m0: Dictionary = PD_MELODIES[mel_id0]
		var spb: float = 60.0 / float(m0.get("bpm", 60.0))
		var total_beats := 0.0
		for pair in m0.notes:
			total_beats += float(pair[1])
		var bars: int = int(ceil(total_beats / float(beats_per_bar)))
		bars = maxi(bars, 2)
		bar = float(beats_per_bar) * spb
		dur = float(bars) * bar
		chords = []
		for i in range(bars):
			chords.append([0, 4, 7])
	var n := int(BGM_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)

	# ── 오른손: 선율 ──
	var mel_id: String = str(cfg.get("melody", ""))
	var notes: Array = []
	if mel_id != "" and PD_MELODIES.has(mel_id):
		notes = _layout_melody(PD_MELODIES[mel_id], root, int(cfg.octave), dur)
		# 화음을 선율에서 역산한다. 임의로 정하면 부딪힌다.
		chords = _auto_chords(notes, dur, chords.size(), root)
	else:
		notes = _random_melody(cfg, chords, root, dur, bar, rng)
	for note in notes:
		# 두 손이 같은 흔들림(템포 드리프트)을 따른다. 각자 흔들면 박이 안 맞는다.
		var at := maxf(0.0, float(note.t) + _tempo_drift(float(note.t), rubato))
		var vel := float(note.amp) * rng.randf_range(0.9, 1.0)
		_voice(buf, int(at * float(BGM_RATE)), float(note.f),
			float(note.len), 0.42 * vel, "melody")

	# ── 왼손: 화음 반주 ──
	_left_hand(buf, cfg, chords, root, dur, bar, rng, rubato)

	return _finalize(buf, n)

## 사람이 치면 빠르기가 미세하게 출렁인다. 두 손이 이 곡선을 함께 따라야 박이 맞는다.
func _tempo_drift(t: float, amount: float) -> float:
	return (sin(t * 0.83) * 0.6 + sin(t * 1.97 + 1.1) * 0.4) * amount

## 왼손 반주. 사람 손이 닿는 범위에서 마디마다 3~4번만 친다.
func _left_hand(buf: PackedFloat32Array, cfg: Dictionary, chords: Array,
		root: float, dur: float, bar: float, rng: RandomNumberGenerator,
		rubato: float) -> void:
	var style: String = str(cfg.get("lh", "ballad"))
	for ci in range(chords.size()):
		var c: Array = chords[ci]
		var t0: float = float(ci) * bar
		# 각 스타일의 [시각(마디 비율), 어떤 음, 세기]
		# 박 단위로 친다. 오른손과 같은 격자라 박이 어긋나지 않는다.
		var bpb: int = 3 if style == "waltz" else 4
		var beat: float = bar / float(bpb)
		var pattern: Array = []
		match style:
			"waltz":
				# 쿵 - 짝 - 짝 (1박, 2박, 3박)
				pattern = [[0, "root", 0.34], [1, "chord", 0.20], [2, "chord", 0.18]]
			"sparse":
				# 아주 조용히 (1박, 3박)
				pattern = [[0, "root", 0.28], [2, "fifth", 0.16]]
			_:
				# ballad: 근음 - 화음 - 5도 - 화음 (1·2·3·4박)
				pattern = [[0, "root", 0.32], [1, "chord", 0.18],
						   [2, "fifth", 0.24], [3, "chord", 0.17]]
		for step in pattern:
			var beat_i: int = int(step[0])
			var kind: String = str(step[1])
			var vel: float = float(step[2]) * rng.randf_range(0.9, 1.05)
			# 두 손이 같은 흔들림을 공유한다 (각자 흔들면 어긋나 들린다)
			var at: float = t0 + float(beat_i) * beat + _tempo_drift(t0 + float(beat_i) * beat, rubato)
			if at < 0.0 or at > dur - 0.4:
				continue
			var hold: float = bar * (0.9 if kind == "root" else 0.45)
			match kind:
				"root":
					var f := _loopable(_semi(root * 0.25, float(c[0])), dur)
					_voice(buf, int(at * float(BGM_RATE)), f, hold, vel, "bass")
				"fifth":
					var f2 := _loopable(_semi(root * 0.25, float(c[mini(2, c.size() - 1)])), dur)
					_voice(buf, int(at * float(BGM_RATE)), f2, hold, vel, "bass")
				"chord":
					# 화음은 두세 음을 거의 동시에 (사람 손처럼 아주 살짝 어긋나게)
					for k in range(1, c.size()):
						var f3 := _loopable(_semi(root * 0.5, float(c[k])), dur)
						var spread := float(k) * 0.008
						_voice(buf, int((at + spread) * float(BGM_RATE)), f3,
							hold, vel * 0.8, "arp")

## 정해진 선율을 시간축에 배치
func _layout_melody(mel: Dictionary, root: float, oct: int, dur: float) -> Array:
	var out: Array = []
	var spb := 60.0 / float(mel.get("bpm", 60.0))
	var t := 0.0
	for pair in mel.notes:
		var semi: int = int(pair[0])
		var beats: float = float(pair[1])
		var length := beats * spb
		if semi != REST and t + length <= dur - 0.3:
			var f := _loopable(_semi(root * float(oct), float(semi)), dur)
			# 페달을 밟은 것처럼 음이 서로 겹쳐 울리게 넉넉히 준다
			out.append({"t": t, "len": clampf(length * 2.4, 0.9, 3.4), "f": f, "amp": 1.0})
		t += length
	return out

## 선율이 없는 곡용 — 화음에서 음을 골라 즉흥 선율을 만든다
func _random_melody(cfg: Dictionary, chords: Array, root: float,
		dur: float, bar: float, rng: RandomNumberGenerator) -> Array:
	var notes: Array = []
	var scale: Array = cfg.get("scale", [0, 2, 4, 7, 9, 12])
	var oct: int = int(cfg.octave)
	var npb: int = int(cfg.get("notes_per_bar", 2))
	for ci in range(chords.size()):
		for k in range(npb + (rng.randi() % 2)):
			var start: float = float(ci) * bar + rng.randf_range(0.1, 0.8) * bar
			var length: float = rng.randf_range(1.6, 2.6)
			if start + length > dur - 0.3:
				continue
			var si: int = rng.randi() % scale.size()
			if rng.randf() < 0.4:
				si = mini(scale.size() - 1, si + 2)
			var f := _loopable(_semi(root * float(oct), float(scale[si])), dur)
			notes.append({"t": start, "len": length, "f": f, "amp": rng.randf_range(0.75, 1.0)})
	return notes

## 저역통과 + 부드러운 압축 + 정규화 후 16bit 로 변환
func _finalize(buf: PackedFloat32Array, n: int) -> AudioStreamWAV:
	# 최대값을 찾아 정규화 (악기가 여러 층이라 합이 커질 수 있다)
	var peak := 0.0
	for i in range(n):
		peak = maxf(peak, absf(buf[i]))
	var norm := 1.0 if peak < 0.001 else minf(1.0, 0.82 / peak)

	var data := PackedByteArray()
	data.resize(n * 2)
	# 저역통과 필터는 상태가 0 에서 시작하면 도입부만 작아져 루프 이음매가 생긴다.
	# 곡 끝부분을 미리 흘려보내 필터를 "데운" 뒤 본 계산을 시작한다.
	var lp := 0.0
	for i in range(maxi(0, n - 4000), n):
		var pv: float = buf[i] * norm
		pv = pv - (pv * pv * pv) / 3.0
		lp += (pv - lp) * LP_ALPHA
	for i in range(n):
		var v: float = buf[i] * norm
		v = v - (v * v * v) / 3.0          # 부드럽게 눌러 과포화 방지
		lp += (v - lp) * LP_ALPHA          # 날카로운 고역을 깎는다
		var sv := int(clampf(lp, -1.0, 1.0) * 27000.0)
		data[i * 2] = sv & 0xFF
		data[i * 2 + 1] = (sv >> 8) & 0xFF

	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = BGM_RATE
	st.stereo = false
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	return st

## 콜백으로 16bit PCM 스트림을 만든다
func _make(duration: float, wave: Callable) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var v: float = clampf(float(wave.call(t, duration)), -1.0, 1.0)
		# 앞뒤 페이드로 클릭 노이즈 방지
		var fade := minf(1.0, minf(float(i), float(n - i)) / 64.0)
		var s := int(v * fade * 32000.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = SAMPLE_RATE
	st.stereo = false
	st.data = data
	return st

# ── 여행지 앰비언트(환경음) ─────────────────────────────────────────────
#
# 여행지마다 깔리는 배경 환경음. 전부 필터를 먹인 화이트 노이즈로 만든다.
# 외부 음원이 없으므로 "파도/바람/비" 같은 소리는 잡음의 주파수 대역과
# 아주 느린 진폭 변화만으로 흉내낸다. 사람 귀는 이 둘로 대부분을 구분한다.
#
# 루프 이음매 처리:
#   1) 필요한 길이보다 크로스페이드 구간만큼 더 길게 잡음을 만든 뒤
#      꼬리를 머리에 겹쳐 섞는다(정상 잡음이라 티가 나지 않는다).
#   2) 그 뒤에 곱하는 진폭 LFO 는 루프 길이 안에서 정확히 정수 번 돌게 맞춘다.
#   → 시작과 끝의 진폭·파형 통계가 같아져 "툭" 소리가 나지 않는다.

const AMB_RATE := 22050
const AMB_XFADE := 0.6          # 이음매 크로스페이드 길이(초)
const AMB_BASE_DB := -24.0      # BGM 보다 훨씬 작게 깔린다

## kind → [길이(초), 최종 진폭]
const AMB_KINDS := {
	"wave":  [10.0, 0.72],
	"wind":  [9.0,  0.60],
	"rain":  [8.0,  0.62],
	"space": [12.0, 0.66],
	"room":  [8.0,  0.30],   # 거의 무음에 가까운 방 소리
}

func set_ambient_volume(v: float) -> void:
	_amb_volume = clampf(v, 0.0, 1.0)
	if _amb_player and _amb_player.playing:
		_amb_player.volume_db = _amb_db()

func _amb_db() -> float:
	if _amb_volume <= 0.001:
		return -80.0
	return AMB_BASE_DB + linear_to_db(_amb_volume)

## 환경음을 튼다. 같은 종류면 아무것도 하지 않는다.
##   "wave" / "wind" / "rain" / "space" / "room"
func play_ambient(kind: String) -> void:
	if kind == _amb_current and _amb_player and _amb_player.playing:
		return
	_amb_current = kind
	if not AMB_KINDS.has(kind):
		return
	var cached: AudioStreamWAV = _amb_cache.get(kind, null)
	if cached != null:
		_start_ambient(kind, cached)
		return
	if _amb_building.has(kind):
		return   # 이미 만드는 중
	# 10초짜리 파형 합성은 프레임을 잡아먹으므로 백그라운드로 돌린다.
	# 태스크 id 는 BGM 과 같은 배열에 넣어 _shutdown() 이 한 번에 기다리게 한다.
	_amb_building[kind] = true
	_bgm_tasks.append(WorkerThreadPool.add_task(_build_ambient_async.bind(kind)))

func stop_ambient(fade := 0.8) -> void:
	_amb_current = ""
	if _amb_player == null or not _amb_player.playing:
		return
	var tw := create_tween()
	tw.tween_property(_amb_player, "volume_db", -80.0, fade)
	await get_tree().create_timer(fade).timeout
	# 기다리는 사이 다른 환경음이 시작됐다면 끄지 않는다
	if _amb_player and _amb_current == "":
		_amb_player.stop()

func _build_ambient_async(kind: String) -> void:
	if _quitting or not is_instance_valid(self):
		return
	var stream := _build_ambient(kind)
	if _quitting or not is_instance_valid(self):
		return
	call_deferred("_on_ambient_built", kind, stream)

func _on_ambient_built(kind: String, stream: AudioStreamWAV) -> void:
	_amb_building.erase(kind)
	if stream == null:
		return
	_amb_cache[kind] = stream
	if kind == _amb_current:
		_start_ambient(kind, stream)

func _start_ambient(kind: String, stream: AudioStreamWAV) -> void:
	if _amb_player == null:
		_amb_player = AudioStreamPlayer.new()
		_amb_player.bus = BUS_SFX
		add_child(_amb_player)
	_amb_player.stream = stream
	_amb_player.volume_db = -80.0
	_amb_player.play()
	var tw := create_tween()
	tw.tween_property(_amb_player, "volume_db", _amb_db(), 1.4)

# ── 앰비언트 합성 ───────────────────────────────────────────────────────

## 루프 길이 안에서 정수 번 도는 LFO 주파수로 맞춘다 (이음매 제거)
func _amb_lfo_freq(f: float, dur: float) -> float:
	return maxf(1.0, round(f * dur)) / dur

func _build_ambient(kind: String) -> AudioStreamWAV:
	if not AMB_KINDS.has(kind):
		return null
	var spec: Array = AMB_KINDS[kind]
	var dur: float = float(spec[0])
	var gain: float = float(spec[1])
	var n := int(AMB_RATE * dur)
	if kind == "space":
		return _amb_finalize(_amb_space(n, dur), n, gain)

	var xf := int(AMB_RATE * AMB_XFADE)
	var raw := _amb_noise_layer(kind, n + xf)
	# 꼬리를 머리에 겹쳐 섞어 이음매를 없앤다
	for i in range(xf):
		var w := float(i) / float(xf)
		raw[i] = raw[i] * w + raw[n + i] * (1.0 - w)
	raw.resize(n)
	_amb_modulate(kind, raw, n, dur)
	return _amb_finalize(raw, n, gain)

## 종류별로 필터를 먹인 잡음층을 만든다.
func _amb_noise_layer(kind: String, total: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + 7
	# 한 극 저역통과 상태값들. 두 번 걸어 더 완만한 기울기를 만든다.
	var lp1 := 0.0
	var lp2 := 0.0
	var lp_slow := 0.0
	# 비 소리의 알갱이(빗방울) — 남은 감쇠량
	var grain := 0.0
	var grain_dec := 0.0
	for i in range(total):
		var w := rng.randf_range(-1.0, 1.0)
		var v := 0.0
		match kind:
			"wave":
				# 저역통과를 두 번 걸어 낮게 웅웅대는 물소리를 만든다
				lp1 += (w - lp1) * 0.030
				lp2 += (lp1 - lp2) * 0.030
				v = lp2 * 9.0
			"wind":
				# 대역통과 = 완만한 저역통과에서 더 낮은 성분을 뺀다
				lp1 += (w - lp1) * 0.090
				lp_slow += (lp1 - lp_slow) * 0.010
				v = (lp1 - lp_slow) * 3.4
			"rain":
				# 고역 쪽만 남긴다 (원음 - 저역) → 쉭 하는 빗소리
				lp1 += (w - lp1) * 0.35
				v = (w - lp1) * 0.85
				# 알갱이감: 가끔 톡 하고 튀는 물방울을 얹는다
				if rng.randf() < 0.0016:
					grain = rng.randf_range(0.25, 0.6)
					grain_dec = rng.randf_range(0.004, 0.012)
				if grain > 0.0001:
					v += grain * rng.randf_range(-1.0, 1.0)
					grain -= grain * grain_dec
				else:
					grain = 0.0
			"room":
				# 거의 들리지 않는 저역 방 잡음
				lp1 += (w - lp1) * 0.020
				lp2 += (lp1 - lp2) * 0.020
				v = lp2 * 7.0
		buf[i] = v
	return buf

## 잡음층에 아주 느린 진폭 변화를 곱한다. LFO 는 루프 안에서 정수 번 돈다.
func _amb_modulate(kind: String, buf: PackedFloat32Array, n: int, dur: float) -> void:
	match kind:
		"wave":
			# 0.1~0.2Hz 로 아주 느리게 밀려왔다 빠지는 출렁임
			var f1 := _amb_lfo_freq(0.13, dur)
			var f2 := _amb_lfo_freq(0.19, dur)
			for i in range(n):
				var t := float(i) / float(AMB_RATE)
				var s := 0.55 + 0.32 * sin(TAU * f1 * t) + 0.16 * sin(TAU * f2 * t + 1.3)
				buf[i] *= maxf(0.06, s)
		"wind":
			# 여러 주기를 겹쳐 규칙이 잡히지 않는 세기 변화를 만든다
			var g1 := _amb_lfo_freq(0.11, dur)
			var g2 := _amb_lfo_freq(0.29, dur)
			var g3 := _amb_lfo_freq(0.67, dur)
			for i in range(n):
				var t := float(i) / float(AMB_RATE)
				var s := 0.48 + 0.28 * sin(TAU * g1 * t) \
					+ 0.16 * sin(TAU * g2 * t + 2.1) \
					+ 0.08 * sin(TAU * g3 * t + 0.7)
				buf[i] *= maxf(0.05, s)
		"rain":
			# 비는 세기가 거의 일정하다. 아주 옅은 흔들림만 준다.
			var r1 := _amb_lfo_freq(0.17, dur)
			for i in range(n):
				var t := float(i) / float(AMB_RATE)
				buf[i] *= 0.88 + 0.12 * sin(TAU * r1 * t)
		"room":
			var m1 := _amb_lfo_freq(0.07, dur)
			for i in range(n):
				var t := float(i) / float(AMB_RATE)
				buf[i] *= 0.85 + 0.15 * sin(TAU * m1 * t)

## 우주 험 — 40~70Hz 사인을 살짝 어긋나게 겹친다.
## 주파수가 조금씩 다르면 맥놀이가 생겨 "살아 있는" 저주파가 된다.
func _amb_space(n: int, dur: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(n)
	# 모두 루프 길이의 정수배 주기로 맞춰 이음매를 없앤다
	var parts := [
		[_amb_lfo_freq(41.0, dur), 1.00, 0.0],
		[_amb_lfo_freq(41.7, dur), 0.70, 1.1],   # 0.7Hz 차이 → 아주 느린 맥놀이
		[_amb_lfo_freq(55.0, dur), 0.45, 2.4],
		[_amb_lfo_freq(55.9, dur), 0.32, 0.6],
		[_amb_lfo_freq(68.0, dur), 0.22, 3.0],
	]
	var sw := _amb_lfo_freq(0.09, dur)   # 전체 세기의 아주 느린 숨
	for i in range(n):
		var t := float(i) / float(AMB_RATE)
		var v := 0.0
		for p in parts:
			v += sin(TAU * float(p[0]) * t + float(p[2])) * float(p[1])
		buf[i] = v * (0.80 + 0.20 * sin(TAU * sw * t))
	return buf

## 정규화 후 16bit PCM 루프 스트림으로 변환
func _amb_finalize(buf: PackedFloat32Array, n: int, gain: float) -> AudioStreamWAV:
	var peak := 0.0
	for i in range(n):
		peak = maxf(peak, absf(buf[i]))
	var norm := 0.0 if peak < 0.00001 else gain / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var s := int(clampf(buf[i] * norm, -1.0, 1.0) * 32000.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = AMB_RATE
	st.stereo = false
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	return st
