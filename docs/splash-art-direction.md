# 퀴풀 스플래시 아트 디렉션

> **구조 전환(v2): 포스터 우선(Poster-First)** — 캐릭터/디오라마/우주는 단일
> no-text 포스터 이미지 한 장에 포함하고, 코드는 로고/카피/버튼/프레임 UI만 담당.
> Blender 렌더는 debug/fallback 소스로 강등. 프로덕션 교체는 tools/splash/import-splash-art.py.

## 컨셉
파스텔 우주 은하를 배경으로, 퀴카 커플이 작은 미니월드(디오라마 행성) 위에서 여행을 떠나는
힐링 타이틀 화면. 상업용 모바일 캐주얼 게임 포스터 완성도 목표.

## 레이어 구조 (뒤 → 앞)
1. 일러스트 포스터 배경 (`splash-poster-no-text.png`) — 텍스트 없음
2. 3D 앰비언트 별 (코드, Node3D)
3. 3D 캐릭터 커플 (`quica-couple-splash.png`) + halo glow + contact shadow (코드)
4. 크림/골드 라운드 프레임 3겹 (코드 Panel)
5. 3D 젤리 한글 로고 "퀴풀" (코드, 7겹 Label)
6. 서브타이틀 / 하단 카피 (코드 Label)
7. 프리미엄 버튼 (코드 Button + StyleBoxFlat)
8. 반짝임/별똥별 장식 (코드)

## 컬러 팔레트
| 토큰 | HEX |
|---|---|
| space-deep | #16205A |
| space-navy | #241858 |
| pastel-sky | #80D2FF |
| pastel-lavender | #B69BFF |
| pastel-pink | #FFB5C9 |
| pastel-mint | #8FF0C2 |
| cream | #FFF2C8 |
| peach | #FFB28E |
| gold-soft | #FFE4A3 |
| logo-green | #78D866 |
| logo-dark-green | #2F7A4D |
| shadow-purple | #30205F |

## 로고 "퀴풀" 구조 (코드 렌더)
- 뒤: 진한 초록 back-shadow 5겹 (#24643F → #2F7A4D, 아래로 extrusion)
- 본문: 크림 #FFF2C8, 초록 stroke #2F7A4D (outline 16)
- 외곽: 보라 soft shadow rgba(40,20,80,0.55)
- 상단: 흰색 하이라이트 60%
- 좌우: 잎사귀 장식 🌿
- glow pulse 애니메이션 (main_menu_3d.gd `_process`)

## 레이아웃 (9:16)
| 요소 | y 위치 |
|---|---|
| 로고 | 6~22% |
| 서브타이틀 | 22~28% |
| 캐릭터/디오라마 | 37~66% |
| 하단 카피 (2줄) | 70~75% |
| CTA | 78~84% |
| 이어하기 | 86~91% |
| 설정/종료 | 93% |

## 금지
- 단순 파란 구체 히어로 / 코드 도형 캐릭터 / 회색 버튼
- 이미지에 텍스트 굽기 / 하단 거대 검정 패널
- 하단 카피가 버튼에 가려지는 배치
