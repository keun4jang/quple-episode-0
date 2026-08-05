#!/usr/bin/env python3
"""여행지 테이블(GDScript) 생성. 국내 17 + 해외 192 + 우주 11 + 다른 차원 1."""
import pathlib

KOREA = [
    ("seoul","서울","🏯","골목마다 다른 얼굴을 한 도시",1800),
    ("busan","부산","🌊","바다 냄새가 나는 언덕길",2100),
    ("incheon","인천","✈","떠나는 사람과 돌아오는 사람",2400),
    ("daegu","대구","🍎","분지의 여름은 뜨겁고 정겹다",2400),
    ("gwangju","광주","🎨","골목에 그림이 걸린 도시",2700),
    ("daejeon","대전","🔬","조용하고 단정한 거리",2700),
    ("ulsan","울산","🐋","고래가 다니던 바다",3000),
    ("sejong","세종","🌳","새로 심은 나무가 많은 곳",3000),
    ("gyeonggi","경기","🚉","서울을 감싼 넓은 들",3300),
    ("gangwon","강원","⛰","산과 바다가 붙어 있는 곳",3600),
    ("chungbuk","충북","🍇","해가 잘 드는 언덕",3600),
    ("chungnam","충남","🌾","느리게 흐르는 강",3900),
    ("jeonbuk","전북","🍚","밥 냄새가 좋은 고장",3900),
    ("jeonnam","전남","🏝","섬이 별처럼 흩어진 바다",4200),
    ("gyeongbuk","경북","🏛","오래된 것이 그대로 남은 곳",4200),
    ("gyeongnam","경남","⚓","항구와 산이 이웃한 곳",4500),
    ("jeju","jeju_x","🍊","돌담 사이로 부는 바람",5400),
]
KOREA[-1] = ("jeju","제주","🍊","돌담 사이로 부는 바람",5400)

# (id, 한국어명, 국기, 대륙, 키워드)
WORLD = [
 # ── 아시아 ──
 ("japan","일본","🇯🇵","asia","조용한 골목"),("china","중국","🇨🇳","asia","끝없는 성벽"),
 ("mongolia","몽골","🇲🇳","asia","초원의 밤"),("taiwan_x","대만","🇹🇼","asia","야시장 불빛"),
 ("vietnam","베트남","🇻🇳","asia","오토바이 물결"),("thailand","태국","🇹🇭","asia","향신료 냄새"),
 ("laos","라오스","🇱🇦","asia","느린 강물"),("cambodia","캄보디아","🇰🇭","asia","돌에 새긴 얼굴"),
 ("myanmar","미얀마","🇲🇲","asia","금빛 탑"),("malaysia","말레이시아","🇲🇾","asia","쌍둥이 탑"),
 ("singapore","싱가포르","🇸🇬","asia","정원 같은 도시"),("indonesia","인도네시아","🇮🇩","asia","섬과 화산"),
 ("philippines","필리핀","🇵🇭","asia","투명한 바다"),("brunei","브루나이","🇧🇳","asia","물 위의 마을"),
 ("timor","동티모르","🇹🇱","asia","젊은 나라의 아침"),("india","인도","🇮🇳","asia","하얀 대리석"),
 ("nepal","네팔","🇳🇵","asia","설산의 능선"),("bhutan","부탄","🇧🇹","asia","골짜기의 절"),
 ("bangladesh","방글라데시","🇧🇩","asia","강이 많은 땅"),("srilanka","스리랑카","🇱🇰","asia","차밭의 초록"),
 ("maldives","몰디브","🇲🇻","asia","물 위의 오두막"),("pakistan","파키스탄","🇵🇰","asia","높은 고개"),
 ("afghanistan","아프가니스탄","🇦🇫","asia","마른 산맥"),("iran","이란","🇮🇷","asia","푸른 타일"),
 ("iraq","이라크","🇮🇶","asia","두 강 사이"),("syria","시리아","🇸🇾","asia","오래된 시장"),
 ("lebanon","레바논","🇱🇧","asia","삼나무 언덕"),("jordan","요르단","🇯🇴","asia","붉은 바위 도시"),
 ("israel","이스라엘","🇮🇱","asia","오래된 성벽"),("palestine_x","팔레스타인","🇵🇸","asia","올리브 나무"),
 ("saudi","사우디아라비아","🇸🇦","asia","사막의 밤"),("uae","아랍에미리트","🇦🇪","asia","유리로 된 도시"),
 ("qatar","카타르","🇶🇦","asia","바다 위 신도시"),("kuwait","쿠웨이트","🇰🇼","asia","만의 바람"),
 ("bahrain","바레인","🇧🇭","asia","진주의 섬"),("oman","오만","🇴🇲","asia","협곡의 물빛"),
 ("yemen","예멘","🇾🇪","asia","흙으로 지은 탑"),("turkey","튀르키예","🇹🇷","asia","두 대륙 사이"),
 ("georgia","조지아","🇬🇪","asia","포도밭 계곡"),("armenia","아르메니아","🇦🇲","asia","돌로 지은 교회"),
 ("azerbaijan","아제르바이잔","🇦🇿","asia","불의 언덕"),("kazakhstan","카자흐스탄","🇰🇿","asia","넓은 초원"),
 ("uzbekistan","우즈베키스탄","🇺🇿","asia","푸른 돔"),("turkmenistan","투르크메니스탄","🇹🇲","asia","불타는 구덩이"),
 ("kyrgyzstan","키르기스스탄","🇰🇬","asia","산 위의 호수"),("tajikistan","타지키스탄","🇹🇯","asia","높은 고원"),
 ("northkorea","조선","🇰🇵","asia","가까운 북쪽"),
 # ── 유럽 ──
 ("france","프랑스","🇫🇷","europe","빵 냄새와 탑"),("uk","영국","🇬🇧","europe","안개 낀 강"),
 ("ireland","아일랜드","🇮🇪","europe","초록 절벽"),("germany","독일","🇩🇪","europe","오래된 광장"),
 ("netherlands","네덜란드","🇳🇱","europe","운하와 자전거"),("belgium","벨기에","🇧🇪","europe","골목의 초콜릿"),
 ("luxembourg","룩셈부르크","🇱🇺","europe","성벽 위 산책"),("switzerland","스위스","🇨🇭","europe","눈 덮인 봉우리"),
 ("austria","오스트리아","🇦🇹","europe","음악이 흐르는 거리"),("italy","이탈리아","🇮🇹","europe","돌길과 분수"),
 ("spain","스페인","🇪🇸","europe","해가 긴 광장"),("portugal","포르투갈","🇵🇹","europe","파란 타일"),
 ("andorra","안도라","🇦🇩","europe","산속 작은 나라"),("monaco","모나코","🇲🇨","europe","바다 옆 절벽"),
 ("malta","몰타","🇲🇹","europe","꿀빛 돌담"),("sanmarino","산마리노","🇸🇲","europe","언덕 위 성"),
 ("vatican","바티칸","🇻🇦","europe","가장 작은 나라"),("greece","그리스","🇬🇷","europe","하얀 집과 파란 문"),
 ("cyprus","키프로스","🇨🇾","europe","지중해의 섬"),("denmark","덴마크","🇩🇰","europe","색색의 부두"),
 ("norway","노르웨이","🇳🇴","europe","깊은 피오르"),("sweden","스웨덴","🇸🇪","europe","숲과 호수"),
 ("finland","핀란드","🇫🇮","europe","오로라의 밤"),("iceland","아이슬란드","🇮🇸","europe","김이 나는 땅"),
 ("estonia","에스토니아","🇪🇪","europe","중세의 지붕"),("latvia","라트비아","🇱🇻","europe","호박의 해변"),
 ("lithuania","리투아니아","🇱🇹","europe","언덕의 십자가"),("poland","폴란드","🇵🇱","europe","광장의 종소리"),
 ("czech","체코","🇨🇿","europe","다리 위의 조각"),("slovakia","슬로바키아","🇸🇰","europe","성 아래 마을"),
 ("hungary","헝가리","🇭🇺","europe","강 위의 다리"),("romania","루마니아","🇷🇴","europe","숲속의 성"),
 ("bulgaria","불가리아","🇧🇬","europe","장미의 골짜기"),("serbia","세르비아","🇷🇸","europe","두 강의 만남"),
 ("croatia","크로아티아","🇭🇷","europe","주황 지붕과 바다"),("slovenia","슬로베니아","🇸🇮","europe","호수 위 섬"),
 ("bosnia","보스니아","🇧🇦","europe","돌다리"),("montenegro","몬테네그로","🇲🇪","europe","검은 산"),
 ("northmacedonia","북마케도니아","🇲🇰","europe","오래된 호수"),("albania","알바니아","🇦🇱","europe","산과 해안"),
 ("kosovo_x","코소보","🇽🇰","europe","젊은 도시"),("moldova","몰도바","🇲🇩","europe","땅속 포도주"),
 ("ukraine","우크라이나","🇺🇦","europe","넓은 밀밭"),("belarus","벨라루스","🇧🇾","europe","자작나무 숲"),
 ("russia","러시아","🇷🇺","europe","끝없는 기차"),("liechtenstein","리히텐슈타인","🇱🇮","europe","알프스의 공국"),
 # ── 아프리카 ──
 ("egypt","이집트","🇪🇬","africa","사막의 삼각형"),("morocco","모로코","🇲🇦","africa","파란 골목"),
 ("algeria","알제리","🇩🇿","africa","사하라의 문"),("tunisia","튀니지","🇹🇳","africa","하얀 언덕마을"),
 ("libya","리비아","🇱🇾","africa","해안의 유적"),("sudan","수단","🇸🇩","africa","작은 피라미드"),
 ("southsudan","남수단","🇸🇸","africa","젊은 강"),("ethiopia","에티오피아","🇪🇹","africa","바위를 판 교회"),
 ("eritrea","에리트레아","🇪🇷","africa","붉은 바다"),("djibouti","지부티","🇩🇯","africa","소금 호수"),
 ("somalia","소말리아","🇸🇴","africa","긴 해안선"),("kenya","케냐","🇰🇪","africa","초원의 무리"),
 ("uganda","우간다","🇺🇬","africa","나일의 시작"),("rwanda","르완다","🇷🇼","africa","천 개의 언덕"),
 ("burundi","부룬디","🇧🇮","africa","호수의 나라"),("tanzania","탄자니아","🇹🇿","africa","눈 덮인 적도"),
 ("nigeria","나이지리아","🇳🇬","africa","북적이는 거리"),("ghana","가나","🇬🇭","africa","황금 해안"),
 ("senegal","세네갈","🇸🇳","africa","분홍 호수"),("mali","말리","🇲🇱","africa","흙으로 지은 도서관"),
 ("burkina","부르키나파소","🇧🇫","africa","붉은 흙길"),("niger","니제르","🇳🇪","africa","사막의 강"),
 ("chad","차드","🇹🇩","africa","사라지는 호수"),("cameroon","카메룬","🇨🇲","africa","작은 아프리카"),
 ("car","중앙아프리카공화국","🇨🇫","africa","깊은 숲"),("gabon","가봉","🇬🇦","africa","해변의 코끼리"),
 ("congo","콩고","🇨🇬","africa","큰 강"),("drcongo","콩고민주공화국","🇨🇩","africa","밀림의 심장"),
 ("angola","앙골라","🇦🇴","africa","대서양의 절벽"),("zambia","잠비아","🇿🇲","africa","천둥 치는 연기"),
 ("zimbabwe","짐바브웨","🇿🇼","africa","돌로 쌓은 도시"),("malawi","말라위","🇲🇼","africa","별이 비치는 호수"),
 ("mozambique","모잠비크","🇲🇿","africa","산호의 해안"),("botswana","보츠와나","🇧🇼","africa","물이 고인 사막"),
 ("namibia","나미비아","🇳🇦","africa","붉은 모래언덕"),("southafrica","남아프리카공화국","🇿🇦","africa","두 바다가 만나는 곶"),
 ("lesotho","레소토","🇱🇸","africa","하늘 위 왕국"),("eswatini","에스와티니","🇸🇿","africa","골짜기의 왕국"),
 ("madagascar","마다가스카르","🇲🇬","africa","바오밥 길"),("mauritius","모리셔스","🇲🇺","africa","산호초의 섬"),
 ("seychelles","세이셸","🇸🇨","africa","화강암 해변"),("comoros","코모로","🇰🇲","africa","향기의 섬"),
 ("capeverde","카보베르데","🇨🇻","africa","대서양의 화산섬"),("guineabissau","기니비사우","🇬🇼","africa","맹그로브 강"),
 ("guinea","기니","🇬🇳","africa","물의 성"),("sierraleone","시에라리온","🇸🇱","africa","사자의 산"),
 ("liberia","라이베리아","🇱🇷","africa","비가 많은 해안"),("ivorycoast","코트디부아르","🇨🇮","africa","석호의 도시"),
 ("togo","토고","🇹🇬","africa","좁고 긴 나라"),("benin","베냉","🇧🇯","africa","물 위의 마을"),
 ("gambia","감비아","🇬🇲","africa","강을 따라"),("mauritania","모리타니","🇲🇷","africa","사막의 기차"),
 ("saotome","상투메프린시페","🇸🇹","africa","초콜릿 섬"),("equatorialguinea","적도기니","🇬🇶","africa","적도의 만"),
 # ── 북아메리카 ──
 ("usa","미국","🇺🇸","america","잠들지 않는 불빛"),("canada","캐나다","🇨🇦","america","단풍과 호수"),
 ("mexico","멕시코","🇲🇽","america","색이 진한 골목"),("guatemala","과테말라","🇬🇹","america","호수와 화산"),
 ("belize","벨리즈","🇧🇿","america","푸른 구멍"),("honduras","온두라스","🇭🇳","america","마야의 계단"),
 ("elsalvador","엘살바도르","🇸🇻","america","화산의 나라"),("nicaragua","니카라과","🇳🇮","america","호수 속 화산"),
 ("costarica","코스타리카","🇨🇷","america","구름 숲"),("panama","파나마","🇵🇦","america","두 바다를 잇는 길"),
 ("cuba","쿠바","🇨🇺","america","오래된 자동차"),("jamaica","자메이카","🇯🇲","america","박자가 느린 섬"),
 ("haiti","아이티","🇭🇹","america","산이 많은 땅"),("dominicanrep","도미니카공화국","🇩🇴","america","야자수 해변"),
 ("bahamas","바하마","🇧🇸","america","얕고 맑은 바다"),("barbados","바베이도스","🇧🇧","america","분홍 모래"),
 ("trinidad","트리니다드토바고","🇹🇹","america","축제의 섬"),("grenada","그레나다","🇬🇩","america","향신료의 섬"),
 ("stlucia","세인트루시아","🇱🇨","america","두 개의 봉우리"),("stvincent","세인트빈센트그레나딘","🇻🇨","america","작은 섬들"),
 ("antigua","앤티가바부다","🇦🇬","america","해변이 365개"),("dominica","도미니카연방","🇩🇲","america","끓는 호수"),
 ("stkitts","세인트키츠네비스","🇰🇳","america","사탕수수 철길"),
 # ── 남아메리카 ──
 ("brazil","브라질","🇧🇷","america","거대한 강과 숲"),("argentina","아르헨티나","🇦🇷","america","끝없는 초원"),
 ("chile","칠레","🇨🇱","america","가장 긴 나라"),("peru","페루","🇵🇪","america","구름 위 도시"),
 ("bolivia","볼리비아","🇧🇴","america","하늘이 비치는 소금밭"),("colombia","콜롬비아","🇨🇴","america","커피 언덕"),
 ("venezuela","베네수엘라","🇻🇪","america","하늘에서 떨어지는 물"),("ecuador","에콰도르","🇪🇨","america","적도의 한가운데"),
 ("paraguay","파라과이","🇵🇾","america","붉은 흙과 강"),("uruguay","우루과이","🇺🇾","america","조용한 해안 도시"),
 ("guyana","가이아나","🇬🇾","america","밀림의 폭포"),("suriname","수리남","🇸🇷","america","나무로 지은 도시"),
 # ── 오세아니아 ──
 ("australia","호주","🇦🇺","oceania","쿼카가 사는 섬"),("newzealand","뉴질랜드","🇳🇿","oceania","초록 언덕과 양"),
 ("fiji","피지","🇫🇯","oceania","따뜻한 산호 바다"),("papua","파푸아뉴기니","🇵🇬","oceania","깊은 숲의 새"),
 ("solomon","솔로몬제도","🇸🇧","oceania","흩어진 섬들"),("vanuatu","바누아투","🇻🇺","oceania","활화산의 섬"),
 ("samoa","사모아","🇼🇸","oceania","야자수 그늘"),("tonga","통가","🇹🇴","oceania","고래가 오는 바다"),
 ("kiribati","키리바시","🇰🇮","oceania","날짜가 시작되는 곳"),("tuvalu","투발루","🇹🇻","oceania","낮고 작은 섬"),
 ("nauru","나우루","🇳🇷","oceania","가장 작은 공화국"),("palau","팔라우","🇵🇼","oceania","해파리 호수"),
 ("micronesia","미크로네시아","🇫🇲","oceania","돌 화폐의 섬"),("marshall","마셜제도","🇲🇭","oceania","환초의 고리"),
 ("cookislands_x","니우에","🇳🇺","oceania","산호로 된 섬"),
]

SPACE = [
 ("neptune","해왕성","🔵","가장 먼 바깥에서부터",21600),
 ("uranus","천왕성","🩵","옆으로 누워 도는 별",23400),
 ("saturn","토성","🪐","고리 위를 걷는 기분",25200),
 ("jupiter","목성","🟠","줄무늬가 흐르는 거인",27000),
 ("asteroid","소행성대","☄","돌들이 떠다니는 길",28800),
 ("mars","화성","🔴","붉은 모래 위 두 줄 발자국",30600),
 ("moon","달","🌙","둘만 아는 조용한 곳",32400),
 ("venus","금성","🟡","두꺼운 구름 아래",34200),
 ("mercury","수성","⚪","해와 가장 가까운 곳",36000),
 ("sun","태양","☀","여기서 더는 갈 수 없다",43200),
]

def esc(s): return s.replace('"', '\\"')

out = []
out.append("## 자동 생성 — tools/travel/gen_destinations.py")
out.append("## 국내 %d · 해외 %d · 우주 %d · 다른 차원 1" % (len(KOREA), len(WORLD), len(SPACE)))
out.append("const DESTINATIONS: Array[Dictionary] = [")
out.append("\t# ── 1막 국내 ──")
for i,(id_,name,emo,tag,dur) in enumerate(KOREA):
    fast = 18 + i
    out.append('\t{"id": "%s", "chapter": "korea", "name": "%s", "emoji": "%s",' % (id_, name, emo))
    out.append('\t "tagline": "%s", "duration_sec": %d, "fast_sec": %d},' % (esc(tag), dur, fast))
out.append("")
out.append("\t# ── 2막 해외 ──")
for i,(id_,name,flag,cont,kw) in enumerate(WORLD):
    dur = 5400 + (i % 12) * 900
    fast = 20 + (i % 10)
    out.append('\t{"id": "%s", "chapter": "world", "region": "%s", "name": "%s", "emoji": "%s",' % (id_, cont, name, flag))
    out.append('\t "keyword": "%s", "tagline": "%s", "duration_sec": %d, "fast_sec": %d},' % (esc(kw), esc(kw), dur, fast))
out.append("")
out.append("\t# ── 3막 우주 (해왕성에서 태양까지) ──")
for i,(id_,name,emo,tag,dur) in enumerate(SPACE):
    out.append('\t{"id": "%s", "chapter": "space", "name": "%s", "emoji": "%s",' % (id_, name, emo))
    out.append('\t "tagline": "%s", "duration_sec": %d, "fast_sec": %d},' % (esc(tag), dur, 40 + i * 3))
out.append("")
out.append("\t# ── 엔딩 ──")
out.append('\t{"id": "rift", "chapter": "beyond", "name": "다른 차원", "emoji": "✨",')
out.append('\t "tagline": "여기서부터는 지도가 없다", "duration_sec": 86400, "fast_sec": 70, "final": true},')
out.append("]")

pathlib.Path("/tmp/dest_table.gd").write_text("\n".join(out) + "\n")
print("국내 %d · 해외 %d · 우주 %d · 차원 1 = 총 %d곳" % (
    len(KOREA), len(WORLD), len(SPACE), len(KOREA)+len(WORLD)+len(SPACE)+1))
# 중복 id 검사
ids = [d[0] for d in KOREA] + [d[0] for d in WORLD] + [d[0] for d in SPACE] + ["rift"]
dup = [i for i in set(ids) if ids.count(i) > 1]
print("중복 id:", dup if dup else "없음")
