# 실내 배경 그림 — 제미나이 프롬프트

옆에서 보는 0편 맵 네 곳의 배경. 지금은 코드로 그려 두었고, 그림이 들어오면
그 자리에 걸린다. 되돌리려면 파일만 지우면 된다.

받은 파일은 이렇게 넣는다:

```bash
python3 tools/side/import-indoor-bg.py --map office --file ~/받은그림.png
```

`--map` 은 `front` / `lobby` / `office` / `hallway` 넷 중 하나.

**바닥선과 여백은 알아서 처리한다.** 위아래에 덧대어진 단색 띠를 잘라내고,
벽과 바닥이 만나는 줄을 찾아 화면에 맞춘다. 찾은 값이 틀렸을 때만
`--floor 0.78` 처럼 직접 준다. 너무 밝으면 `--dim 0.85`.

**회사 앞은 하늘만 바꾼다.** 바닥선을 찾지 않고, 건물·가로등·인도는
코드가 그린 것을 그대로 쓴다.

---

## 반드시 지켜야 하는 것 넷

이 넷 중 하나라도 어긋나면 그림을 못 쓴다. 예쁜 것보다 이게 먼저다.

**1. 완전히 정면에서 본 단면.**
원근이 있으면 안 된다. 소실점도, 비스듬한 각도도 없어야 한다. 인형의 집을
정면에서 열어 본 것처럼, 벽이 화면과 완전히 평행해야 한다. 캐릭터는 이
그림 위를 좌우로만 걸어다니므로, 조금이라도 각도가 들어가면 걸을수록
바닥과 어긋난다.

**2. 바닥선이 위에서 82% 지점.**
벽과 바닥이 만나는 가로선이 그림 높이의 82% 자리에 있어야 한다.
(예: 세로 1000px 그림이면 위에서 820px 지점) 이 선 위에 캐릭터가 선다.
정확히 82%가 아니어도 된다 — 넣을 때 `--floor` 로 알려 주면 맞춘다.
**대신 바닥선이 처음부터 끝까지 수평이어야 한다.** 기울거나 층이 지면 못 쓴다.

**3. 좌우로 이어 붙여도 어색하지 않을 것.**
맵이 화면보다 훨씬 길어서, 받은 그림을 거울처럼 뒤집어 이어 붙여 늘린다.
그래서 **딱 하나뿐이어야 하는 것**(간판, 큰 시계, 특별한 문)은 넣지 말아야
한다. 여러 개 있어도 이상하지 않은 것(창, 기둥, 천장등)만 넣는다.

**4. 글자와 캐릭터 없음.**
글자는 코드로 얹고, 쿼카 커플은 따로 세운다. 사람·동물·문자·로고가
들어가면 못 쓴다.

## 그 밖의 규격

- **가로로 긴 그림.** 16:9 정도면 충분하다. 클수록 좋다
- **밤.** 네 곳 모두 밤 11시 무렵이다
- **파일 두 개를 같이 올린다.** 이게 화풍을 맞추는 가장 확실한 방법이다
  - `assets/travel/chapter-korea.png` — 배경 화풍의 기준
  - `assets/mascots/sheet/leader-side.png` — **이 캐릭터가 그림 위에 선다.**
    배경만 기준으로 잡으면 캐릭터와 재질이 따로 논다. 실제로 옆에 놓일
    것을 보여 주는 편이 낫다
- **가구는 배경에만.** 앞쪽에 놓이는 책상·물건·문은 코드가 그린다.
  그림 속 가구는 벽에 붙어 있거나 멀리 있는 것만

---

## 프롬프트

제미나이에는 영어가 더 잘 통한다. 위의 파일 두 개를 올리고 아래를 그대로
붙여 넣는다.

**픽셀 화풍으로 바꾸지 않는다.** 쿼카 커플이 부드러운 3D 클레이 렌더라서,
배경만 픽셀로 가면 둘이 완전히 따로 논다 — 이 프로젝트가 며칠 동안 고쳐
온 문제가 정확히 그것이다. 화풍을 바꾸려면 캐릭터부터 다시 그려야 한다.

**한 장씩 확인하고 넘어간다.** 사무실 한 장을 넣어 게임 화면으로 본 뒤에
나머지 셋을 뽑는다. 정면 단면이 제대로 나오는지, 바닥선이 수평인지는
넣어 보기 전에는 알 수 없다.

**같은 대화창에서 이어 뽑는다.** 사무실이 맞게 나왔으면 그 창에서 다음 것을
부탁하는 편이 화풍이 훨씬 잘 붙는다.

**아래쪽은 비워 달라고 한다.** 캐릭터와 코드로 그린 가구가 그 위에 놓인다.
사무실 그림이 잘 맞은 것도 아래를 비워 둔 덕이 컸다.

### 공통 앞머리 (네 개 모두 앞에 붙인다)

```
Soft pastel 3D clay-render style, matte rounded shapes, gentle warm rim light,
muted dusty palette — match the style of the attached reference image exactly.

STRICT ORTHOGRAPHIC SIDE ELEVATION. Absolutely flat, straight-on view like a
dollhouse cross-section. No perspective, no vanishing point, no camera tilt.
Every wall perfectly parallel to the picture plane.

Wide 16:9 horizontal image. The floor line (where wall meets floor) must be a
perfectly straight horizontal line at 82% down from the top, unbroken across
the full width.

Horizontally repeatable: no unique landmarks, no signage, no large single
feature. Only elements that can appear many times (windows, pillars, lights).

No characters, no people, no animals, no text, no letters, no logos, no UI.
```

### 1. 사무실 — `--map office`

```
An open-plan office floor at 11pm, seen from the side.

A long wall of tall night windows showing a distant dark blue city with a few
scattered warm-lit windows. Slim window mullions between them. Above the
windows a low ceiling with recessed strip lights, most of them switched off.
Below the windows a waist-high wall panel. Low fabric cubicle partitions along
the back. Cool blue-grey interior, one or two pools of warm light on the floor.
Quiet, empty, a little lonely — everyone has gone home.
```

**이 맵에 있는 것:** 애인의 책상(모니터 켜짐), 다른 책상 둘, 사다리와 선반,
로비 문(왼쪽 끝), 복도 문(오른쪽 끝). 전부 코드가 그리니 그림에는 넣지 말 것.

### 2. 로비 — `--map lobby`

```
The double-height entrance hall of a small office building at night, seen from
the side.

A tall wall of glass looking out onto a dark street, running the full height of
the space. Polished pale stone floor with soft reflections. Slim columns rising
the whole way up. Warm ceiling downlights near the very top, only some of them
lit. Calm, clean, slightly cold, with one or two warm pools of light on the
floor.

This is a two-storey open volume — the ceiling belongs at the very top of the
image and the middle stays open and airy. Keep the upper-middle band uncluttered.
Keep the lower third simple and uncluttered.
```

**로비만 다른 조건: 천장이 높아야 한다.**
2층 통로와 엘리베이터가 이 공간 **안에서** 위로 올라간다. 통로는 그림의
위에서 약 30% 지점에 그려진다. 사무실처럼 천장이 낮으면 2층이 천장을
뚫고 올라간 꼴이 된다. **2층까지 트인 홀**이어야 한다.

**이 맵에 있는 것:** 안내 데스크, 사원증 반납함, 엘리베이터, 계단, 2층 통로,
바깥 문, 사무실 문. 전부 코드가 그린다.

### 3. 복도 — `--map hallway`

```
A narrow office corridor at night, seen from the side.

Plain windowless walls, closed doors set into them at intervals, small wall
lamps between the doors. Carpet floor. Low ceiling. Cool dim blue-grey light,
noticeably darker than the office. Long, plain, slightly oppressive — the kind
of corridor you walk down when you would rather not.
```

**복도만 다른 조건: 어두워야 하고, 밝은 것이 없어야 한다.**
이 맵에서 유일하게 밝은 것은 **대표실 문틈으로 새어 나오는 빛**이고,
그건 코드가 그린다. 그림 속 벽등이 환하면 그 빛이 묻혀서, 걸어갈수록
문이 가까워지는 느낌이 사라진다. 사무실보다 확실히 어둡게, 벽등은
아주 약하게.

**창이 없어야 한다.** 앞의 둘은 창밖 도시로 숨통이 트이는데, 여기는
막혀 있어야 한다. 답답한 것이 이 장면이 하려는 말이다.

**이 맵에 있는 것:** 대표실 문(문틈으로 새는 빛), 돌아가는 문. 코드가 그린다.

### 4. 회사 앞 — `--map front`

```
A quiet city street at night, seen from the side.

A far-away skyline of dark blue office towers with scattered warm-lit windows,
softly hazy with distance. Empty sky above with a few thin clouds. Nothing in
the foreground — the near ground is left empty.
```

**주의: 이것만 다르다.** 회사 앞은 **먼 밤도시만** 그림으로 바꾼다.
쿼카전자 건물과 가로등, 인도는 코드가 그린 것을 그대로 쓴다.
불 켜진 4층 창 하나가 이 이야기의 시작인데, 배경은 좌우로 이어 붙이므로
그림에 넣으면 그 창이 여러 개로 늘어난다. **하나뿐이어야 하는 것은
그림에 넣지 않는다.**

---

## 받아서 넣는 순서

1. 한 장씩 받는다. 넣어서 게임 화면으로 본 뒤 다음 것을 뽑는다
2. 각각 넣는다
   ```bash
   python3 tools/side/import-indoor-bg.py --map office   --file ~/사무실.png
   python3 tools/side/import-indoor-bg.py --map lobby    --file ~/로비.png
   python3 tools/side/import-indoor-bg.py --map hallway  --file ~/복도.png
   python3 tools/side/import-indoor-bg.py --map front    --file ~/밤하늘.png
   ```
3. 게임을 켜서 본다. 바닥선이 어긋나면 `--floor` 만 고쳐 다시 넣는다
4. 너무 밝아 캐릭터가 묻히면 `--dim 0.85` 을 붙인다

**그림이 들어오면 코드로 그린 가구 색도 같이 봐야 한다.** 책상·계단·문틀이
푸른 회색으로 남아 있으면 따뜻한 그림 위에서 그것만 튄다. 네 맵 모두
`painted` 값을 받아 색을 갈아입도록 해 두었다.

넣은 뒤에도 코드로 그린 배경은 지우지 않는다. 파일을 지우면 바로 돌아온다.
