extends Button

func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	var ink:=Color("c8dfc9")
	ink.a=.25 if disabled else .72
	var baseline:=size.y-6.0
	var wave:=PackedVector2Array()
	for index in range(int(size.x-16)):
		var x:=8.0+index
		wave.append(Vector2(x,baseline+sin(x*.20)*1.6))
	if wave.size()>1:draw_polyline(wave,ink,1.0,true)
	for side in [-1.0,1.0]:
		var center:=Vector2(13 if side<0 else size.x-13,size.y*.46)
		var curl:=PackedVector2Array()
		for index in 20:
			var angle:=float(index)*.24
			var radius:=5.5-float(index)*.20
			curl.append(center+Vector2(cos(angle)*side,sin(angle))*radius)
		draw_polyline(curl,ink,1.25,true)
	var gold:=Color("d1b879");gold.a=.35
	draw_line(Vector2(20,4),Vector2(size.x-20,4),gold,1.0,true)
