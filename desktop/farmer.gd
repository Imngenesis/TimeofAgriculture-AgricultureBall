extends Node3D

const G=preload("res://geometry.gd")
const COATS=[Color("#5a7570"),Color("#9c6044"),Color("#947955"),Color("#566776"),Color("#747954")]
var legs=[]
var arms=[]

func outfit(index: int,material: Material):
	var coat=COATS[index%COATS.size()]
	var trousers=Color("#454b45")
	var skin=Color("#b68a65")
	var torso=G.new()
	torso.beam(Vector3(0,0.19,0),Vector3(0,0.37,0),0.089,0.084,coat,10)
	torso.beam(Vector3(0,0.235,0),Vector3(0,0.252,0),0.090,0.089,Color("#574c3c"),10)
	torso.beam(Vector3(-0.049,0.36,0.062),Vector3(0.032,0.25,0.078),0.008,0.006,Color("#c2b79c"),5)
	torso.beam(Vector3(0,0.36,0),Vector3(0,0.41,0),0.035,0.033,skin,8)
	torso.oval(Vector3(0,0.433,0),Vector3(0.055,0.066,0.054),skin,0.2,10,5)
	torso.oval(Vector3(0,0.448,-0.018),Vector3(0.057,0.061,0.046),Color("#49443c"),0,10,4)
	var straw=Color("#a88c54")
	torso.beam(Vector3(0,0.478,0),Vector3(0,0.499,0),0.153,0.134,straw.darkened(0.15),20)
	torso.beam(Vector3(0,0.496,0),Vector3(0,0.566,0),0.136,0.021,straw,20)
	for n in 10:
		var ray=Vector3(cos(n*TAU/10),0,sin(n*TAU/10))
		torso.beam(Vector3(0,0.563,0)+ray*0.02,Vector3(0,0.492,0)+ray*0.13,0.004,0.004,straw.lightened(0.16),4)
	if index%3==0:
		var basket=Vector3(0,0.28,-0.105)
		torso.beam(basket-Vector3.UP*0.065,basket+Vector3.UP*0.045,0.048,0.077,straw.darkened(0.25),12)
		for k in 3:
			var base=basket+Vector3.UP*(k*0.026-0.028)
			torso.beam(base,base+Vector3.UP*0.006,0.061+0.006*k,0.061+0.006*k,straw,12)
	add_child(torso.bake(material))
	for sign_x in [-1,1]:
		var leg=G.new()
		leg.beam(Vector3.ZERO,Vector3(0,-0.154,0.015),0.041,0.029,trousers,8)
		leg.oval(Vector3(0,-0.165,0.033),Vector3(0.034,0.021,0.061),Color("#494334"),0,8,4)
		var knee=leg.bake(material)
		knee.position=Vector3(sign_x*0.049,0.19,0)
		add_child(knee);legs.append(knee)
		var arm=G.new()
		var elbow=Vector3(sign_x*0.024,-0.083,0.012)
		var wrist=elbow+Vector3(0,-0.064,0.030)
		arm.beam(Vector3.ZERO,elbow,0.036,0.026,coat,8)
		arm.beam(elbow,wrist,0.023,0.018,skin,7)
		arm.oval(wrist,Vector3(0.019,0.026,0.022),skin,0,7,3)
		var shoulder=arm.bake(material)
		shoulder.position=Vector3(sign_x*0.084,0.356,0)
		add_child(shoulder);arms.append(shoulder)

func pose(phase: float,walking: bool,working: bool):
	for i in 2:
		var swing=sin(phase)*(1 if i==0 else -1)
		legs[i].rotation.x=swing*(0.59 if walking else 0.024)
		arms[i].rotation.x=(-swing*0.51 if walking else (-0.36+swing*0.28 if working else swing*0.07))
