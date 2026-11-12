from pathlib import Path
p=Path(r'D:\浪费GPT额度\小温的游戏\游戏\scripts\player\skinning_grip.gd')
s=p.read_text(encoding='utf8').replace('knee + up * .10 - forward * .08','knee + up * .16 - forward * .10')
p.write_text(s,encoding='utf8')
p=Path(r'D:\浪费GPT额度\小温的游戏\素材\06_游戏场景资产\狩猎与烹饪\剥皮小刀\validate_low_skinning.gd')
s=p.read_text(encoding='utf8').replace('("res://assets/fauna/marine/BrownFish.glb" if height < .3 else "res://assets/fauna/marine/Seal.glb")','"res://assets/fauna/marine/BrownFish.glb"')
s=s.replace('var factor: float = height/box.size.y','''var ray_origin := Vector3(box.get_center().x,box.end.y+1.0,box.get_center().z)
		var top := box.position.y
		for mesh: MeshInstance3D in corpse.find_children("*","MeshInstance3D",true,false):
			var faces := mesh.mesh.get_faces()
			for k in range(0,faces.size(),3):
				var hit = Geometry3D.ray_intersects_triangle(ray_origin,Vector3.DOWN,mesh.global_transform*faces[k],mesh.global_transform*faces[k+1],mesh.global_transform*faces[k+2])
				if hit != null: top = maxf(top,hit.y)
		var factor: float = .15/(top-box.position.y)''')
s=s.replace('Vector3(box.get_center().x,box.end.y,box.get_center().z)*factor','''Vector3(box.get_center().x,top,box.get_center().z)*factor
		var support_fixture := MeshInstance3D.new()
		if height > .3:
			var fixture_box := BoxMesh.new()
			fixture_box.size = Vector3(.85,.3,.5)
			support_fixture.mesh = fixture_box
			support_fixture.position = Vector3(hunt.processing_target.x,.15,hunt.processing_target.z)
			var fixture_mat := StandardMaterial3D.new()
			fixture_mat.albedo_color = Color(.24,.14,.07)
			support_fixture.material_override = fixture_mat
			scene.add_child(support_fixture)''')
s=s.replace('corpse.queue_free()','corpse.queue_free()\n\t\tsupport_fixture.queue_free()')
p.write_text(s,encoding='utf8')
