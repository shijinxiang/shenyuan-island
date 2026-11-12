extends PanelContainer
var ornament_color:=Color(.26,.43,.40,.30)
var draw_ornaments:=true

func _ready() -> void:resized.connect(queue_redraw)

func _draw() -> void:
	if not draw_ornaments:return
	var points:=PackedVector2Array()
	for index in range(maxi(0,int(size.x)-56)):
		var x:=28.0+index
		points.append(Vector2(x,size.y-7.+sin(x*.10)*2.0))
	if points.size()>1:draw_polyline(points,ornament_color,1.0,true)
	for x in [17.,size.x-17.]:
		var curl:=PackedVector2Array()
		for index in 24:
			var angle:=float(index)*.25
			var radius:=8.0-index*.25
			curl.append(Vector2(x,18.)+Vector2(cos(angle),sin(angle))*radius)
		draw_polyline(curl,ornament_color,1.5,true)
