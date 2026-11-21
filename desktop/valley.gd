extends RefCounted

const COLS = 15
const ROWS = 12
const CORE_CELLS = 72
const SECTORS = ["中央河谷","上游竹埠","两岸丘陵","下游沙洲"]
const R = 1.52
const WIDTH = 2.632717
const STEP = 2.28

# Keep the original valley's tile IDs and world coordinates for farms, dikes and workers in old saves.
static func grid(id: int) -> Vector2i:
	if id<72: return Vector2i(id%9+3,floori(id/9.0)+2)
	if id<102: return Vector2i((id-72)%15,floori((id-72)/15.0))
	if id<150:
		var side=(id-102)%6
		return Vector2i(side if side<3 else side+9,floori((id-102)/6.0)+2)
	return Vector2i((id-150)%15,10+floori((id-150)/15.0))

static func id_at(col: int,row: int) -> int:
	if col<0 or row<0 or col>=COLS or row>=ROWS: return -1
	if row<2: return 72+row*COLS+col
	if row>=10: return 150+(row-10)*COLS+col
	if col>=3 and col<12: return (row-2)*9+col-3
	return 102+(row-2)*6+(col if col<3 else col-9)

static func sector(id: int) -> int:
	if id<72: return 0
	if id<102: return 1
	return 2 if id<150 else 3

static func center(id: int) -> Vector2:
	var pos=grid(id)
	return Vector2((pos.x-7.25+0.5*(pos.y%2))*WIDTH,(pos.y-5.5)*STEP)

static func river(z: float) -> float:
	return 0.36 * z + 1.18 * sin(z * 0.42 + 0.6) - 0.15

static func breadth(z: float) -> float:
	return 1.14 + 0.14 * sin(z * 0.62 + 0.1)

static func ground(x: float, z: float) -> float:
	var bank = absf(x - river(z)) - breadth(z)
	var ramp = smoothstep(-0.15, 1.2, bank)
	var upland = smoothstep(3.3, 11.5, bank)
	var breaks = sin(x * 0.52 + z * 0.21) * 0.12 + cos(z * 0.68) * 0.09
	return -0.37 + 0.73 * ramp + upland * (2.0 + 0.39 * sin(z * 0.32 + x * 0.22)) + breaks * ramp + 0.035 * sin(z * 1.78 + x)

static func v3(p: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(p.x, ground(p.x,p.y) + lift, p.y)

static func crossing(a: Vector2,b: Vector2) -> Array:
	if (a.x-river(a.y))*(b.x-river(b.y))>=0: return [a,b]
	var z=-3.5 if absf(a.y+3.5)+absf(b.y+3.5)<absf(a.y-4.8)+absf(b.y-4.8) else 4.8
	var direction=signf(a.x-river(a.y))
	var half=breadth(z)+1.75
	return [a,Vector2(river(z)+half*direction,z),Vector2(river(z)-half*direction,z),b]

static func corner(id: int, k: int, scale_factor: float = 1.0) -> Vector2:
	var a = PI * (float(k) / 3.0 - 1.0 / 6.0)
	return center(id) + Vector2(cos(a), sin(a)) * R * scale_factor

static func nb(id: int, d: int) -> int:
	var pos=grid(id)
	var row = pos.y
	var shift = row % 2
	var delta = [Vector2i(1,0),Vector2i(shift,1),Vector2i(shift-1,1),Vector2i(-1,0),Vector2i(shift-1,-1),Vector2i(shift,-1)][posmod(d,6)]
	return id_at(pos.x+delta.x,row+delta.y)

static func edge_key(a: int, b: int) -> String:
	return "%d-%d" % [mini(a,b), maxi(a,b)]

static func distance(a: int,b: int) -> int:
	var ga=grid(a)
	var gb=grid(b)
	var ra=ga.y
	var rb=gb.y
	var dq=(ga.x-floori(ra/2.0))-(gb.x-floori(rb/2.0))
	return maxi(absi(dq),maxi(absi(ra-rb),absi(dq+ra-rb)))

static func tier(id: int) -> int:
	var p = center(id)
	var d = absf(p.x - river(p.y))
	if d < breadth(p.y) + 0.32: return -1
	if d < 5.9: return 0
	if d < 8.8: return 1
	return 2

static func intake(id: int) -> int:
	var best = -1
	var distance = INF
	for d in 6:
		var other = nb(id,d)
		if other == -1: continue
		var p = center(other)
		var bank = absf(p.x - river(p.y))
		if bank < distance:
			distance = bank
			best = d
	return best

static func reach(id: int) -> int:
	return clampi(floori((center(id).y + 9.12) / 6.08),0,2)

static func region(id: int) -> String:
	if sector(id)>0: return SECTORS[sector(id)]
	var p = center(id)
	if p.x < river(p.y): return "西岭" if tier(id) > 0 else "芦湾"
	return "东岗" if tier(id) > 0 else "河滩"

static func address(id: int) -> String:
	var pos=grid(id)
	return "%s · %s%d" % [region(id),char(65+pos.x),pos.y+1]

static func cell_at(p: Vector2) -> int:
	var row = roundi(p.y / STEP + 5.5)
	var result = -1
	var best = INF
	for rr in range(maxi(0,row-1), mini(ROWS,row+2)):
		var cc = roundi(p.x / WIDTH + 7.25 - 0.5 * (rr % 2))
		if cc < 0 or cc >= COLS: continue
		var id = id_at(cc,rr)
		var dist = center(id).distance_squared_to(p)
		if dist < best:
			best = dist
			result = id
	if result < 0: return -1
	var off = (p-center(result)).abs()
	if off.x > WIDTH*0.5 or off.y + off.x / sqrt(3.0) > R: return -1
	return result
