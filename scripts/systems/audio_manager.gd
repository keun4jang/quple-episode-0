extends Node
## 코드로 합성하는 효과음. 외부 사운드 파일을 쓰지 않는다.
## 짧은 파형을 AudioStreamWAV 로 직접 만들어 재생한다.

const SAMPLE_RATE := 22050
const BUS_SFX := "master"

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}
var _sfx_volume: float = 0.9

func _ready() -> void:
	# 동시에 여러 소리가 나도 끊기지 않게 풀을 만든다
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)

func set_sfx_volume(v: float) -> void:
	_sfx_volume = clampf(v, 0.0, 1.0)

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
