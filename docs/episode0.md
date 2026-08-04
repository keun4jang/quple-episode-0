# 쿼플 0편: 퇴근 말고 출발

회사에 혼자 남아 야근하는 애인을 데리러 가고, 둘이 함께 회사를 떠나 여행자가 되는 짧은 프롤로그.

## 조작 (키보드 전용, 마우스 불필요)

| 키 | 동작 |
|---|---|
| 방향키 | 이동 (WASD 아님) |
| Space | 조사 / 대화 / 확인 |
| F | 사진 |
| D | 바람 노트(목표) |
| B | 앨범 |
| Esc | 메뉴 / 닫기 |

## 진행 순서 (13단계)

```
START → ENTER_COMPANY → FIND_PARTNER → TALK_PARTNER → CHOICE_WAIT
→ EAVESDROP_BOSS → RETURN_TO_PARTNER → COLLECT_TRAVEL_ITEMS
→ RETURN_BADGE → PARTNER_JOINED → FIRST_PHOTO → ALBUM_CREATED → CLEAR
```

1. 회사 밖에서 시작. 건물에 **딱 하나 켜진 창문**(2.5초 주기로 숨 쉬듯 빛남)
2. 입구로 이동 → Space 로 로비 진입
3. 로비 → 엘리베이터 → 사무실
4. 혼자 야근 중인 애인(어깨가 처진 피곤한 자세)을 만남
5. 대화 → 선택지 → 대표실 복도에서 엿듣기
6. 사무실로 돌아가 **여행 물품 3가지**(카메라·수첩·가방) 수집
7. 로비에서 사원증 반납 → 애인 합류(자세가 펴지고 밝아짐)
8. 회사 앞 빛나는 자리에서 **F 로 첫 사진** → 앨범 첫 페이지 → 자동 저장 → 0편 클리어

## 맵

| 씬 | 설명 |
|---|---|
| `CompanyFront3D` | 저녁 회사 앞. 시작·엔딩 지점 |
| `CompanyLobby3D` | 조용한 로비. 사원증 반납함 |
| `Office3D` | 애인이 야근 중인 사무실. 여행 물품 3개 |
| `BossDoorHallway3D` | 대표실 앞 복도. 문틈으로 새는 빛 |

## 실행 / 테스트

```bash
godot --path .                                        # 게임 실행
godot --headless --path . res://tests/TestEpisode0Flow.tscn   # 0편 흐름 19개
godot --headless --path . res://tests/TestCoreLoop.tscn       # 여행 루프 31개
```

## 제작 원칙

- Godot 기본 Mesh / Material / Light / UI 노드만 사용
- 외부 이미지·3D 모델·사운드·유료 에셋 없음
- 폰트는 프로젝트 전역 볼드 테마(Jua, OFL)
- 회사명은 `쿼카전자` / `QUOKKA CORP` 만 사용 (실제 회사·주소·로고 없음)
