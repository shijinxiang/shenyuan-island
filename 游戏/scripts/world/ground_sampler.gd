extends RefCounted
var faces:=PackedVector3Array()
var bins:Dictionary={}
func build(mesh:MeshInstance3D) -> void:
	faces=mesh.mesh.get_faces()
	var transform:=preload("res://scripts/core/island_static_setup.gd").world_transform(mesh)
	for index in faces.size():faces[index]=transform*faces[index]
	for index in range(0,faces.size(),3):
		var a:=Vector2(faces[index].x,faces[index].z)
		var b:=Vector2(faces[index+1].x,faces[index+1].z)
		var c:=Vector2(faces[index+2].x,faces[index+2].z)
		var minimum:Vector2=(a.min(b).min(c)/5.).floor()
		var maximum:Vector2=(a.max(b).max(c)/5.).floor()
		for x in range(int(minimum.x),int(maximum.x)+1):
			for z in range(int(minimum.y),int(maximum.y)+1):
				var key:=Vector2i(x,z)
				if not bins.has(key):bins[key]=[]
				bins[key].append(index)
func height(x:float,z:float) -> float:
	var highest:float=-100.
	for index in bins.get(Vector2i(floori(x/5.),floori(z/5.)),[]):
		var a:=faces[index];var b:=faces[index+1];var c:=faces[index+2]
		var denominator:float=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		if absf(denominator)<.000001:continue
		var u:float=((b.z-c.z)*(x-c.x)+(c.x-b.x)*(z-c.z))/denominator
		var v:float=((c.z-a.z)*(x-c.x)+(a.x-c.x)*(z-c.z))/denominator
		if u>=-.00001 and v>=-.00001 and u+v<=1.00001:
			highest=maxf(highest,u*a.y+v*b.y+(1-u-v)*c.y)
	return highest
