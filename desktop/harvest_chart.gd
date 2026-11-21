extends Control

const U=preload("res://paper.gd")
const SEASONS=["春","夏","秋","冬"]
var entries=[]

func _draw():
	if entries.is_empty(): return
	var font=get_theme_default_font()
	var high=1
	for pair in entries: high=maxi(high,maxi(pair[1],pair[2]))
	var top=18.0
	var base=size.y-21
	var span=(size.x-34)/8.0
	draw_line(Vector2(30,top),Vector2(size.x,top),U.LINE,1)
	draw_line(Vector2(30,base),Vector2(size.x,base),U.LINE,1)
	draw_string(font,Vector2(1,top+5),str(high),HORIZONTAL_ALIGNMENT_LEFT,-1,12,U.DIM)
	draw_string(font,Vector2(12,base),"0",HORIZONTAL_ALIGNMENT_LEFT,-1,12,U.DIM)
	for i in entries.size():
		var entry=entries[i]
		var x=32+i*span
		for j in 2:
			var height=(base-top)*entry[j+1]/high
			draw_rect(Rect2(x+span*(0.12+j*0.32),base-height,span*0.26,height),U.GREEN if j==0 else U.GOLD)
		draw_string(font,Vector2(x,base+16),"%d%s" % [floori(entry[0]/4.0)+1,SEASONS[entry[0]%4]],HORIZONTAL_ALIGNMENT_CENTER,span,12,U.DIM)
