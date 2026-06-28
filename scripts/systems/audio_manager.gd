extends Node
## AudioManager — 외부 파일 없이 런타임에 PCM을 생성해 소리를 재생한다.
## 22050Hz, 16비트 모노 PCM을 PackedByteArray로 패킹하여 AudioStreamWAV로 사용.

const SR := 22050

var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

var _sfx_lib := {}
var _bgm_stream: AudioStreamWAV = null
var _current_bgm: String = ""

func _ready() -> void:
    _bgm_player = AudioStreamPlayer.new()
    _bgm_player.bus = "Master"
    _bgm_player.volume_db = -12.0
    add_child(_bgm_player)

    _sfx_player = AudioStreamPlayer.new()
    _sfx_player.bus = "Master"
    add_child(_sfx_player)

    # SFX 라이브러리 미리 생성
    _sfx_lib["ui_select"] = _tone([660.0, 880.0], 0.12, 0.4, 0.005, 0.08)
    _sfx_lib["dialogue_tick"] = _tone([1200.0], 0.04, 0.18, 0.002, 0.03)
    _sfx_lib["camera_shutter"] = _noise(0.12, 0.6, 0.5)
    _sfx_lib["footstep"] = _noise(0.09, 0.35, 0.25)

## 톤 버퍼 생성기 (여러 주파수를 합성한 사인파 + attack/decay 엔벨로프)
func _tone(freqs: Array, dur: float, vol: float, attack: float, decay: float) -> AudioStreamWAV:
    var n := int(SR * dur)
    var data := PackedByteArray()
    data.resize(n * 2)
    for i in range(n):
        var t := float(i) / SR
        var s := 0.0
        for f in freqs:
            s += sin(TAU * f * t)
        s /= max(1, freqs.size())
        # 엔벨로프 (attack/decay)
        var env := 1.0
        if t < attack:
            env = t / attack
        elif t > dur - decay:
            env = max(0.0, (dur - t) / decay)
        var v := int(clamp(s * env * vol, -1.0, 1.0) * 32767.0)
        data.encode_s16(i * 2, v)
    var st := AudioStreamWAV.new()
    st.format = AudioStreamWAV.FORMAT_16_BITS
    st.mix_rate = SR
    st.stereo = false
    st.data = data
    return st

## 발소리용 소프트 노이즈 버스트 (간단 저역통과 필터 적용)
func _noise(dur: float, vol: float, lowpass: float) -> AudioStreamWAV:
    var n := int(SR * dur)
    var data := PackedByteArray()
    data.resize(n * 2)
    var prev := 0.0
    var seed_v := 12345
    for i in range(n):
        seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
        var r := (float(seed_v) / 1073741823.0) - 1.0
        prev = lerp(prev, r, lowpass)  # 간단 저역통과
        var t := float(i) / SR
        var env := max(0.0, 1.0 - t / dur)
        var v := int(clamp(prev * env * vol, -1.0, 1.0) * 32767.0)
        data.encode_s16(i * 2, v)
    var st := AudioStreamWAV.new()
    st.format = AudioStreamWAV.FORMAT_16_BITS
    st.mix_rate = SR
    st.stereo = false
    st.data = data
    return st

## 부드럽게 반복되는 앰비언트 패드 (A minor 화음 + 느린 진폭 트레몰로)
func _build_bgm() -> AudioStreamWAV:
    var dur := 4.0
    var n := int(SR * dur)
    var data := PackedByteArray()
    data.resize(n * 2)
    var freqs := [220.0, 261.63, 329.63]  # A minor 패드
    var vol := 0.12
    for i in range(n):
        var t := float(i) / SR
        var s := 0.0
        for f in freqs:
            s += sin(TAU * f * t)
        s /= freqs.size()
        # 느린 진폭 트레몰로 (0.25Hz)
        var tremolo := 0.7 + 0.3 * sin(TAU * 0.25 * t)
        var v := int(clamp(s * tremolo * vol, -1.0, 1.0) * 32767.0)
        data.encode_s16(i * 2, v)
    var st := AudioStreamWAV.new()
    st.format = AudioStreamWAV.FORMAT_16_BITS
    st.mix_rate = SR
    st.stereo = false
    st.data = data
    st.loop_mode = AudioStreamWAV.LOOP_FORWARD
    st.loop_begin = 0
    st.loop_end = n
    return st

# ── 공개 API ──────────────────────────────────────────────

func play_bgm(track_name: String, _fade_in: float = 1.0) -> void:
    if _current_bgm == track_name and _bgm_player.playing:
        return
    if _bgm_stream == null:
        _bgm_stream = _build_bgm()
    _current_bgm = track_name
    _bgm_player.stream = _bgm_stream
    _bgm_player.volume_db = -12.0
    _bgm_player.play()

func stop_bgm(_fade_out: float = 1.0) -> void:
    _bgm_player.stop()
    _current_bgm = ""

func play_sfx(sfx_name: String) -> void:
    if sfx_name in _sfx_lib:
        _sfx_player.stream = _sfx_lib[sfx_name]
        _sfx_player.play()

func footstep() -> void: play_sfx("footstep")
func photo_shutter() -> void: play_sfx("camera_shutter")
func dialogue_tick() -> void: play_sfx("dialogue_tick")
func ui_select() -> void: play_sfx("ui_select")
