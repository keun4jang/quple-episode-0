# GitHub Pages 로 개인정보처리방침 올리기

스토어 등록에는 **인터넷에서 열리는 개인정보처리방침 주소**가 필요하다.
아무것도 수집하지 않아도 주소는 있어야 한다. GitHub Pages 가 공짜다.

## 한 번만 하면 된다

1. GitHub 저장소 → **Settings** → 왼쪽 **Pages**
2. **Source** 를 `Deploy from a branch` 로
3. **Branch** 를 `main`, 폴더를 `/docs` 로 고르고 **Save**
4. 몇 분 뒤 주소가 생긴다:
   `https://keun4jang.github.io/quple-episode-0/pages/privacy`

그 주소를 스토어의 "개인정보처리방침 URL" 칸에 넣는다.

## 주의

- **`main` 브랜치에 있어야 열린다.** 지금 작업 브랜치에만 있으면 안 열린다
- 저장소가 **비공개면 Pages 도 안 열린다** (유료 요금제 제외).
  공개로 두거나, 이 문서만 따로 공개 저장소에 두면 된다
- 내용이 바뀌면 이 파일을 고치고 push 하면 몇 분 뒤 반영된다
