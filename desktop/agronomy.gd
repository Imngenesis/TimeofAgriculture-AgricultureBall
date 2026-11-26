extends RefCounted

const C = preload("res://crop_book.gd")
const Curriculum = preload("res://curriculum.gd")
const CODE = C.CODES
const ROOTS = {
 "稻": ["稻穗留种", "晒稻入仓"], "粟": ["选穗播粟", "干藏粟穗"], "麦": ["麦穗选种", "脱粒入仓"],
 "薯": ["留薯试种", "薯窖储藏"], "豆": ["选荚留种", "晾荚脱粒"], "玉米": ["选棒留种", "悬棒风干"]}

const METHODS = {
 "稻": [["选穗分藏", "秋收时先民不将谷粒一律归仓，而是专挑穗大粒饱、熟透不落者连穗割下，单晾单藏，与日常口粮分开保管，后世称“穗选留种”。此举既防荒年混食、断送下来年种源，又让不落粒、籽粒饱满的性状在逐代拣选中累积固定；把一穗从口粮里分出来，正是良种选育的起点。水稻基础收成增加 1。"], ["分畦插秧", "大水漫撒的早期水田，水深难匀、草苗难辨，收成全凭天时。先民把田划成宽窄一致的畦，畦间开沟引水，水层深浅可逐畦调节，旱能灌、涝能排；下种也不再扬手乱撒，而是按等距分株插秧入畦，株行成线。田分畦、秧成行之后，通风受光均匀、除草顺手，用种用水都省，水田自此由粗放转入精耕。低田水稻增收 3 粮。"], ["青田稻鱼共生", "浙江青田一带，农人在稻田里放养鲤鱼，俗名“田鱼”。稻田为鱼遮阴、供稻花虫饵，鱼群游动搅松田泥、啃食杂草与稻飞虱，鱼粪就地肥稻，稻鱼一田双收。因鱼不耐药，此法天然倒逼少施化肥农药，千年来自成一套生态农法，青田稻鱼共生系统亦入选首批全球重要农业文化遗产；难处是须常年保水、严控施药，田块与鱼种都得另作安排。连通灌渠的稻田秋收增 3 份口粮。"]],
 "粟": [["辨穗选粟", "按穗形分开保留地方粟种，便于比较收成。珍珠粟基础收成增加 1。"], ["雨季错播", "分散雨季播期，减轻弱苗齐发的损失。高地或地力不足 58 的粟田增收 3 粮。"], ["草谷兼收", "谷穗与秸草分收，充分利用旱区收获。每块粟田秋收额外入库 3 饲料。"]],
 "麦": [["单穗选麦", "留取整穗小麦比较籽粒。小麦基础收成增加 1。"], ["条田匀播", "成行条播使群体疏密较一致。台地或麦区的麦田增收 3 粮。"], ["麦场精收", "分次归拢、清选落粒，减少麦粒损耗。每块有当地连通粮仓的麦田多收 4 粮。"]],
 "薯": [["块茎分级", "按块茎大小分别留种，减少出苗差异。马铃薯基础收成增加 1。"], ["高畦培土", "垄畦增加块茎生长空间。高地或安第斯的薯田多收 4 粮。"], ["窖藏留薯", "选择通风阴凉的窖室贮存块茎。有当地连通粮仓时，薯田免去 2 粮分拣损耗并多收 2 粮。"]],
 "豆": [["选荚分收", "从成熟豆荚中选出完整种子留作下茬。菜豆基础收成增加 1。"], ["搭架引蔓", "给攀援品系提供支架，增加可用光照。照料达到 30 人秒的豆田多收 3 粮。"], ["豆茬养地", "将豆茬归田以培肥地力。豆田秋收时额外恢复 4 地力，并收 1 饲料。"]],
 "玉米": [["穗行留种", "将不同果穗分行试种并记录表现。玉米基础收成增加 1。"], ["宽行培土", "控制行距并为植株根部培土。台地或墨西哥高原的玉米田多收 3 粮。"], ["籽秆分储", "将籽粒归粮仓、秸秆另储。每块玉米田秋收额外入库 4 饲料。"]]}
const HERITAGE = {
 "plough": ["江东曲辕犁", 1, 3, ["seed"], "以曲辕犁整地，有农人到岗的田块每秒额外积累 1 点照料。", 0],
 "drill": ["耧车条播", 1, 4, ["seed"], "西汉赵过推广的畜力播种机，木耧下并排数只中空耧腿，牛拉人扶，行过之处开沟、落籽、覆土一气呵成，行距与播深皆由耧脚定死。较之扬手漫撒的深浅不一、籽粒聚散，条播出苗成行、整齐均匀，既省下种子，又便于此后中耕除草、顺垄追肥；它本是旱地麦粟的利器，传入稻区后成为旱稻与稻麦轮作的播种基础。粟、麦、玉米每田少用 1 份种粮，最低 1 份。", 1],
 "pump": ["龙骨水车", 2, 5, ["dike"], "龙骨水车借链板沿斜槽提水。有人操作的灌渠覆盖范围增加一格，便于把水送上田畦。", 2],
 "winnow": ["竹箕扬场", 1, 3, ["dry"], "用竹箕借风分开籽粒和轻糠。连通本地粮仓的稻、粟、麦、玉米每田多收 2 粮。", 4]}
const BILLS = [[2, 0, 1, 0], [3, 1, 2, 0], [4, 1, 2, 1], [5, 2, 3, 2]]
const HOURS = [16, 23, 31, 40]
static var branches = {}
static func all(core: Dictionary) -> Dictionary:
 if not branches.is_empty(): return branches
 branches = core.duplicate(true)
 for key in HERITAGE: branches[key] = HERITAGE[key].slice(0, 5)
 for crop in CODE:
  for stage in 3:
   var key = id(crop, stage)
   var method = METHODS[crop] [stage]
   var parents = ["seed" if stage == 0 else id(crop, stage - 1)]
   if stage == 1: parents.append({"稻": "dike", "粟": "scout", "麦": "drill", "薯": "dry", "豆": "rotate", "玉米": "plough"} [crop])
   branches[key] = [method[0], 2 if stage == 1 and crop == "豆" else stage, [2, 4, 6] [stage], parents, method[1]]
 for key in Curriculum.TOPICS.data:
  var row = Curriculum.TOPICS.data[key]
  branches[key] = [row.name, int(row.era), int(row.notes), row.requires, row.description]
 return branches

static func id(crop: String, stage: int) -> String:
 return CODE[crop] + "_" + str(stage + 1)

static func subject(key: String) -> String:
 for crop in CODE:
  if key.begins_with(CODE[crop] + "_"): return crop
 return ""

static func discovered(s: Dictionary, crop: String) -> bool:
 return s.frontier.lines.has(crop) or s.frontier.samples.has(crop)

static func bill(s: Dictionary, key: String, spec: Array) -> Array:
 var cost = BILLS[spec[1]].duplicate()
 var first = C.START[s.frontier.region]
 if key == "seed":
  cost = {"稻": [2, 0, 0, 0], "粟": [1, 0, 1, 0], "麦": [2, 0, 1, 0], "薯": [3, 0, 0, 0], "豆": [2, 0, 0, 0], "玉米": [3, 0, 1, 0]} [first]
 elif key == "dry":
  cost = {"稻": [2, 0, 1, 0], "粟": [1, 0, 2, 0], "麦": [2, 0, 0, 1], "薯": [2, 0, 1, 1], "豆": [2, 0, 1, 0], "玉米": [2, 0, 2, 0]} [first]
 elif key == "drill" or key == "plough": cost[3] += 1
 elif subject(key) != "" and spec[1] > 0: cost[1] += 1 if subject(key) not in["薯", "玉米"] else 2
 if Curriculum.TOPICS.data.has(key):
  match discipline(key):
   "育种": cost[1] += 1
   "耕作": cost[2] += 1
   "防灾": cost[3] += 1
   "经济": cost[0] += 2
  if Curriculum.terms(key) > 0:
   cost[0] += 2
   cost[1] += 1
 return cost

static func discipline(key: String) -> String:
 if Curriculum.TOPICS.data.has(key): return Curriculum.TOPICS.data[key].track
 if key in HERITAGE: return "防灾" if key == "pump" else "耕作"
 var crop = subject(key)
 if crop != "": return "育种" if key.ends_with("_1") else "耕作"
 return "公共"

static func notes(s: Dictionary, key: String, spec: Array) -> int:
 var focus = s.research_record.focus
 var track = discipline(key)
 if focus == "" or track == "公共": return spec[2]
 return maxi(1, roundi(spec[2] * 0.70)) if track == focus else ceili(spec[2] * 1.15)

static func title(s: Dictionary, key: String, techs: Dictionary) -> String:
 if key in["seed", "dry"]: return ROOTS[C.START[s.frontier.region]] [0 if key == "seed" else 1]
 return techs[key] [0]

static func timing(spec: Array) -> int:
 return HOURS[spec[1]]

static func limit(s: Dictionary, level: int) -> int:
 return 7 + level * 2 + s.era * 3

static func description(s: Dictionary, key: String, techs: Dictionary) -> String:
 if key in["seed", "dry"]:
  var crop = C.START[s.frontier.region]
  var method = title(s, key, techs)
  return("%s的第一课是「%s」。用本地种源开设第一块试验农田。" if key == "seed" else "%s的收获按「%s」处理。解锁备荒粮仓，当地的秋粮可以集中保管。") % [C.title(crop), method]
 return techs[key] [4]
