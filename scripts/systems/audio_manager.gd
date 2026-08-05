extends Node
## 코드로 합성하는 효과음. 외부 사운드 파일을 쓰지 않는다.
## 짧은 파형을 AudioStreamWAV 로 직접 만들어 재생한다.

const SAMPLE_RATE := 22050
const BGM_RATE := 16000        # 배경음은 부드러운 음색이라 낮은 레이트로 충분하다
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

func _ready() -> void:
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
	WorkerThreadPool.add_task(_build_bgm_async.bind(track))

func _build_bgm_async(track: String) -> void:
	var stream := _build_bgm(track)
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
# 5음 음계(펜타토닉)만 쓰면 어떤 음을 겹쳐도 불협이 생기지 않는다.
# 모든 주파수를 "루프 길이 안에서 정수 번 진동하도록" 맞춰서 이음매를 없앤다.

## 곡 정의: 근음, 화음 진행(반음 단위), 멜로디 음정, 분위기
const BGM_TRACKS := {
	# 화음은 전부 장3도(+4)를 품은 메이저 계열, 음계는 장5음계로 밝게 유지한다.
	"menu": {
		"root": 261.63, "dur": 24.0,
		# I - IV - V - I  (가장 밝고 열린 진행)
		"chords": [[0, 4, 7, 12], [5, 9, 12, 17], [7, 11, 14, 19], [0, 4, 7, 12]],
		"scale": [0, 2, 4, 7, 9, 12, 14, 16], "mel_gain": 0.38, "pad_gain": 0.28, "octave": 2,
		"notes_per_bar": 2, "decay": 1.5,
	},
	"episode0": {
		"root": 233.08, "dur": 26.0,
		# I - vi - IV - V  밤이지만 따뜻하게. vi 는 색으로만 쓰고 곧 메이저로 풀린다
		"chords": [[0, 4, 7, 12], [9, 12, 16, 21], [5, 9, 12, 17], [7, 11, 14, 19]],
		"scale": [0, 2, 4, 7, 9, 12, 14], "mel_gain": 0.32, "pad_gain": 0.30, "octave": 2,
		"notes_per_bar": 2, "decay": 1.6,
	},
	"travel": {
		"root": 196.00, "dur": 22.0,
		# I - V - IV - I  걷는 느낌으로 경쾌하게
		"chords": [[0, 4, 7, 12], [7, 11, 14, 19], [5, 9, 12, 17], [0, 4, 7, 14]],
		"scale": [0, 2, 4, 7, 9, 12, 14, 16], "mel_gain": 0.42, "pad_gain": 0.26, "octave": 2,
		"notes_per_bar": 3, "decay": 2.1,
	},
	"room": {
		"root": 220.00, "dur": 20.0,
		# I - IV - I - V  오르골처럼 포근하게
		"chords": [[0, 4, 7, 12], [5, 9, 12, 17], [0, 4, 7, 12], [7, 11, 14, 19]],
		"scale": [0, 2, 4, 7, 9, 12, 14], "mel_gain": 0.46, "pad_gain": 0.24, "octave": 3,
		"notes_per_bar": 3, "decay": 2.4,
	},
}

## 반음 → 배음비
func _semi(root: float, n: float) -> float:
	return root * pow(2.0, n / 12.0)

## 루프 안에서 정확히 정수 번 진동하도록 보정 (이음매 제거의 핵심)
func _loopable(f: float, dur: float) -> float:
	return maxf(1.0, round(f * dur)) / dur

func _build_bgm(track: String) -> AudioStreamWAV:
	var cfg: Dictionary = BGM_TRACKS.get(track, {})
	if cfg.is_empty():
		return null
	var dur: float = cfg.dur
	var root: float = cfg.root
	var chords: Array = cfg.chords
	var scale: Array = cfg.scale
	var n := int(BGM_RATE * dur)
	var bar := dur / float(chords.size())

	# 1) 패드 성부 미리 계산 (코드별 3음 × 2배음)
	var pad_voices: Array = []
	for ci in range(chords.size()):
		var voices: Array = []
		for semi in chords[ci]:
			var f := _loopable(_semi(root, float(semi)), dur)
			voices.append(f)
			voices.append(_loopable(f * 2.0, dur))   # 옥타브 배음
		pad_voices.append(voices)

	# 2) 멜로디 음표 배치 (마디마다 1~2개, 루프 경계를 넘지 않게)
	var notes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(track)
	var oct: int = int(cfg.octave)
	var npb: int = int(cfg.get("notes_per_bar", 2))
	for ci in range(chords.size()):
		var count := npb + (rng.randi() % 2)
		for k in range(count):
			var start: float = float(ci) * bar + rng.randf_range(0.15, 0.72) * bar
			var length: float = rng.randf_range(0.8, 1.5)
			if start + length > dur - 0.25:
				continue
			# 위쪽 음을 조금 더 자주 골라 밝게
			var si: int = rng.randi() % scale.size()
			if rng.randf() < 0.45:
				si = mini(scale.size() - 1, si + 2)
			var deg: int = scale[si]
			var f := _loopable(_semi(root * float(oct), float(deg)), dur)
			notes.append({"t": start, "len": length, "f": f, "amp": rng.randf_range(0.7, 1.0)})

	var decay: float = float(cfg.get("decay", 1.9))
	var mel_gain: float = cfg.mel_gain
	var pad_gain: float = cfg.pad_gain

	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(BGM_RATE)
		var v := 0.0

		# 패드: 현재 마디의 코드를 부드럽게 이어 붙인다
		var bi := int(t / bar) % chords.size()
		var bt := fmod(t, bar) / bar
		var cross := smoothstep(0.82, 1.0, bt)          # 마디 끝에서 다음 코드로 교차
		var ni := (bi + 1) % chords.size()
		v += _pad_sum(pad_voices[bi], t) * (1.0 - cross) * pad_gain
		v += _pad_sum(pad_voices[ni], t) * cross * pad_gain

		# 아주 느린 숨결 (음량이 서서히 오르내린다)
		v *= 0.85 + sin(TAU * t / dur) * 0.15

		# 멜로디: 부드러운 어택 + 긴 감쇠
		for note in notes:
			var lt: float = t - float(note.t)
			if lt < 0.0 or lt > float(note.len):
				continue
			var atk: float = minf(1.0, lt / 0.16)
			var rel: float = exp(-lt * decay)
			var f: float = note.f
			v += (sin(TAU * f * t) * 0.72 + sin(TAU * f * 2.0 * t) * 0.22 \
				+ sin(TAU * f * 3.0 * t) * 0.09) \
				* atk * rel * float(note.amp) * mel_gain

		v = clampf(v, -1.0, 1.0)
		# 부드럽게 눌러 과포화 방지
		v = v - (v * v * v) / 3.0
		var sv := int(v * 26000.0)
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

func _pad_sum(voices: Array, t: float) -> float:
	var v := 0.0
	for j in range(voices.size()):
		var f: float = voices[j]
		var w := 1.0 if j % 2 == 0 else 0.32   # 배음은 작게
		v += sin(TAU * f * t) * w
	return v / float(voices.size())

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
