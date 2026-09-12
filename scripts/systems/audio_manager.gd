extends Node
## AudioManager — 외부 파일 없이 런타임에 PCM을 생성해 소리를 재생한다.
## 22050Hz, 16비트 모노 PCM을 PackedByteArray로 패킹하여 AudioStreamWAV로 사용.

const SR := 22050

var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

var _sfx_lib := {}
var _bgm_cache := {}
var _current_bgm: String = ""

## 씬별 BGM 무드 정의: [주파수들(화음), 길이, 음량, 트레몰로 속도(Hz), 트레몰로 깊이]
const BGM_THEMES := {
    "night":  {"freqs": [220.00, 261.63, 329.63], "dur": 4.0, "vol": 0.12, "trem_hz": 0.25, "trem_depth": 0.3},
    "indoor": {"freqs": [293.66, 349.23, 440.00, 523.25], "dur": 5.0, "vol": 0.10, "trem_hz": 0.18, "trem_depth": 0.22},
    "tense":  {"freqs": [110.00, 155.56, 207.65], "dur": 3.0, "vol": 0.14, "trem_hz": 0.6, "trem_depth": 0.45},
    "menu":   {"freqs": [261.63, 329.63, 392.00, 523.25], "dur": 4.0, "vol": 0.13, "trem_hz": 0.35, "trem_depth": 0.18},
}

var bgm_volume: float = 0.8
var sfx_volume: float = 1.0

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
    _sfx_lib["confirm"] = _tone([523.25, 659.25, 784.0], 0.18, 0.45, 0.005, 0.12)
    _sfx_lib["page_turn"] = _noise(0.08, 0.3, 0.6)
    _sfx_lib["clear_fanfare"] = _fanfare()

## 짧은 3음 상승 팡파르 (게임 클리어용)
func _fanfare() -> AudioStreamWAV:
    var notes := [523.25, 659.25, 784.0, 1046.5]  # C5 E5 G5 C6
    var note_dur := 0.16
    var n := int(SR * note_dur * notes.size())
    var data := PackedByteArray()
    data.resize(n * 2)
    for i in range(n):
        var t := float(i) / SR
        var note_i := int(t / note_dur)
        note_i = min(note_i, notes.size() - 1)
        var local_t := t - note_i * note_dur
        var f: float = notes[note_i]
        var s := sin(TAU * f * local_t) + 0.4 * sin(TAU * f * 2.0 * local_t)
        var env: float = 1.0
        if local_t < 0.01:
            env = local_t / 0.01
        elif local_t > note_dur - 0.05:
            env = max(0.0, (note_dur - local_t) / 0.05)
        var v := int(clamp(s * env * 0.35, -1.0, 1.0) * 32767.0)
        data.encode_s16(i * 2, v)
    var st := AudioStreamWAV.new()
    st.format = AudioStreamWAV.FORMAT_16_BITS
    st.mix_rate = SR
    st.stereo = false
    st.data = data
    return st

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
        var env: float = 1.0
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
        var env: float = max(0.0, 1.0 - t / dur)
        var v := int(clamp(prev * env * vol, -1.0, 1.0) * 32767.0)
        data.encode_s16(i * 2, v)
    var st := AudioStreamWAV.new()
    st.format = AudioStreamWAV.FORMAT_16_BITS
    st.mix_rate = SR
    st.stereo = false
    st.data = data
    return st

## 씬 무드별 반복 앰비언트 패드 (화음 + 진폭 트레몰로), BGM_THEMES 파라미터로 생성
func _build_pad(freqs: Array, dur: float, vol: float, trem_hz: float, trem_depth: float) -> AudioStreamWAV:
    var n := int(SR * dur)
    var data := PackedByteArray()
    data.resize(n * 2)
    for i in range(n):
        var t := float(i) / SR
        var s := 0.0
        for f in freqs:
            s += sin(TAU * f * t)
        s /= freqs.size()
        var tremolo: float = (1.0 - trem_depth) + trem_depth * sin(TAU * trem_hz * t)
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

func _build_bgm(track_name: String) -> AudioStreamWAV:
    var theme: Dictionary = BGM_THEMES.get(track_name, BGM_THEMES["night"])
    return _build_pad(theme.freqs, theme.dur, theme.vol, theme.trem_hz, theme.trem_depth)

# ── 공개 API ──────────────────────────────────────────────

func play_bgm(track_name: String, _fade_in: float = 1.0) -> void:
    if _current_bgm == track_name and _bgm_player.playing:
        return
    if not _bgm_cache.has(track_name):
        _bgm_cache[track_name] = _build_bgm(track_name)
    _current_bgm = track_name
    _bgm_player.stream = _bgm_cache[track_name]
    set_bgm_volume(bgm_volume)
    _bgm_player.play()

func stop_bgm(_fade_out: float = 1.0) -> void:
    _bgm_player.stop()
    _current_bgm = ""

func play_sfx(sfx_name: String) -> void:
    if sfx_name in _sfx_lib:
        _sfx_player.stream = _sfx_lib[sfx_name]
        _sfx_player.volume_db = -40.0 if sfx_volume <= 0.001 else linear_to_db(sfx_volume)
        _sfx_player.play()

func set_bgm_volume(v: float) -> void:
    bgm_volume = clamp(v, 0.0, 1.0)
    if _bgm_player:
        _bgm_player.volume_db = -40.0 if bgm_volume <= 0.001 else linear_to_db(bgm_volume) - 6.0

func set_sfx_volume(v: float) -> void:
    sfx_volume = clamp(v, 0.0, 1.0)
    if _sfx_player:
        _sfx_player.volume_db = -40.0 if sfx_volume <= 0.001 else linear_to_db(sfx_volume)

func footstep() -> void: play_sfx("footstep")
func photo_shutter() -> void: play_sfx("camera_shutter")
func dialogue_tick() -> void: play_sfx("dialogue_tick")
func ui_select() -> void: play_sfx("ui_select")
