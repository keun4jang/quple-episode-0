extends Node
## 쿼플 코어 루프
##
##   여행 보내기  →  (앱을 꺼도 시간이 흐름)  →  돌아오면 사진과 일기를 확인
##
## 진행은 실제 시각(unix time) 기준이므로 앱을 종료해도 계속된다.
## 이것이 이 게임의 리텐션 장치다 — 플레이어는 "확인하러" 돌아온다.

signal trip_started(dest_id: String)
signal trip_arrived(souvenir: Dictionary)
signal souvenir_collected(souvenir: Dictionary)

## 개발 중에는 여행이 금방 끝나야 확인이 쉽다.
## QUPLE_FAST_TRAVEL=1 이면 초 단위, 아니면 출시용 시간을 쓴다.
static func _is_fast() -> bool:
	return OS.get_environment("QUPLE_FAST_TRAVEL") != ""

## 막(章). 앞 막에서 정해진 곳 수만큼 다녀와야 다음 막이 열린다.
const CHAPTERS: Array[Dictionary] = [
	{"id": "korea",  "name": "국내",      "need_prev": 0},
	{"id": "world",  "name": "해외",      "need_prev": 5},
	{"id": "space",  "name": "우주",      "need_prev": 15},
	{"id": "beyond", "name": "다른 차원", "need_prev": 8},
]

## 해외는 대륙으로 나눠 보여준다
const REGIONS: Array[Dictionary] = [
	{"id": "asia",    "name": "아시아"},
	{"id": "europe",  "name": "유럽"},
	{"id": "africa",  "name": "아프리카"},
	{"id": "america", "name": "아메리카"},
	{"id": "oceania", "name": "오세아니아"},
]

## 자동 생성 — tools/travel/gen_destinations.py
## 국내 17 · 해외 197 · 우주 10 · 다른 차원 1
const DESTINATIONS: Array[Dictionary] = [
	# ── 1막 국내 ──
	{"id": "seoul", "chapter": "korea", "name": "서울", "emoji": "🏯",
	 "tagline": "골목마다 다른 얼굴을 한 도시", "duration_sec": 1800, "fast_sec": 18},
	{"id": "busan", "chapter": "korea", "name": "부산", "emoji": "🌊",
	 "tagline": "바다 냄새가 나는 언덕길", "duration_sec": 2100, "fast_sec": 19},
	{"id": "incheon", "chapter": "korea", "name": "인천", "emoji": "✈",
	 "tagline": "떠나는 사람과 돌아오는 사람", "duration_sec": 2400, "fast_sec": 20},
	{"id": "daegu", "chapter": "korea", "name": "대구", "emoji": "🍎",
	 "tagline": "분지의 여름은 뜨겁고 정겹다", "duration_sec": 2400, "fast_sec": 21},
	{"id": "gwangju", "chapter": "korea", "name": "광주", "emoji": "🎨",
	 "tagline": "골목에 그림이 걸린 도시", "duration_sec": 2700, "fast_sec": 22},
	{"id": "daejeon", "chapter": "korea", "name": "대전", "emoji": "🔬",
	 "tagline": "조용하고 단정한 거리", "duration_sec": 2700, "fast_sec": 23},
	{"id": "ulsan", "chapter": "korea", "name": "울산", "emoji": "🐋",
	 "tagline": "고래가 다니던 바다", "duration_sec": 3000, "fast_sec": 24},
	{"id": "sejong", "chapter": "korea", "name": "세종", "emoji": "🌳",
	 "tagline": "새로 심은 나무가 많은 곳", "duration_sec": 3000, "fast_sec": 25},
	{"id": "gyeonggi", "chapter": "korea", "name": "경기", "emoji": "🚉",
	 "tagline": "서울을 감싼 넓은 들", "duration_sec": 3300, "fast_sec": 26},
	{"id": "gangwon", "chapter": "korea", "name": "강원", "emoji": "⛰",
	 "tagline": "산과 바다가 붙어 있는 곳", "duration_sec": 3600, "fast_sec": 27},
	{"id": "chungbuk", "chapter": "korea", "name": "충북", "emoji": "🍇",
	 "tagline": "해가 잘 드는 언덕", "duration_sec": 3600, "fast_sec": 28},
	{"id": "chungnam", "chapter": "korea", "name": "충남", "emoji": "🌾",
	 "tagline": "느리게 흐르는 강", "duration_sec": 3900, "fast_sec": 29},
	{"id": "jeonbuk", "chapter": "korea", "name": "전북", "emoji": "🍚",
	 "tagline": "밥 냄새가 좋은 고장", "duration_sec": 3900, "fast_sec": 30},
	{"id": "jeonnam", "chapter": "korea", "name": "전남", "emoji": "🏝",
	 "tagline": "섬이 별처럼 흩어진 바다", "duration_sec": 4200, "fast_sec": 31},
	{"id": "gyeongbuk", "chapter": "korea", "name": "경북", "emoji": "🏛",
	 "tagline": "오래된 것이 그대로 남은 곳", "duration_sec": 4200, "fast_sec": 32},
	{"id": "gyeongnam", "chapter": "korea", "name": "경남", "emoji": "⚓",
	 "tagline": "항구와 산이 이웃한 곳", "duration_sec": 4500, "fast_sec": 33},
	{"id": "jeju", "chapter": "korea", "name": "제주", "emoji": "🍊",
	 "tagline": "돌담 사이로 부는 바람", "duration_sec": 5400, "fast_sec": 34},

	# ── 2막 해외 ──
	{"id": "japan", "chapter": "world", "region": "asia", "name": "일본", "emoji": "🇯🇵",
	 "keyword": "조용한 골목", "tagline": "조용한 골목", "duration_sec": 5400, "fast_sec": 20},
	{"id": "china", "chapter": "world", "region": "asia", "name": "중국", "emoji": "🇨🇳",
	 "keyword": "끝없는 성벽", "tagline": "끝없는 성벽", "duration_sec": 6300, "fast_sec": 21},
	{"id": "mongolia", "chapter": "world", "region": "asia", "name": "몽골", "emoji": "🇲🇳",
	 "keyword": "초원의 밤", "tagline": "초원의 밤", "duration_sec": 7200, "fast_sec": 22},
	{"id": "taiwan_x", "chapter": "world", "region": "asia", "name": "대만", "emoji": "🇹🇼",
	 "keyword": "야시장 불빛", "tagline": "야시장 불빛", "duration_sec": 8100, "fast_sec": 23},
	{"id": "vietnam", "chapter": "world", "region": "asia", "name": "베트남", "emoji": "🇻🇳",
	 "keyword": "오토바이 물결", "tagline": "오토바이 물결", "duration_sec": 9000, "fast_sec": 24},
	{"id": "thailand", "chapter": "world", "region": "asia", "name": "태국", "emoji": "🇹🇭",
	 "keyword": "향신료 냄새", "tagline": "향신료 냄새", "duration_sec": 9900, "fast_sec": 25},
	{"id": "laos", "chapter": "world", "region": "asia", "name": "라오스", "emoji": "🇱🇦",
	 "keyword": "느린 강물", "tagline": "느린 강물", "duration_sec": 10800, "fast_sec": 26},
	{"id": "cambodia", "chapter": "world", "region": "asia", "name": "캄보디아", "emoji": "🇰🇭",
	 "keyword": "돌에 새긴 얼굴", "tagline": "돌에 새긴 얼굴", "duration_sec": 11700, "fast_sec": 27},
	{"id": "myanmar", "chapter": "world", "region": "asia", "name": "미얀마", "emoji": "🇲🇲",
	 "keyword": "금빛 탑", "tagline": "금빛 탑", "duration_sec": 12600, "fast_sec": 28},
	{"id": "malaysia", "chapter": "world", "region": "asia", "name": "말레이시아", "emoji": "🇲🇾",
	 "keyword": "쌍둥이 탑", "tagline": "쌍둥이 탑", "duration_sec": 13500, "fast_sec": 29},
	{"id": "singapore", "chapter": "world", "region": "asia", "name": "싱가포르", "emoji": "🇸🇬",
	 "keyword": "정원 같은 도시", "tagline": "정원 같은 도시", "duration_sec": 14400, "fast_sec": 20},
	{"id": "indonesia", "chapter": "world", "region": "asia", "name": "인도네시아", "emoji": "🇮🇩",
	 "keyword": "섬과 화산", "tagline": "섬과 화산", "duration_sec": 15300, "fast_sec": 21},
	{"id": "philippines", "chapter": "world", "region": "asia", "name": "필리핀", "emoji": "🇵🇭",
	 "keyword": "투명한 바다", "tagline": "투명한 바다", "duration_sec": 5400, "fast_sec": 22},
	{"id": "brunei", "chapter": "world", "region": "asia", "name": "브루나이", "emoji": "🇧🇳",
	 "keyword": "물 위의 마을", "tagline": "물 위의 마을", "duration_sec": 6300, "fast_sec": 23},
	{"id": "timor", "chapter": "world", "region": "asia", "name": "동티모르", "emoji": "🇹🇱",
	 "keyword": "젊은 나라의 아침", "tagline": "젊은 나라의 아침", "duration_sec": 7200, "fast_sec": 24},
	{"id": "india", "chapter": "world", "region": "asia", "name": "인도", "emoji": "🇮🇳",
	 "keyword": "하얀 대리석", "tagline": "하얀 대리석", "duration_sec": 8100, "fast_sec": 25},
	{"id": "nepal", "chapter": "world", "region": "asia", "name": "네팔", "emoji": "🇳🇵",
	 "keyword": "설산의 능선", "tagline": "설산의 능선", "duration_sec": 9000, "fast_sec": 26},
	{"id": "bhutan", "chapter": "world", "region": "asia", "name": "부탄", "emoji": "🇧🇹",
	 "keyword": "골짜기의 절", "tagline": "골짜기의 절", "duration_sec": 9900, "fast_sec": 27},
	{"id": "bangladesh", "chapter": "world", "region": "asia", "name": "방글라데시", "emoji": "🇧🇩",
	 "keyword": "강이 많은 땅", "tagline": "강이 많은 땅", "duration_sec": 10800, "fast_sec": 28},
	{"id": "srilanka", "chapter": "world", "region": "asia", "name": "스리랑카", "emoji": "🇱🇰",
	 "keyword": "차밭의 초록", "tagline": "차밭의 초록", "duration_sec": 11700, "fast_sec": 29},
	{"id": "maldives", "chapter": "world", "region": "asia", "name": "몰디브", "emoji": "🇲🇻",
	 "keyword": "물 위의 오두막", "tagline": "물 위의 오두막", "duration_sec": 12600, "fast_sec": 20},
	{"id": "pakistan", "chapter": "world", "region": "asia", "name": "파키스탄", "emoji": "🇵🇰",
	 "keyword": "높은 고개", "tagline": "높은 고개", "duration_sec": 13500, "fast_sec": 21},
	{"id": "afghanistan", "chapter": "world", "region": "asia", "name": "아프가니스탄", "emoji": "🇦🇫",
	 "keyword": "마른 산맥", "tagline": "마른 산맥", "duration_sec": 14400, "fast_sec": 22},
	{"id": "iran", "chapter": "world", "region": "asia", "name": "이란", "emoji": "🇮🇷",
	 "keyword": "푸른 타일", "tagline": "푸른 타일", "duration_sec": 15300, "fast_sec": 23},
	{"id": "iraq", "chapter": "world", "region": "asia", "name": "이라크", "emoji": "🇮🇶",
	 "keyword": "두 강 사이", "tagline": "두 강 사이", "duration_sec": 5400, "fast_sec": 24},
	{"id": "syria", "chapter": "world", "region": "asia", "name": "시리아", "emoji": "🇸🇾",
	 "keyword": "오래된 시장", "tagline": "오래된 시장", "duration_sec": 6300, "fast_sec": 25},
	{"id": "lebanon", "chapter": "world", "region": "asia", "name": "레바논", "emoji": "🇱🇧",
	 "keyword": "삼나무 언덕", "tagline": "삼나무 언덕", "duration_sec": 7200, "fast_sec": 26},
	{"id": "jordan", "chapter": "world", "region": "asia", "name": "요르단", "emoji": "🇯🇴",
	 "keyword": "붉은 바위 도시", "tagline": "붉은 바위 도시", "duration_sec": 8100, "fast_sec": 27},
	{"id": "israel", "chapter": "world", "region": "asia", "name": "이스라엘", "emoji": "🇮🇱",
	 "keyword": "오래된 성벽", "tagline": "오래된 성벽", "duration_sec": 9000, "fast_sec": 28},
	{"id": "palestine_x", "chapter": "world", "region": "asia", "name": "팔레스타인", "emoji": "🇵🇸",
	 "keyword": "올리브 나무", "tagline": "올리브 나무", "duration_sec": 9900, "fast_sec": 29},
	{"id": "saudi", "chapter": "world", "region": "asia", "name": "사우디아라비아", "emoji": "🇸🇦",
	 "keyword": "사막의 밤", "tagline": "사막의 밤", "duration_sec": 10800, "fast_sec": 20},
	{"id": "uae", "chapter": "world", "region": "asia", "name": "아랍에미리트", "emoji": "🇦🇪",
	 "keyword": "유리로 된 도시", "tagline": "유리로 된 도시", "duration_sec": 11700, "fast_sec": 21},
	{"id": "qatar", "chapter": "world", "region": "asia", "name": "카타르", "emoji": "🇶🇦",
	 "keyword": "바다 위 신도시", "tagline": "바다 위 신도시", "duration_sec": 12600, "fast_sec": 22},
	{"id": "kuwait", "chapter": "world", "region": "asia", "name": "쿠웨이트", "emoji": "🇰🇼",
	 "keyword": "만의 바람", "tagline": "만의 바람", "duration_sec": 13500, "fast_sec": 23},
	{"id": "bahrain", "chapter": "world", "region": "asia", "name": "바레인", "emoji": "🇧🇭",
	 "keyword": "진주의 섬", "tagline": "진주의 섬", "duration_sec": 14400, "fast_sec": 24},
	{"id": "oman", "chapter": "world", "region": "asia", "name": "오만", "emoji": "🇴🇲",
	 "keyword": "협곡의 물빛", "tagline": "협곡의 물빛", "duration_sec": 15300, "fast_sec": 25},
	{"id": "yemen", "chapter": "world", "region": "asia", "name": "예멘", "emoji": "🇾🇪",
	 "keyword": "흙으로 지은 탑", "tagline": "흙으로 지은 탑", "duration_sec": 5400, "fast_sec": 26},
	{"id": "turkey", "chapter": "world", "region": "asia", "name": "튀르키예", "emoji": "🇹🇷",
	 "keyword": "두 대륙 사이", "tagline": "두 대륙 사이", "duration_sec": 6300, "fast_sec": 27},
	{"id": "georgia", "chapter": "world", "region": "asia", "name": "조지아", "emoji": "🇬🇪",
	 "keyword": "포도밭 계곡", "tagline": "포도밭 계곡", "duration_sec": 7200, "fast_sec": 28},
	{"id": "armenia", "chapter": "world", "region": "asia", "name": "아르메니아", "emoji": "🇦🇲",
	 "keyword": "돌로 지은 교회", "tagline": "돌로 지은 교회", "duration_sec": 8100, "fast_sec": 29},
	{"id": "azerbaijan", "chapter": "world", "region": "asia", "name": "아제르바이잔", "emoji": "🇦🇿",
	 "keyword": "불의 언덕", "tagline": "불의 언덕", "duration_sec": 9000, "fast_sec": 20},
	{"id": "kazakhstan", "chapter": "world", "region": "asia", "name": "카자흐스탄", "emoji": "🇰🇿",
	 "keyword": "넓은 초원", "tagline": "넓은 초원", "duration_sec": 9900, "fast_sec": 21},
	{"id": "uzbekistan", "chapter": "world", "region": "asia", "name": "우즈베키스탄", "emoji": "🇺🇿",
	 "keyword": "푸른 돔", "tagline": "푸른 돔", "duration_sec": 10800, "fast_sec": 22},
	{"id": "turkmenistan", "chapter": "world", "region": "asia", "name": "투르크메니스탄", "emoji": "🇹🇲",
	 "keyword": "불타는 구덩이", "tagline": "불타는 구덩이", "duration_sec": 11700, "fast_sec": 23},
	{"id": "kyrgyzstan", "chapter": "world", "region": "asia", "name": "키르기스스탄", "emoji": "🇰🇬",
	 "keyword": "산 위의 호수", "tagline": "산 위의 호수", "duration_sec": 12600, "fast_sec": 24},
	{"id": "tajikistan", "chapter": "world", "region": "asia", "name": "타지키스탄", "emoji": "🇹🇯",
	 "keyword": "높은 고원", "tagline": "높은 고원", "duration_sec": 13500, "fast_sec": 25},
	{"id": "northkorea", "chapter": "world", "region": "asia", "name": "조선", "emoji": "🇰🇵",
	 "keyword": "가까운 북쪽", "tagline": "가까운 북쪽", "duration_sec": 14400, "fast_sec": 26},
	{"id": "france", "chapter": "world", "region": "europe", "name": "프랑스", "emoji": "🇫🇷",
	 "keyword": "빵 냄새와 탑", "tagline": "빵 냄새와 탑", "duration_sec": 15300, "fast_sec": 27},
	{"id": "uk", "chapter": "world", "region": "europe", "name": "영국", "emoji": "🇬🇧",
	 "keyword": "안개 낀 강", "tagline": "안개 낀 강", "duration_sec": 5400, "fast_sec": 28},
	{"id": "ireland", "chapter": "world", "region": "europe", "name": "아일랜드", "emoji": "🇮🇪",
	 "keyword": "초록 절벽", "tagline": "초록 절벽", "duration_sec": 6300, "fast_sec": 29},
	{"id": "germany", "chapter": "world", "region": "europe", "name": "독일", "emoji": "🇩🇪",
	 "keyword": "오래된 광장", "tagline": "오래된 광장", "duration_sec": 7200, "fast_sec": 20},
	{"id": "netherlands", "chapter": "world", "region": "europe", "name": "네덜란드", "emoji": "🇳🇱",
	 "keyword": "운하와 자전거", "tagline": "운하와 자전거", "duration_sec": 8100, "fast_sec": 21},
	{"id": "belgium", "chapter": "world", "region": "europe", "name": "벨기에", "emoji": "🇧🇪",
	 "keyword": "골목의 초콜릿", "tagline": "골목의 초콜릿", "duration_sec": 9000, "fast_sec": 22},
	{"id": "luxembourg", "chapter": "world", "region": "europe", "name": "룩셈부르크", "emoji": "🇱🇺",
	 "keyword": "성벽 위 산책", "tagline": "성벽 위 산책", "duration_sec": 9900, "fast_sec": 23},
	{"id": "switzerland", "chapter": "world", "region": "europe", "name": "스위스", "emoji": "🇨🇭",
	 "keyword": "눈 덮인 봉우리", "tagline": "눈 덮인 봉우리", "duration_sec": 10800, "fast_sec": 24},
	{"id": "austria", "chapter": "world", "region": "europe", "name": "오스트리아", "emoji": "🇦🇹",
	 "keyword": "음악이 흐르는 거리", "tagline": "음악이 흐르는 거리", "duration_sec": 11700, "fast_sec": 25},
	{"id": "italy", "chapter": "world", "region": "europe", "name": "이탈리아", "emoji": "🇮🇹",
	 "keyword": "돌길과 분수", "tagline": "돌길과 분수", "duration_sec": 12600, "fast_sec": 26},
	{"id": "spain", "chapter": "world", "region": "europe", "name": "스페인", "emoji": "🇪🇸",
	 "keyword": "해가 긴 광장", "tagline": "해가 긴 광장", "duration_sec": 13500, "fast_sec": 27},
	{"id": "portugal", "chapter": "world", "region": "europe", "name": "포르투갈", "emoji": "🇵🇹",
	 "keyword": "파란 타일", "tagline": "파란 타일", "duration_sec": 14400, "fast_sec": 28},
	{"id": "andorra", "chapter": "world", "region": "europe", "name": "안도라", "emoji": "🇦🇩",
	 "keyword": "산속 작은 나라", "tagline": "산속 작은 나라", "duration_sec": 15300, "fast_sec": 29},
	{"id": "monaco", "chapter": "world", "region": "europe", "name": "모나코", "emoji": "🇲🇨",
	 "keyword": "바다 옆 절벽", "tagline": "바다 옆 절벽", "duration_sec": 5400, "fast_sec": 20},
	{"id": "malta", "chapter": "world", "region": "europe", "name": "몰타", "emoji": "🇲🇹",
	 "keyword": "꿀빛 돌담", "tagline": "꿀빛 돌담", "duration_sec": 6300, "fast_sec": 21},
	{"id": "sanmarino", "chapter": "world", "region": "europe", "name": "산마리노", "emoji": "🇸🇲",
	 "keyword": "언덕 위 성", "tagline": "언덕 위 성", "duration_sec": 7200, "fast_sec": 22},
	{"id": "vatican", "chapter": "world", "region": "europe", "name": "바티칸", "emoji": "🇻🇦",
	 "keyword": "가장 작은 나라", "tagline": "가장 작은 나라", "duration_sec": 8100, "fast_sec": 23},
	{"id": "greece", "chapter": "world", "region": "europe", "name": "그리스", "emoji": "🇬🇷",
	 "keyword": "하얀 집과 파란 문", "tagline": "하얀 집과 파란 문", "duration_sec": 9000, "fast_sec": 24},
	{"id": "cyprus", "chapter": "world", "region": "europe", "name": "키프로스", "emoji": "🇨🇾",
	 "keyword": "지중해의 섬", "tagline": "지중해의 섬", "duration_sec": 9900, "fast_sec": 25},
	{"id": "denmark", "chapter": "world", "region": "europe", "name": "덴마크", "emoji": "🇩🇰",
	 "keyword": "색색의 부두", "tagline": "색색의 부두", "duration_sec": 10800, "fast_sec": 26},
	{"id": "norway", "chapter": "world", "region": "europe", "name": "노르웨이", "emoji": "🇳🇴",
	 "keyword": "깊은 피오르", "tagline": "깊은 피오르", "duration_sec": 11700, "fast_sec": 27},
	{"id": "sweden", "chapter": "world", "region": "europe", "name": "스웨덴", "emoji": "🇸🇪",
	 "keyword": "숲과 호수", "tagline": "숲과 호수", "duration_sec": 12600, "fast_sec": 28},
	{"id": "finland", "chapter": "world", "region": "europe", "name": "핀란드", "emoji": "🇫🇮",
	 "keyword": "오로라의 밤", "tagline": "오로라의 밤", "duration_sec": 13500, "fast_sec": 29},
	{"id": "iceland", "chapter": "world", "region": "europe", "name": "아이슬란드", "emoji": "🇮🇸",
	 "keyword": "김이 나는 땅", "tagline": "김이 나는 땅", "duration_sec": 14400, "fast_sec": 20},
	{"id": "estonia", "chapter": "world", "region": "europe", "name": "에스토니아", "emoji": "🇪🇪",
	 "keyword": "중세의 지붕", "tagline": "중세의 지붕", "duration_sec": 15300, "fast_sec": 21},
	{"id": "latvia", "chapter": "world", "region": "europe", "name": "라트비아", "emoji": "🇱🇻",
	 "keyword": "호박의 해변", "tagline": "호박의 해변", "duration_sec": 5400, "fast_sec": 22},
	{"id": "lithuania", "chapter": "world", "region": "europe", "name": "리투아니아", "emoji": "🇱🇹",
	 "keyword": "언덕의 십자가", "tagline": "언덕의 십자가", "duration_sec": 6300, "fast_sec": 23},
	{"id": "poland", "chapter": "world", "region": "europe", "name": "폴란드", "emoji": "🇵🇱",
	 "keyword": "광장의 종소리", "tagline": "광장의 종소리", "duration_sec": 7200, "fast_sec": 24},
	{"id": "czech", "chapter": "world", "region": "europe", "name": "체코", "emoji": "🇨🇿",
	 "keyword": "다리 위의 조각", "tagline": "다리 위의 조각", "duration_sec": 8100, "fast_sec": 25},
	{"id": "slovakia", "chapter": "world", "region": "europe", "name": "슬로바키아", "emoji": "🇸🇰",
	 "keyword": "성 아래 마을", "tagline": "성 아래 마을", "duration_sec": 9000, "fast_sec": 26},
	{"id": "hungary", "chapter": "world", "region": "europe", "name": "헝가리", "emoji": "🇭🇺",
	 "keyword": "강 위의 다리", "tagline": "강 위의 다리", "duration_sec": 9900, "fast_sec": 27},
	{"id": "romania", "chapter": "world", "region": "europe", "name": "루마니아", "emoji": "🇷🇴",
	 "keyword": "숲속의 성", "tagline": "숲속의 성", "duration_sec": 10800, "fast_sec": 28},
	{"id": "bulgaria", "chapter": "world", "region": "europe", "name": "불가리아", "emoji": "🇧🇬",
	 "keyword": "장미의 골짜기", "tagline": "장미의 골짜기", "duration_sec": 11700, "fast_sec": 29},
	{"id": "serbia", "chapter": "world", "region": "europe", "name": "세르비아", "emoji": "🇷🇸",
	 "keyword": "두 강의 만남", "tagline": "두 강의 만남", "duration_sec": 12600, "fast_sec": 20},
	{"id": "croatia", "chapter": "world", "region": "europe", "name": "크로아티아", "emoji": "🇭🇷",
	 "keyword": "주황 지붕과 바다", "tagline": "주황 지붕과 바다", "duration_sec": 13500, "fast_sec": 21},
	{"id": "slovenia", "chapter": "world", "region": "europe", "name": "슬로베니아", "emoji": "🇸🇮",
	 "keyword": "호수 위 섬", "tagline": "호수 위 섬", "duration_sec": 14400, "fast_sec": 22},
	{"id": "bosnia", "chapter": "world", "region": "europe", "name": "보스니아", "emoji": "🇧🇦",
	 "keyword": "돌다리", "tagline": "돌다리", "duration_sec": 15300, "fast_sec": 23},
	{"id": "montenegro", "chapter": "world", "region": "europe", "name": "몬테네그로", "emoji": "🇲🇪",
	 "keyword": "검은 산", "tagline": "검은 산", "duration_sec": 5400, "fast_sec": 24},
	{"id": "northmacedonia", "chapter": "world", "region": "europe", "name": "북마케도니아", "emoji": "🇲🇰",
	 "keyword": "오래된 호수", "tagline": "오래된 호수", "duration_sec": 6300, "fast_sec": 25},
	{"id": "albania", "chapter": "world", "region": "europe", "name": "알바니아", "emoji": "🇦🇱",
	 "keyword": "산과 해안", "tagline": "산과 해안", "duration_sec": 7200, "fast_sec": 26},
	{"id": "kosovo_x", "chapter": "world", "region": "europe", "name": "코소보", "emoji": "🇽🇰",
	 "keyword": "젊은 도시", "tagline": "젊은 도시", "duration_sec": 8100, "fast_sec": 27},
	{"id": "moldova", "chapter": "world", "region": "europe", "name": "몰도바", "emoji": "🇲🇩",
	 "keyword": "땅속 포도주", "tagline": "땅속 포도주", "duration_sec": 9000, "fast_sec": 28},
	{"id": "ukraine", "chapter": "world", "region": "europe", "name": "우크라이나", "emoji": "🇺🇦",
	 "keyword": "넓은 밀밭", "tagline": "넓은 밀밭", "duration_sec": 9900, "fast_sec": 29},
	{"id": "belarus", "chapter": "world", "region": "europe", "name": "벨라루스", "emoji": "🇧🇾",
	 "keyword": "자작나무 숲", "tagline": "자작나무 숲", "duration_sec": 10800, "fast_sec": 20},
	{"id": "russia", "chapter": "world", "region": "europe", "name": "러시아", "emoji": "🇷🇺",
	 "keyword": "끝없는 기차", "tagline": "끝없는 기차", "duration_sec": 11700, "fast_sec": 21},
	{"id": "liechtenstein", "chapter": "world", "region": "europe", "name": "리히텐슈타인", "emoji": "🇱🇮",
	 "keyword": "알프스의 공국", "tagline": "알프스의 공국", "duration_sec": 12600, "fast_sec": 22},
	{"id": "egypt", "chapter": "world", "region": "africa", "name": "이집트", "emoji": "🇪🇬",
	 "keyword": "사막의 삼각형", "tagline": "사막의 삼각형", "duration_sec": 13500, "fast_sec": 23},
	{"id": "morocco", "chapter": "world", "region": "africa", "name": "모로코", "emoji": "🇲🇦",
	 "keyword": "파란 골목", "tagline": "파란 골목", "duration_sec": 14400, "fast_sec": 24},
	{"id": "algeria", "chapter": "world", "region": "africa", "name": "알제리", "emoji": "🇩🇿",
	 "keyword": "사하라의 문", "tagline": "사하라의 문", "duration_sec": 15300, "fast_sec": 25},
	{"id": "tunisia", "chapter": "world", "region": "africa", "name": "튀니지", "emoji": "🇹🇳",
	 "keyword": "하얀 언덕마을", "tagline": "하얀 언덕마을", "duration_sec": 5400, "fast_sec": 26},
	{"id": "libya", "chapter": "world", "region": "africa", "name": "리비아", "emoji": "🇱🇾",
	 "keyword": "해안의 유적", "tagline": "해안의 유적", "duration_sec": 6300, "fast_sec": 27},
	{"id": "sudan", "chapter": "world", "region": "africa", "name": "수단", "emoji": "🇸🇩",
	 "keyword": "작은 피라미드", "tagline": "작은 피라미드", "duration_sec": 7200, "fast_sec": 28},
	{"id": "southsudan", "chapter": "world", "region": "africa", "name": "남수단", "emoji": "🇸🇸",
	 "keyword": "젊은 강", "tagline": "젊은 강", "duration_sec": 8100, "fast_sec": 29},
	{"id": "ethiopia", "chapter": "world", "region": "africa", "name": "에티오피아", "emoji": "🇪🇹",
	 "keyword": "바위를 판 교회", "tagline": "바위를 판 교회", "duration_sec": 9000, "fast_sec": 20},
	{"id": "eritrea", "chapter": "world", "region": "africa", "name": "에리트레아", "emoji": "🇪🇷",
	 "keyword": "붉은 바다", "tagline": "붉은 바다", "duration_sec": 9900, "fast_sec": 21},
	{"id": "djibouti", "chapter": "world", "region": "africa", "name": "지부티", "emoji": "🇩🇯",
	 "keyword": "소금 호수", "tagline": "소금 호수", "duration_sec": 10800, "fast_sec": 22},
	{"id": "somalia", "chapter": "world", "region": "africa", "name": "소말리아", "emoji": "🇸🇴",
	 "keyword": "긴 해안선", "tagline": "긴 해안선", "duration_sec": 11700, "fast_sec": 23},
	{"id": "kenya", "chapter": "world", "region": "africa", "name": "케냐", "emoji": "🇰🇪",
	 "keyword": "초원의 무리", "tagline": "초원의 무리", "duration_sec": 12600, "fast_sec": 24},
	{"id": "uganda", "chapter": "world", "region": "africa", "name": "우간다", "emoji": "🇺🇬",
	 "keyword": "나일의 시작", "tagline": "나일의 시작", "duration_sec": 13500, "fast_sec": 25},
	{"id": "rwanda", "chapter": "world", "region": "africa", "name": "르완다", "emoji": "🇷🇼",
	 "keyword": "천 개의 언덕", "tagline": "천 개의 언덕", "duration_sec": 14400, "fast_sec": 26},
	{"id": "burundi", "chapter": "world", "region": "africa", "name": "부룬디", "emoji": "🇧🇮",
	 "keyword": "호수의 나라", "tagline": "호수의 나라", "duration_sec": 15300, "fast_sec": 27},
	{"id": "tanzania", "chapter": "world", "region": "africa", "name": "탄자니아", "emoji": "🇹🇿",
	 "keyword": "눈 덮인 적도", "tagline": "눈 덮인 적도", "duration_sec": 5400, "fast_sec": 28},
	{"id": "nigeria", "chapter": "world", "region": "africa", "name": "나이지리아", "emoji": "🇳🇬",
	 "keyword": "북적이는 거리", "tagline": "북적이는 거리", "duration_sec": 6300, "fast_sec": 29},
	{"id": "ghana", "chapter": "world", "region": "africa", "name": "가나", "emoji": "🇬🇭",
	 "keyword": "황금 해안", "tagline": "황금 해안", "duration_sec": 7200, "fast_sec": 20},
	{"id": "senegal", "chapter": "world", "region": "africa", "name": "세네갈", "emoji": "🇸🇳",
	 "keyword": "분홍 호수", "tagline": "분홍 호수", "duration_sec": 8100, "fast_sec": 21},
	{"id": "mali", "chapter": "world", "region": "africa", "name": "말리", "emoji": "🇲🇱",
	 "keyword": "흙으로 지은 도서관", "tagline": "흙으로 지은 도서관", "duration_sec": 9000, "fast_sec": 22},
	{"id": "burkina", "chapter": "world", "region": "africa", "name": "부르키나파소", "emoji": "🇧🇫",
	 "keyword": "붉은 흙길", "tagline": "붉은 흙길", "duration_sec": 9900, "fast_sec": 23},
	{"id": "niger", "chapter": "world", "region": "africa", "name": "니제르", "emoji": "🇳🇪",
	 "keyword": "사막의 강", "tagline": "사막의 강", "duration_sec": 10800, "fast_sec": 24},
	{"id": "chad", "chapter": "world", "region": "africa", "name": "차드", "emoji": "🇹🇩",
	 "keyword": "사라지는 호수", "tagline": "사라지는 호수", "duration_sec": 11700, "fast_sec": 25},
	{"id": "cameroon", "chapter": "world", "region": "africa", "name": "카메룬", "emoji": "🇨🇲",
	 "keyword": "작은 아프리카", "tagline": "작은 아프리카", "duration_sec": 12600, "fast_sec": 26},
	{"id": "car", "chapter": "world", "region": "africa", "name": "중앙아프리카공화국", "emoji": "🇨🇫",
	 "keyword": "깊은 숲", "tagline": "깊은 숲", "duration_sec": 13500, "fast_sec": 27},
	{"id": "gabon", "chapter": "world", "region": "africa", "name": "가봉", "emoji": "🇬🇦",
	 "keyword": "해변의 코끼리", "tagline": "해변의 코끼리", "duration_sec": 14400, "fast_sec": 28},
	{"id": "congo", "chapter": "world", "region": "africa", "name": "콩고", "emoji": "🇨🇬",
	 "keyword": "큰 강", "tagline": "큰 강", "duration_sec": 15300, "fast_sec": 29},
	{"id": "drcongo", "chapter": "world", "region": "africa", "name": "콩고민주공화국", "emoji": "🇨🇩",
	 "keyword": "밀림의 심장", "tagline": "밀림의 심장", "duration_sec": 5400, "fast_sec": 20},
	{"id": "angola", "chapter": "world", "region": "africa", "name": "앙골라", "emoji": "🇦🇴",
	 "keyword": "대서양의 절벽", "tagline": "대서양의 절벽", "duration_sec": 6300, "fast_sec": 21},
	{"id": "zambia", "chapter": "world", "region": "africa", "name": "잠비아", "emoji": "🇿🇲",
	 "keyword": "천둥 치는 연기", "tagline": "천둥 치는 연기", "duration_sec": 7200, "fast_sec": 22},
	{"id": "zimbabwe", "chapter": "world", "region": "africa", "name": "짐바브웨", "emoji": "🇿🇼",
	 "keyword": "돌로 쌓은 도시", "tagline": "돌로 쌓은 도시", "duration_sec": 8100, "fast_sec": 23},
	{"id": "malawi", "chapter": "world", "region": "africa", "name": "말라위", "emoji": "🇲🇼",
	 "keyword": "별이 비치는 호수", "tagline": "별이 비치는 호수", "duration_sec": 9000, "fast_sec": 24},
	{"id": "mozambique", "chapter": "world", "region": "africa", "name": "모잠비크", "emoji": "🇲🇿",
	 "keyword": "산호의 해안", "tagline": "산호의 해안", "duration_sec": 9900, "fast_sec": 25},
	{"id": "botswana", "chapter": "world", "region": "africa", "name": "보츠와나", "emoji": "🇧🇼",
	 "keyword": "물이 고인 사막", "tagline": "물이 고인 사막", "duration_sec": 10800, "fast_sec": 26},
	{"id": "namibia", "chapter": "world", "region": "africa", "name": "나미비아", "emoji": "🇳🇦",
	 "keyword": "붉은 모래언덕", "tagline": "붉은 모래언덕", "duration_sec": 11700, "fast_sec": 27},
	{"id": "southafrica", "chapter": "world", "region": "africa", "name": "남아프리카공화국", "emoji": "🇿🇦",
	 "keyword": "두 바다가 만나는 곶", "tagline": "두 바다가 만나는 곶", "duration_sec": 12600, "fast_sec": 28},
	{"id": "lesotho", "chapter": "world", "region": "africa", "name": "레소토", "emoji": "🇱🇸",
	 "keyword": "하늘 위 왕국", "tagline": "하늘 위 왕국", "duration_sec": 13500, "fast_sec": 29},
	{"id": "eswatini", "chapter": "world", "region": "africa", "name": "에스와티니", "emoji": "🇸🇿",
	 "keyword": "골짜기의 왕국", "tagline": "골짜기의 왕국", "duration_sec": 14400, "fast_sec": 20},
	{"id": "madagascar", "chapter": "world", "region": "africa", "name": "마다가스카르", "emoji": "🇲🇬",
	 "keyword": "바오밥 길", "tagline": "바오밥 길", "duration_sec": 15300, "fast_sec": 21},
	{"id": "mauritius", "chapter": "world", "region": "africa", "name": "모리셔스", "emoji": "🇲🇺",
	 "keyword": "산호초의 섬", "tagline": "산호초의 섬", "duration_sec": 5400, "fast_sec": 22},
	{"id": "seychelles", "chapter": "world", "region": "africa", "name": "세이셸", "emoji": "🇸🇨",
	 "keyword": "화강암 해변", "tagline": "화강암 해변", "duration_sec": 6300, "fast_sec": 23},
	{"id": "comoros", "chapter": "world", "region": "africa", "name": "코모로", "emoji": "🇰🇲",
	 "keyword": "향기의 섬", "tagline": "향기의 섬", "duration_sec": 7200, "fast_sec": 24},
	{"id": "capeverde", "chapter": "world", "region": "africa", "name": "카보베르데", "emoji": "🇨🇻",
	 "keyword": "대서양의 화산섬", "tagline": "대서양의 화산섬", "duration_sec": 8100, "fast_sec": 25},
	{"id": "guineabissau", "chapter": "world", "region": "africa", "name": "기니비사우", "emoji": "🇬🇼",
	 "keyword": "맹그로브 강", "tagline": "맹그로브 강", "duration_sec": 9000, "fast_sec": 26},
	{"id": "guinea", "chapter": "world", "region": "africa", "name": "기니", "emoji": "🇬🇳",
	 "keyword": "물의 성", "tagline": "물의 성", "duration_sec": 9900, "fast_sec": 27},
	{"id": "sierraleone", "chapter": "world", "region": "africa", "name": "시에라리온", "emoji": "🇸🇱",
	 "keyword": "사자의 산", "tagline": "사자의 산", "duration_sec": 10800, "fast_sec": 28},
	{"id": "liberia", "chapter": "world", "region": "africa", "name": "라이베리아", "emoji": "🇱🇷",
	 "keyword": "비가 많은 해안", "tagline": "비가 많은 해안", "duration_sec": 11700, "fast_sec": 29},
	{"id": "ivorycoast", "chapter": "world", "region": "africa", "name": "코트디부아르", "emoji": "🇨🇮",
	 "keyword": "석호의 도시", "tagline": "석호의 도시", "duration_sec": 12600, "fast_sec": 20},
	{"id": "togo", "chapter": "world", "region": "africa", "name": "토고", "emoji": "🇹🇬",
	 "keyword": "좁고 긴 나라", "tagline": "좁고 긴 나라", "duration_sec": 13500, "fast_sec": 21},
	{"id": "benin", "chapter": "world", "region": "africa", "name": "베냉", "emoji": "🇧🇯",
	 "keyword": "물 위의 마을", "tagline": "물 위의 마을", "duration_sec": 14400, "fast_sec": 22},
	{"id": "gambia", "chapter": "world", "region": "africa", "name": "감비아", "emoji": "🇬🇲",
	 "keyword": "강을 따라", "tagline": "강을 따라", "duration_sec": 15300, "fast_sec": 23},
	{"id": "mauritania", "chapter": "world", "region": "africa", "name": "모리타니", "emoji": "🇲🇷",
	 "keyword": "사막의 기차", "tagline": "사막의 기차", "duration_sec": 5400, "fast_sec": 24},
	{"id": "saotome", "chapter": "world", "region": "africa", "name": "상투메프린시페", "emoji": "🇸🇹",
	 "keyword": "초콜릿 섬", "tagline": "초콜릿 섬", "duration_sec": 6300, "fast_sec": 25},
	{"id": "equatorialguinea", "chapter": "world", "region": "africa", "name": "적도기니", "emoji": "🇬🇶",
	 "keyword": "적도의 만", "tagline": "적도의 만", "duration_sec": 7200, "fast_sec": 26},
	{"id": "usa", "chapter": "world", "region": "america", "name": "미국", "emoji": "🇺🇸",
	 "keyword": "잠들지 않는 불빛", "tagline": "잠들지 않는 불빛", "duration_sec": 8100, "fast_sec": 27},
	{"id": "canada", "chapter": "world", "region": "america", "name": "캐나다", "emoji": "🇨🇦",
	 "keyword": "단풍과 호수", "tagline": "단풍과 호수", "duration_sec": 9000, "fast_sec": 28},
	{"id": "mexico", "chapter": "world", "region": "america", "name": "멕시코", "emoji": "🇲🇽",
	 "keyword": "색이 진한 골목", "tagline": "색이 진한 골목", "duration_sec": 9900, "fast_sec": 29},
	{"id": "guatemala", "chapter": "world", "region": "america", "name": "과테말라", "emoji": "🇬🇹",
	 "keyword": "호수와 화산", "tagline": "호수와 화산", "duration_sec": 10800, "fast_sec": 20},
	{"id": "belize", "chapter": "world", "region": "america", "name": "벨리즈", "emoji": "🇧🇿",
	 "keyword": "푸른 구멍", "tagline": "푸른 구멍", "duration_sec": 11700, "fast_sec": 21},
	{"id": "honduras", "chapter": "world", "region": "america", "name": "온두라스", "emoji": "🇭🇳",
	 "keyword": "마야의 계단", "tagline": "마야의 계단", "duration_sec": 12600, "fast_sec": 22},
	{"id": "elsalvador", "chapter": "world", "region": "america", "name": "엘살바도르", "emoji": "🇸🇻",
	 "keyword": "화산의 나라", "tagline": "화산의 나라", "duration_sec": 13500, "fast_sec": 23},
	{"id": "nicaragua", "chapter": "world", "region": "america", "name": "니카라과", "emoji": "🇳🇮",
	 "keyword": "호수 속 화산", "tagline": "호수 속 화산", "duration_sec": 14400, "fast_sec": 24},
	{"id": "costarica", "chapter": "world", "region": "america", "name": "코스타리카", "emoji": "🇨🇷",
	 "keyword": "구름 숲", "tagline": "구름 숲", "duration_sec": 15300, "fast_sec": 25},
	{"id": "panama", "chapter": "world", "region": "america", "name": "파나마", "emoji": "🇵🇦",
	 "keyword": "두 바다를 잇는 길", "tagline": "두 바다를 잇는 길", "duration_sec": 5400, "fast_sec": 26},
	{"id": "cuba", "chapter": "world", "region": "america", "name": "쿠바", "emoji": "🇨🇺",
	 "keyword": "오래된 자동차", "tagline": "오래된 자동차", "duration_sec": 6300, "fast_sec": 27},
	{"id": "jamaica", "chapter": "world", "region": "america", "name": "자메이카", "emoji": "🇯🇲",
	 "keyword": "박자가 느린 섬", "tagline": "박자가 느린 섬", "duration_sec": 7200, "fast_sec": 28},
	{"id": "haiti", "chapter": "world", "region": "america", "name": "아이티", "emoji": "🇭🇹",
	 "keyword": "산이 많은 땅", "tagline": "산이 많은 땅", "duration_sec": 8100, "fast_sec": 29},
	{"id": "dominicanrep", "chapter": "world", "region": "america", "name": "도미니카공화국", "emoji": "🇩🇴",
	 "keyword": "야자수 해변", "tagline": "야자수 해변", "duration_sec": 9000, "fast_sec": 20},
	{"id": "bahamas", "chapter": "world", "region": "america", "name": "바하마", "emoji": "🇧🇸",
	 "keyword": "얕고 맑은 바다", "tagline": "얕고 맑은 바다", "duration_sec": 9900, "fast_sec": 21},
	{"id": "barbados", "chapter": "world", "region": "america", "name": "바베이도스", "emoji": "🇧🇧",
	 "keyword": "분홍 모래", "tagline": "분홍 모래", "duration_sec": 10800, "fast_sec": 22},
	{"id": "trinidad", "chapter": "world", "region": "america", "name": "트리니다드토바고", "emoji": "🇹🇹",
	 "keyword": "축제의 섬", "tagline": "축제의 섬", "duration_sec": 11700, "fast_sec": 23},
	{"id": "grenada", "chapter": "world", "region": "america", "name": "그레나다", "emoji": "🇬🇩",
	 "keyword": "향신료의 섬", "tagline": "향신료의 섬", "duration_sec": 12600, "fast_sec": 24},
	{"id": "stlucia", "chapter": "world", "region": "america", "name": "세인트루시아", "emoji": "🇱🇨",
	 "keyword": "두 개의 봉우리", "tagline": "두 개의 봉우리", "duration_sec": 13500, "fast_sec": 25},
	{"id": "stvincent", "chapter": "world", "region": "america", "name": "세인트빈센트그레나딘", "emoji": "🇻🇨",
	 "keyword": "작은 섬들", "tagline": "작은 섬들", "duration_sec": 14400, "fast_sec": 26},
	{"id": "antigua", "chapter": "world", "region": "america", "name": "앤티가바부다", "emoji": "🇦🇬",
	 "keyword": "해변이 365개", "tagline": "해변이 365개", "duration_sec": 15300, "fast_sec": 27},
	{"id": "dominica", "chapter": "world", "region": "america", "name": "도미니카연방", "emoji": "🇩🇲",
	 "keyword": "끓는 호수", "tagline": "끓는 호수", "duration_sec": 5400, "fast_sec": 28},
	{"id": "stkitts", "chapter": "world", "region": "america", "name": "세인트키츠네비스", "emoji": "🇰🇳",
	 "keyword": "사탕수수 철길", "tagline": "사탕수수 철길", "duration_sec": 6300, "fast_sec": 29},
	{"id": "brazil", "chapter": "world", "region": "america", "name": "브라질", "emoji": "🇧🇷",
	 "keyword": "거대한 강과 숲", "tagline": "거대한 강과 숲", "duration_sec": 7200, "fast_sec": 20},
	{"id": "argentina", "chapter": "world", "region": "america", "name": "아르헨티나", "emoji": "🇦🇷",
	 "keyword": "끝없는 초원", "tagline": "끝없는 초원", "duration_sec": 8100, "fast_sec": 21},
	{"id": "chile", "chapter": "world", "region": "america", "name": "칠레", "emoji": "🇨🇱",
	 "keyword": "가장 긴 나라", "tagline": "가장 긴 나라", "duration_sec": 9000, "fast_sec": 22},
	{"id": "peru", "chapter": "world", "region": "america", "name": "페루", "emoji": "🇵🇪",
	 "keyword": "구름 위 도시", "tagline": "구름 위 도시", "duration_sec": 9900, "fast_sec": 23},
	{"id": "bolivia", "chapter": "world", "region": "america", "name": "볼리비아", "emoji": "🇧🇴",
	 "keyword": "하늘이 비치는 소금밭", "tagline": "하늘이 비치는 소금밭", "duration_sec": 10800, "fast_sec": 24},
	{"id": "colombia", "chapter": "world", "region": "america", "name": "콜롬비아", "emoji": "🇨🇴",
	 "keyword": "커피 언덕", "tagline": "커피 언덕", "duration_sec": 11700, "fast_sec": 25},
	{"id": "venezuela", "chapter": "world", "region": "america", "name": "베네수엘라", "emoji": "🇻🇪",
	 "keyword": "하늘에서 떨어지는 물", "tagline": "하늘에서 떨어지는 물", "duration_sec": 12600, "fast_sec": 26},
	{"id": "ecuador", "chapter": "world", "region": "america", "name": "에콰도르", "emoji": "🇪🇨",
	 "keyword": "적도의 한가운데", "tagline": "적도의 한가운데", "duration_sec": 13500, "fast_sec": 27},
	{"id": "paraguay", "chapter": "world", "region": "america", "name": "파라과이", "emoji": "🇵🇾",
	 "keyword": "붉은 흙과 강", "tagline": "붉은 흙과 강", "duration_sec": 14400, "fast_sec": 28},
	{"id": "uruguay", "chapter": "world", "region": "america", "name": "우루과이", "emoji": "🇺🇾",
	 "keyword": "조용한 해안 도시", "tagline": "조용한 해안 도시", "duration_sec": 15300, "fast_sec": 29},
	{"id": "guyana", "chapter": "world", "region": "america", "name": "가이아나", "emoji": "🇬🇾",
	 "keyword": "밀림의 폭포", "tagline": "밀림의 폭포", "duration_sec": 5400, "fast_sec": 20},
	{"id": "suriname", "chapter": "world", "region": "america", "name": "수리남", "emoji": "🇸🇷",
	 "keyword": "나무로 지은 도시", "tagline": "나무로 지은 도시", "duration_sec": 6300, "fast_sec": 21},
	{"id": "australia", "chapter": "world", "region": "oceania", "name": "호주", "emoji": "🇦🇺",
	 "keyword": "쿼카가 사는 섬", "tagline": "쿼카가 사는 섬", "duration_sec": 7200, "fast_sec": 22},
	{"id": "newzealand", "chapter": "world", "region": "oceania", "name": "뉴질랜드", "emoji": "🇳🇿",
	 "keyword": "초록 언덕과 양", "tagline": "초록 언덕과 양", "duration_sec": 8100, "fast_sec": 23},
	{"id": "fiji", "chapter": "world", "region": "oceania", "name": "피지", "emoji": "🇫🇯",
	 "keyword": "따뜻한 산호 바다", "tagline": "따뜻한 산호 바다", "duration_sec": 9000, "fast_sec": 24},
	{"id": "papua", "chapter": "world", "region": "oceania", "name": "파푸아뉴기니", "emoji": "🇵🇬",
	 "keyword": "깊은 숲의 새", "tagline": "깊은 숲의 새", "duration_sec": 9900, "fast_sec": 25},
	{"id": "solomon", "chapter": "world", "region": "oceania", "name": "솔로몬제도", "emoji": "🇸🇧",
	 "keyword": "흩어진 섬들", "tagline": "흩어진 섬들", "duration_sec": 10800, "fast_sec": 26},
	{"id": "vanuatu", "chapter": "world", "region": "oceania", "name": "바누아투", "emoji": "🇻🇺",
	 "keyword": "활화산의 섬", "tagline": "활화산의 섬", "duration_sec": 11700, "fast_sec": 27},
	{"id": "samoa", "chapter": "world", "region": "oceania", "name": "사모아", "emoji": "🇼🇸",
	 "keyword": "야자수 그늘", "tagline": "야자수 그늘", "duration_sec": 12600, "fast_sec": 28},
	{"id": "tonga", "chapter": "world", "region": "oceania", "name": "통가", "emoji": "🇹🇴",
	 "keyword": "고래가 오는 바다", "tagline": "고래가 오는 바다", "duration_sec": 13500, "fast_sec": 29},
	{"id": "kiribati", "chapter": "world", "region": "oceania", "name": "키리바시", "emoji": "🇰🇮",
	 "keyword": "날짜가 시작되는 곳", "tagline": "날짜가 시작되는 곳", "duration_sec": 14400, "fast_sec": 20},
	{"id": "tuvalu", "chapter": "world", "region": "oceania", "name": "투발루", "emoji": "🇹🇻",
	 "keyword": "낮고 작은 섬", "tagline": "낮고 작은 섬", "duration_sec": 15300, "fast_sec": 21},
	{"id": "nauru", "chapter": "world", "region": "oceania", "name": "나우루", "emoji": "🇳🇷",
	 "keyword": "가장 작은 공화국", "tagline": "가장 작은 공화국", "duration_sec": 5400, "fast_sec": 22},
	{"id": "palau", "chapter": "world", "region": "oceania", "name": "팔라우", "emoji": "🇵🇼",
	 "keyword": "해파리 호수", "tagline": "해파리 호수", "duration_sec": 6300, "fast_sec": 23},
	{"id": "micronesia", "chapter": "world", "region": "oceania", "name": "미크로네시아", "emoji": "🇫🇲",
	 "keyword": "돌 화폐의 섬", "tagline": "돌 화폐의 섬", "duration_sec": 7200, "fast_sec": 24},
	{"id": "marshall", "chapter": "world", "region": "oceania", "name": "마셜제도", "emoji": "🇲🇭",
	 "keyword": "환초의 고리", "tagline": "환초의 고리", "duration_sec": 8100, "fast_sec": 25},
	{"id": "cookislands_x", "chapter": "world", "region": "oceania", "name": "니우에", "emoji": "🇳🇺",
	 "keyword": "산호로 된 섬", "tagline": "산호로 된 섬", "duration_sec": 9000, "fast_sec": 26},

	# ── 3막 우주 (해왕성에서 태양까지) ──
	{"id": "neptune", "chapter": "space", "name": "해왕성", "emoji": "🔵",
	 "tagline": "가장 먼 바깥에서부터", "duration_sec": 21600, "fast_sec": 40},
	{"id": "uranus", "chapter": "space", "name": "천왕성", "emoji": "🩵",
	 "tagline": "옆으로 누워 도는 별", "duration_sec": 23400, "fast_sec": 43},
	{"id": "saturn", "chapter": "space", "name": "토성", "emoji": "🪐",
	 "tagline": "고리 위를 걷는 기분", "duration_sec": 25200, "fast_sec": 46},
	{"id": "jupiter", "chapter": "space", "name": "목성", "emoji": "🟠",
	 "tagline": "줄무늬가 흐르는 거인", "duration_sec": 27000, "fast_sec": 49},
	{"id": "asteroid", "chapter": "space", "name": "소행성대", "emoji": "☄",
	 "tagline": "돌들이 떠다니는 길", "duration_sec": 28800, "fast_sec": 52},
	{"id": "mars", "chapter": "space", "name": "화성", "emoji": "🔴",
	 "tagline": "붉은 모래 위 두 줄 발자국", "duration_sec": 30600, "fast_sec": 55},
	{"id": "moon", "chapter": "space", "name": "달", "emoji": "🌙",
	 "tagline": "둘만 아는 조용한 곳", "duration_sec": 32400, "fast_sec": 58},
	{"id": "venus", "chapter": "space", "name": "금성", "emoji": "🟡",
	 "tagline": "두꺼운 구름 아래", "duration_sec": 34200, "fast_sec": 61},
	{"id": "mercury", "chapter": "space", "name": "수성", "emoji": "⚪",
	 "tagline": "해와 가장 가까운 곳", "duration_sec": 36000, "fast_sec": 64},
	{"id": "sun", "chapter": "space", "name": "태양", "emoji": "☀",
	 "tagline": "여기서 더는 갈 수 없다", "duration_sec": 43200, "fast_sec": 67},

	# ── 엔딩 ──
	{"id": "rift", "chapter": "beyond", "name": "다른 차원", "emoji": "✨",
	 "tagline": "여기서부터는 지도가 없다", "duration_sec": 86400, "fast_sec": 70, "final": true},
]

## 실제 적용될 소요 시간
func duration_of(d: Dictionary) -> int:
	return int(d.get("fast_sec", 20)) if _is_fast() else int(d.get("duration_sec", 1800))

## 막·해금 관련 함수는 collection 이 필요해 get_destination 뒤에 있다.

## 여행 중 애인이 보내오는 중간 소식.
##   at = 여행 진행률(0.0~1.0). 그 지점을 지나면 도착한다.
## 실제 시각 기준이라 앱을 꺼둔 사이에도 도착해 있다.
const MID_MESSAGES: Dictionary = {
	"seoul": [
		{"at": 0.35, "emoji": "🐈", "text": "지금 골목길 지나는 중이야.\n여기 고양이가 엄청 많아!"},
		{"at": 0.70, "emoji": "🌆", "text": "해가 지고 있어.\n너도 이거 봤으면 좋겠다."}],
	"busan": [
		{"at": 0.35, "emoji": "⛰", "text": "계단이 끝이 없어.\n근데 위에서 보는 바다가 진짜 좋아."},
		{"at": 0.70, "emoji": "🍢", "text": "시장에서 뭐 좀 샀어.\n돌아가서 같이 먹자."}],
	"jeju": [
		{"at": 0.35, "emoji": "🌬", "text": "바람이 진짜 세.\n모자 날아갈 뻔했어."},
		{"at": 0.70, "emoji": "🍊", "text": "귤을 하나 땄는데\n생각보다 훨씬 달아."}],
	"gangneung": [
		{"at": 0.35, "emoji": "🚃", "text": "기차 창밖으로\n바다가 계속 따라와."},
		{"at": 0.70, "emoji": "🌅", "text": "내일 해 뜨는 거 보려고\n일찍 자기로 했어."}],
	"kyoto": [
		{"at": 0.35, "emoji": "🎋", "text": "대나무가 너무 높아서\n하늘이 초록색이야."},
		{"at": 0.70, "emoji": "🏮", "text": "등불이 하나씩 켜지고 있어.\n조용하고 좋다."}],
	"paris": [
		{"at": 0.35, "emoji": "🥐", "text": "빵집 앞을 지났는데\n냄새가 너무 좋아서 한참 서 있었어."},
		{"at": 0.70, "emoji": "🗼", "text": "탑이 보이기 시작했어.\n생각보다 훨씬 커."}],
	"newyork": [
		{"at": 0.35, "emoji": "🏙", "text": "건물이 너무 높아서\n고개가 아파."},
		{"at": 0.70, "emoji": "🌃", "text": "밤인데도 대낮처럼 밝아.\n좀 신기해."}],
	"cairo": [
		{"at": 0.35, "emoji": "🐫", "text": "낙타를 탔는데\n생각보다 많이 흔들려."},
		{"at": 0.70, "emoji": "✨", "text": "해가 지니까 갑자기 추워.\n대신 별이 엄청나."}],
	"moon": [
		{"at": 0.35, "emoji": "🌌", "text": "중력이 약해서\n자꾸 웃음이 나."},
		{"at": 0.70, "emoji": "🌍", "text": "저기 파란 점이 지구래.\n우리 집도 저 안에 있대."}],
	"mars": [
		{"at": 0.35, "emoji": "🔴", "text": "온통 붉어서\n노을 속을 걷는 것 같아."},
		{"at": 0.70, "emoji": "🌗", "text": "달이 두 개야.\n사진으로는 잘 안 담기네."}],
	"saturn": [
		{"at": 0.35, "emoji": "🪐", "text": "고리가 생각보다 얇아.\n근데 끝이 안 보여."},
		{"at": 0.70, "emoji": "☀", "text": "해가 작은 점처럼 보여.\n그래도 안 무서워."}],
	"rift": [
		{"at": 0.30, "emoji": "🌀", "text": "여기는 위아래가 없어.\n근데 손은 계속 잡고 있어."},
		{"at": 0.65, "emoji": "✨", "text": "돌아가는 길은 안 보여.\n괜찮아, 같이 있잖아."}],
}

## 여행지별 기념품(사진 + 일기). 방문할 때마다 순서대로 하나씩 열린다.
const SOUVENIRS: Dictionary = {
	"seoul": [
		{"title": "[ 첫 골목 ]", "diary": "늘 지나치던 길인데\n오늘은 손을 잡고 걸었다.", "photo": "🏯"},
		{"title": "[ 한강의 오후 ]", "diary": "바람이 좋아서\n아무 말도 하지 않았다.", "photo": "🌊"},
		{"title": "[ 야경 ]", "diary": "불빛이 예쁘다고 했더니\n네가 나를 봤다.", "photo": "🌃"}],
	"busan": [
		{"title": "[ 언덕 위 집들 ]", "diary": "계단이 끝없이 이어져서\n둘 다 숨이 찼다.", "photo": "🏘"},
		{"title": "[ 파도 소리 ]", "diary": "밤바다는 보이지 않고\n소리만 들렸다.", "photo": "🌊"},
		{"title": "[ 시장의 김 ]", "diary": "뜨거운 걸 호호 불면서\n반씩 나눠 먹었다.", "photo": "🍜"}],
	"jeju": [
		{"title": "[ 돌담길 ]", "diary": "바람이 세서\n자꾸 붙어 걸었다.", "photo": "🌾"},
		{"title": "[ 귤밭 ]", "diary": "하나 따서 까줬더니\n웃었다.", "photo": "🍊"},
		{"title": "[ 검은 모래 ]", "diary": "발자국이 선명하게 남는다고\n한참 들여다봤다.", "photo": "🏖"}],
	"gangneung": [
		{"title": "[ 첫 해 ]", "diary": "해가 올라오는 동안\n아무도 말하지 않았다.", "photo": "🌅"},
		{"title": "[ 바다 옆 커피 ]", "diary": "잔이 식는 줄도 모르고\n오래 앉아 있었다.", "photo": "☕"},
		{"title": "[ 돌아오는 기차 ]", "diary": "창밖을 보다가\n어깨에 기대 잠들었다.", "photo": "🚃"}],
	"kyoto": [
		{"title": "[ 대나무 길 ]", "diary": "위를 올려다보니\n초록빛만 가득했다.", "photo": "🎋"},
		{"title": "[ 붉은 문 ]", "diary": "끝이 안 보이는 길을\n천천히 걸었다.", "photo": "⛩"},
		{"title": "[ 저녁 골목 ]", "diary": "등불이 하나씩 켜지는 걸\n서서 지켜봤다.", "photo": "🏮"}],
	"paris": [
		{"title": "[ 낯선 아침 ]", "diary": "빵 냄새로 눈을 떴다.\n여기가 어디든 좋았다.", "photo": "🥐"},
		{"title": "[ 탑 아래에서 ]", "diary": "고개를 한참 젖히고\n둘 다 아무 말도 못 했다.", "photo": "🗼"},
		{"title": "[ 비 오는 골목 ]", "diary": "우산이 하나뿐이라\n조금 더 붙어 걸었다.", "photo": "☔"}],
	"newyork": [
		{"title": "[ 올려다본 하늘 ]", "diary": "건물 사이로 난 하늘이\n생각보다 좁았다.", "photo": "🏙"},
		{"title": "[ 공원의 벤치 ]", "diary": "복잡한 도시 한가운데\n이렇게 조용한 곳이 있었다.", "photo": "🌳"},
		{"title": "[ 밤의 불빛 ]", "diary": "잠들지 않는 도시라더니\n정말 그랬다.", "photo": "🌆"}],
	"cairo": [
		{"title": "[ 사막의 밤 ]", "diary": "생각보다 추워서\n둘이 붙어 있었다.", "photo": "🏜"},
		{"title": "[ 오래된 돌 ]", "diary": "몇천 년 전에도\n누가 여기 서 있었을까.", "photo": "🔺"},
		{"title": "[ 별이 쏟아지는 ]", "diary": "이렇게 많은 별은\n처음 봤다.", "photo": "✨"}],
	"moon": [
		{"title": "[ 조용한 곳 ]", "diary": "소리가 하나도 없어서\n숨소리가 다 들렸다.", "photo": "🌙"},
		{"title": "[ 지구를 보다 ]", "diary": "저기 어딘가에\n우리 집이 있다고 했다.", "photo": "🌍"},
		{"title": "[ 발자국 ]", "diary": "나란히 찍힌 두 개의 발자국.\n지워지지 않는다고 했다.", "photo": "👣"}],
	"mars": [
		{"title": "[ 붉은 모래 ]", "diary": "온통 붉어서\n노을이 끝나지 않는 것 같았다.", "photo": "🔴"},
		{"title": "[ 마른 강바닥 ]", "diary": "예전엔 물이 흘렀대.\n여기도 누군가 살았을까.", "photo": "🏜"},
		{"title": "[ 두 개의 달 ]", "diary": "달이 두 개나 떠서\n한참 세어 봤다.", "photo": "🌗"}],
	"saturn": [
		{"title": "[ 고리 위에서 ]", "diary": "얼음 조각들이\n천천히 같이 돌고 있었다.", "photo": "🪐"},
		{"title": "[ 끝없는 폭풍 ]", "diary": "무서울 줄 알았는데\n이상하게 조용했다.", "photo": "🌀"},
		{"title": "[ 멀어진 해 ]", "diary": "해가 작은 점처럼 보였다.\n그래도 따뜻했다.", "photo": "☀"}],
	"rift": [
		{"title": "[ 지도의 끝 ]", "diary": "여기서부터는 아무도 가 본 적이 없대.\n그래서 같이 가기로 했다.", "photo": "✨"}],
}

## 진행 중인 여행 (없으면 빈 Dictionary)
var trip: Dictionary = {}
## 모은 기념품들 (앨범)
var collection: Array = []

# ── 조회 ────────────────────────────────────────────────────────────────

func get_destination(dest_id: String) -> Dictionary:
	for d in DESTINATIONS:
		if d.id == dest_id:
			return d
	return {}

## 어느 막에서 몇 곳을 다녀왔는가 (같은 곳 여러 번은 1로 센다)
func chapter_cleared(chapter_id: String) -> int:
	var seen := {}
	for sv in collection:
		var d: Dictionary = get_destination(str(sv.get("dest_id", "")))
		if not d.is_empty() and str(d.get("chapter", "")) == chapter_id:
			seen[d.id] = true
	return seen.size()

func get_chapter(chapter_id: String) -> Dictionary:
	for c in CHAPTERS:
		if c.id == chapter_id:
			return c
	return {}

func chapter_index(chapter_id: String) -> int:
	for i in range(CHAPTERS.size()):
		if CHAPTERS[i].id == chapter_id:
			return i
	return -1

## 그 막이 열렸는가 (앞 막을 정해진 곳 수만큼 다녀왔는가)
func is_chapter_unlocked(chapter_id: String) -> bool:
	var idx := chapter_index(chapter_id)
	if idx <= 0:
		return true
	var prev: Dictionary = CHAPTERS[idx - 1]
	var need: int = int(CHAPTERS[idx].get("need_prev", 3))
	return chapter_cleared(str(prev.id)) >= need

## 여행지 해금 여부
func is_unlocked(dest_id: String) -> bool:
	var d: Dictionary = get_destination(dest_id)
	if d.is_empty():
		return false
	if not is_chapter_unlocked(str(d.get("chapter", ""))):
		return false
	# 엔딩 여행지는 한 번만 갈 수 있다
	if bool(d.get("final", false)) and ending_reached():
		return false
	return true

## 해금까지 무엇이 남았는지
func unlock_hint(dest_id: String) -> String:
	var d: Dictionary = get_destination(dest_id)
	if d.is_empty() or is_unlocked(dest_id):
		return ""
	if bool(d.get("final", false)) and ending_reached():
		return "이미 다녀왔어요"
	var idx := chapter_index(str(d.get("chapter", "")))
	if idx <= 0:
		return ""
	var prev: Dictionary = CHAPTERS[idx - 1]
	var need: int = int(CHAPTERS[idx].get("need_prev", 3))
	var have := chapter_cleared(str(prev.id))
	return "%s 여행지 %d곳을 더 다녀오면 열려요" % [prev.name, maxi(0, need - have)]

## 엔딩(다른 차원)에 다녀왔는가
func ending_reached() -> bool:
	for sv in collection:
		var d: Dictionary = get_destination(str(sv.get("dest_id", "")))
		if not d.is_empty() and bool(d.get("final", false)):
			return true
	return false

func is_traveling() -> bool:
	return not trip.is_empty() and not has_arrived()

func has_arrived() -> bool:
	if trip.is_empty():
		return false
	return _now() >= int(trip.get("arrive_at", 0))

func seconds_left() -> int:
	if trip.is_empty():
		return 0
	return maxi(0, int(trip.get("arrive_at", 0)) - _now())

## 0.0 ~ 1.0 진행률
func progress() -> float:
	if trip.is_empty():
		return 0.0
	var total := int(trip.get("arrive_at", 0)) - int(trip.get("depart_at", 0))
	if total <= 0:
		return 1.0
	return clampf(float(_now() - int(trip.get("depart_at", 0))) / float(total), 0.0, 1.0)

func visit_count(dest_id: String) -> int:
	var n := 0
	for s in collection:
		if s.get("dest_id", "") == dest_id:
			n += 1
	return n

# ── 여행 중 중간 소식 ──

## 지금까지 도착한 소식 (진행률 기준)
func arrived_messages() -> Array:
	if trip.is_empty():
		return []
	var dest_id: String = str(trip.get("dest_id", ""))
	var pool: Array = MID_MESSAGES.get(dest_id, [])
	if pool.is_empty():
		pool = _auto_messages(get_destination(dest_id))
	var prog := progress()
	var out: Array = []
	for i in range(pool.size()):
		if prog >= float(pool[i].get("at", 1.0)):
			var m: Dictionary = (pool[i] as Dictionary).duplicate(true)
			m["index"] = i
			out.append(m)
	return out

## 아직 읽지 않은 소식
func unread_messages() -> Array:
	var read: Array = trip.get("read_msgs", [])
	var out: Array = []
	for m in arrived_messages():
		if not read.has(int(m.get("index", -1))):
			out.append(m)
	return out

func unread_count() -> int:
	return unread_messages().size()

## 소식을 읽음 처리한다
func mark_messages_read() -> void:
	if trip.is_empty():
		return
	var read: Array = trip.get("read_msgs", [])
	for m in arrived_messages():
		var i := int(m.get("index", -1))
		if i >= 0 and not read.has(i):
			read.append(i)
	trip["read_msgs"] = read
	SaveManager.save_game()

## 다음 소식까지 남은 시간(초). 없으면 -1
func seconds_to_next_message() -> int:
	if trip.is_empty():
		return -1
	var dest_id2: String = str(trip.get("dest_id", ""))
	var pool: Array = MID_MESSAGES.get(dest_id2, [])
	if pool.is_empty():
		pool = _auto_messages(get_destination(dest_id2))
	var total := int(trip.get("arrive_at", 0)) - int(trip.get("depart_at", 0))
	if total <= 0:
		return -1
	var prog := progress()
	for m in pool:
		var at := float(m.get("at", 1.0))
		if prog < at:
			return int((at - prog) * float(total))
	return -1

func format_time_left() -> String:
	var s := seconds_left()
	if s <= 0:
		return "도착!"
	var m := s / 60
	var sec := s % 60
	if m >= 60:
		return "%d시간 %d분" % [m / 60, m % 60]
	if m > 0:
		return "%d분 %d초" % [m, sec]
	return "%d초" % sec

# ── 코어 루프 ────────────────────────────────────────────────────────────

## 1단계: 여행 보내기
func start_trip(dest_id: String) -> bool:
	if is_traveling() or has_arrived():
		return false
	var d := get_destination(dest_id)
	if d.is_empty():
		return false
	if not is_unlocked(dest_id):
		return false
	var now := _now()
	trip = {
		"dest_id": dest_id,
		"depart_at": now,
		"arrive_at": now + duration_of(d),
		"read_msgs": [],
	}
	trip_started.emit(dest_id)
	SaveManager.save_game()
	return true

## 2단계: (앱을 꺼도 시간이 흐름 — 별도 처리 불필요)

## 3단계: 돌아온 쿼카들에게서 사진과 일기를 받는다
func collect_arrival() -> Dictionary:
	if not has_arrived():
		return {}
	var dest_id: String = trip.get("dest_id", "")
	var souvenir := _pick_souvenir(dest_id)
	souvenir["dest_id"] = dest_id
	souvenir["collected_at"] = _now()
	# 0편에서 챙긴 물건에 따라 기록의 내용이 달라진다
	if not _has_item("camera"):
		souvenir["photo"] = "📭"
		souvenir["title"] = "[ 사진 없음 ]"
	if not _has_item("notebook"):
		souvenir["diary"] = "적어둘 수첩이 없어서\n기억으로만 남았다."
	collection.append(souvenir)
	trip = {}
	souvenir_collected.emit(souvenir)
	SaveManager.save_game()
	return souvenir

## 0편에서 챙긴 물건이 여행 기록에 반영된다.
##   카메라 없으면 사진이 없고, 수첩 없으면 일기가 없다.
func _has_item(item: String) -> bool:
	var st := get_node_or_null("/root/Episode0State")
	if st == null:
		return true   # 0편을 건너뛴 경우엔 제한하지 않는다
	match item:
		"camera": return st.has_camera
		"notebook": return st.has_notebook
		"bag": return st.has_travel_bag
	return true

## 손으로 쓴 기념품이 없는 곳은 그곳의 특징으로 문장을 만든다.
## 225곳을 전부 손으로 쓸 수 없으므로, 여행지마다 다른 결과가 나오도록 조합한다.
const AUTO_TITLES := ["[ %s ]", "[ %s 앞에서 ]", "[ %s의 하루 ]"]


## 받침에 맞는 조사를 고른다.
##
## "%s(을)를" 같은 표기를 그대로 화면에 내보내고 있었다. 손으로 쓴 여행지는
## 몇 곳뿐이고 나머지 200곳 넘게가 이 문장을 쓰므로, 대부분의 플레이어가
## 괄호를 본다는 뜻이었다.
##
## 한글 음절은 유니코드에서 (초성, 중성, 종성) 순서로 배열돼 있어서
## (코드 - 0xAC00) % 28 이 0 이면 받침이 없다.
static func _josa(word: String, with_final: String, without_final: String) -> String:
	if word.is_empty():
		return without_final
	var c := word.strip_edges().unicode_at(word.strip_edges().length() - 1)
	# 한글이 아니면(숫자·라틴 문자) 받침 유무를 알 수 없다. 흔한 쪽으로 둔다.
	if c < 0xAC00 or c > 0xD7A3:
		return without_final
	return with_final if (c - 0xAC00) % 28 != 0 else without_final


## 문장 안의 조사 표기를 실제 조사로 바꾼다. "%s" 가 이미 채워진 뒤에 부른다.
static func fix_josa(text: String) -> String:
	var out := text
	for pair in [["(을)를", "을", "를"], ["(이)가", "이", "가"],
			["(은)는", "은", "는"], ["(과)와", "과", "와"], ["(으)로", "으로", "로"]]:
		while true:
			var i: int = out.find(pair[0])
			if i < 0:
				break
			out = out.substr(0, i) + _josa(out.substr(0, i), pair[1], pair[2]) \
				+ out.substr(i + pair[0].length())
	return out
const AUTO_DIARIES := [
	"%s(을)를 보고\n한참 아무 말도 안 했다.",
	"%s(이)가 있는 곳까지\n손을 잡고 걸었다.",
	"%s 앞에서\n사진을 한 장 찍었다.",
	"%s(을)를 보니\n여기까지 온 게 실감났다.",
	"%s(이)가 오래 기억날 것 같다고\n네가 말했다.",
	"%s 옆에 앉아\n숨을 골랐다.",
]
const AUTO_MSGS := [
	"지금 %s 근처야.\n생각보다 훨씬 좋다.",
	"%s(을)를 보고 있어.\n너도 봤으면 좋겠어.",
	"여기 %s(이)가 유명하대.\n와보길 잘했어.",
	"%s 앞에서 좀 쉬는 중이야.\n곧 또 소식 보낼게.",
]

## 아무 일도 없던 날. 매번 사진이 나오면 사진이 특별하지 않다.
## 약 22% 확률로 조용한 하루가 온다. 그래야 다음 사진이 반갑다.
const QUIET_DAYS := [
	"오늘은 그냥 걸었다.",
	"특별한 건 없었지만\n나쁘지 않은 하루였다.",
	"사진을 찍는 걸 잊었다.\n그만큼 좋았다는 뜻이겠지.",
	"아무 말 없이\n오래 앉아 있었다.",
	"오늘은 아무것도 하지 않기로 했다.",
	"길을 잃었는데\n둘 다 웃었다.",
]

func _is_quiet_day(dest_id: String, idx: int) -> bool:
	return abs(hash(dest_id + "quiet" + str(idx))) % 100 < 22

func _quiet_souvenir(d: Dictionary, idx: int) -> Dictionary:
	var h: int = abs(hash(str(d.get("id", "")) + "q" + str(idx)))
	return {
		"title": "[ 조용한 하루 ]",
		"diary": QUIET_DAYS[h % QUIET_DAYS.size()],
		"photo": "·",
		"quiet": true,
	}

func _auto_souvenir(d: Dictionary, idx: int) -> Dictionary:
	var kw: String = str(d.get("keyword", d.get("tagline", "이곳")))
	var h: int = abs(hash(str(d.get("id", "")) + str(idx)))
	return {
		"title": AUTO_TITLES[h % AUTO_TITLES.size()] % kw,
		"diary": fix_josa(AUTO_DIARIES[(h / 7) % AUTO_DIARIES.size()] % kw),
		"photo": str(d.get("emoji", "📷")),
	}

## 손으로 쓴 소식이 없는 곳도 마찬가지로 만든다
func _auto_messages(d: Dictionary) -> Array:
	var kw: String = str(d.get("keyword", d.get("tagline", "이곳")))
	var h: int = abs(hash(str(d.get("id", ""))))
	return [
		{"at": 0.35, "emoji": str(d.get("emoji", "💌")),
		 "text": fix_josa(AUTO_MSGS[h % AUTO_MSGS.size()] % kw)},
		{"at": 0.70, "emoji": "✉",
		 "text": fix_josa(AUTO_MSGS[(h / 5) % AUTO_MSGS.size()] % kw)},
	]

func _pick_souvenir(dest_id: String) -> Dictionary:
	var pool: Array = SOUVENIRS.get(dest_id, [])
	if pool.is_empty():
		# 손으로 쓴 게 없으면 그곳의 특징으로 만든다 (방문할수록 다른 기록)
		var d: Dictionary = get_destination(dest_id)
		if d.is_empty():
			return {"title": "[ 기록 ]", "diary": "무언가를 보고 왔다.", "photo": "📷"}
		var vi := visit_count(dest_id)
		if _is_quiet_day(dest_id, vi):
			return _quiet_souvenir(d, vi)
		return _auto_souvenir(d, vi)
	var vcount := visit_count(dest_id)
	# 손으로 쓴 곳도 가끔은 아무 일 없는 날
	if vcount >= pool.size() and _is_quiet_day(dest_id, vcount):
		return _quiet_souvenir(get_destination(dest_id), vcount)
	# 방문 횟수만큼 다음 것을 열고, 다 보면 순환한다
	var idx: int = vcount % pool.size()
	return (pool[idx] as Dictionary).duplicate(true)

# ── 저장 ────────────────────────────────────────────────────────────────

func reset() -> void:
	trip = {}
	collection = []

func to_dict() -> Dictionary:
	return {"trip": trip, "collection": collection}

func from_dict(d: Dictionary) -> void:
	trip = d.get("trip", {})
	collection = d.get("collection", [])

func _now() -> int:
	return int(Time.get_unix_time_from_system())

# ── 함께 배우는 것 ───────────────────────────────────────────────────────
# 수치(레벨·스탯)로 말하지 않기 위해, 여행하며 둘이 몸에 익히는 습관으로 표현한다.
# effect_hint 는 "무엇이 몇 % 오른다" 대신 체감으로만 알려준다.
const TRAVEL_HABITS: Array = [
	{"id": "slow_walk", "name": "천천히 걷기",
	 "desc": "서두르지 않아도 도착은 한다",
	 "effect_hint": "여행이 조금 짧게 느껴져요"},
	{"id": "get_lost", "name": "길 잃어도 괜찮기",
	 "desc": "예정에 없던 곳이 제일 기억에 남는다",
	 "effect_hint": "뜻밖의 소식이 자주 와요"},
	{"id": "photo_each_other", "name": "서로 사진 찍어주기",
	 "desc": "풍경보다 사람이 남는다",
	 "effect_hint": "둘이 함께 찍힌 사진이 늘어요"},
	{"id": "empty_day", "name": "아무 계획 없는 하루",
	 "desc": "비워둔 날이 여행을 살린다",
	 "effect_hint": "조용한 하루가 더 자주 와요"},
	{"id": "share_umbrella", "name": "우산 하나로 걷기",
	 "desc": "비 오는 날은 어깨가 조금 젖는다",
	 "effect_hint": "흐린 날에도 소식이 끊기지 않아요"},
	{"id": "morning_market", "name": "아침 시장 구경하기",
	 "desc": "사는 것보다 보는 게 더 재미있다",
	 "effect_hint": "작고 사소한 기념품이 늘어요"},
	{"id": "long_letter", "name": "긴 편지 쓰기",
	 "desc": "돌아가서 할 말을 미리 적어둔다",
	 "effect_hint": "일기가 조금 길어져요"},
	{"id": "come_back", "name": "좋았던 곳에 다시 가기",
	 "desc": "같은 곳도 두 번째는 다르게 보인다",
	 "effect_hint": "다시 간 곳에서 새 기록이 나와요"},
]

# 다녀온 곳 수에 맞춰 하나씩 열린다 (TRAVEL_HABITS 순서와 짝)
const HABIT_UNLOCK_AT: Array = [3, 6, 10, 15, 25, 40, 70, 120]

func habit_unlocked(habit_id: String) -> bool:
	for i in TRAVEL_HABITS.size():
		if str((TRAVEL_HABITS[i] as Dictionary).get("id", "")) == habit_id:
			if i >= HABIT_UNLOCK_AT.size():
				return false
			return collection.size() >= int(HABIT_UNLOCK_AT[i])
	return false

func unlocked_habits() -> Array:
	var out: Array = []
	for i in TRAVEL_HABITS.size():
		if i < HABIT_UNLOCK_AT.size() and collection.size() >= int(HABIT_UNLOCK_AT[i]):
			out.append((TRAVEL_HABITS[i] as Dictionary).duplicate(true))
	return out
