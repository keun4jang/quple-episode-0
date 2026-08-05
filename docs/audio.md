# 효과음 (코드 합성)

외부 사운드 파일을 쓰지 않는다. `AudioStreamWAV` 에 파형을 직접 계산해 넣는다.
`scripts/systems/audio_manager.gd` (오토로드 `AudioManager`)

## 소리 목록

| 호출 | 소리 | 쓰이는 곳 |
|---|---|---|
| `footstep()` | 낮고 짧은 툭 | 플레이어 걷기 |
| `shutter()` | 찰칵 (2단 클릭 + 고음) | 첫 사진 |
| `ui_click()` | 짧은 클릭 | 소식 열기, 기념품 읽기 |
| `ui_confirm()` | 두 음 상승 | 상호작용, 여행 출발 |
| `message_arrive()` | 부드러운 3음 종소리 | 여행 중 소식 도착 |
| `souvenir_get()` | 반짝임 | 기념품 획득 |

## 원리

```gdscript
# 22050Hz, 16bit 모노. t 를 받아 -1.0~1.0 을 돌려주는 함수만 있으면 된다.
func _click_wave(t: float, dur: float) -> float:
	return sin(TAU * 880.0 * t) * exp(-t * 90.0) * 0.8
```

- 앞뒤 64샘플 페이드로 클릭 노이즈를 없앤다
- 한 번 만든 파형은 캐시한다
- 8개 플레이어 풀을 돌려써서 소리가 겹쳐도 끊기지 않는다
- 발소리는 재생마다 피치를 랜덤하게 흔들어 단조롭지 않게 한다

설정 화면의 효과음 슬라이더가 `AudioManager.set_sfx_volume()` 로 연결된다.
