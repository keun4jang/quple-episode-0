# 디자인·연출 스킬 (2026-10)

클로드 코드 스킬 셋을 설치해 전투 화면 연출에 접목했다. 스킬 폴더(`.claude/skills/`)는 `.gitignore` 대상이라
저장소에는 `skills-lock.json`(출처·해시)만 남는다. 다른 컴퓨터에서 다시 깔려면:

```bash
npx --yes skills@latest add gamedev-skills/awesome-gamedev-agent-skills --skill game-feel --agent claude-code --yes --copy
npx --yes skills@latest add jame581/godotprompter --skill particles-vfx --agent claude-code --yes --copy
npx --yes skills@latest add thedivergentai/gd-agentic-skills --skill godot-shaders-basics --agent claude-code --yes --copy
```

| 스킬 | 가져온 것 | 우리 코드 |
|---|---|---|
| game-feel | 쌓이고 줄어드는 '충격'(trauma²) 흔들림 · 시간 멈칫(Engine.time_scale + 실제 시간 타이머) · 작음/보통/큼 충격 단계 · 넘치며 돌아오는 '뽁'(TRANS_BACK) · 예비 동작 · 흔들림/번쩍임 줄이기 설정 | `idle_game.gd` `_impact` `_add_trauma` `_hitstop` `_pop`, `settings_ui.gd` `_add_calm_row` |
| particles-vfx | 한 번 터지는 버스트(explosiveness) · 색 사라짐(color_ramp) · 줄어듦(scale curve) · 폰은 CPU 입자 | `idle_vfx.gd` (빛 조각, 화면 가득 떠다니는 빛망울) |
| godot-shaders-basics | 테두리(outline) · 노이즈 녹아내림(dissolve) · 비녜트 | `idle_actor.gd` 셰이더, `idle_game.gd` `_post` |

그 밖에 풍경(`idle_backdrop.gd`)에 해·달빛 줄기와 지평선 안개를 더했다.

**주의**: gd-agentic-skills 는 Godot 4.7 기준 예제가 섞여 있다. 우리는 4.3 이라 API 를 그대로 베끼지 말고 확인할 것.
**겪은 것**: `Gradient.add_point()` 뒤에 `set_color(1, ..)` 을 하면 번호가 밀려 가운데 점이 바뀐다 - 빛 무늬가 네모로 나왔다.
점은 `offsets`/`colors` 로 한 번에 넣는다 (`IdleVfx._grad`).
