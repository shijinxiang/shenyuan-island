extends RefCounted

static func setup(scene: Node3D) -> void:
	if not scene.has_node("ShallowSeabedCollision"):
		var raw:=FileAccess.get_file_as_bytes("res://assets/generated/shore_bed.bin").to_float32_array()
		var vertices:=PackedVector3Array()
		vertices.resize(raw.size()/3)
		for index in vertices.size():vertices[index]=Vector3(raw[index*3],raw[index*3+1],raw[index*3+2])
		var seabed:=StaticBody3D.new()
		seabed.name="ShallowSeabedCollision"
		var collision:=CollisionShape3D.new()
		var shape:=ConcavePolygonShape3D.new()
		shape.set_faces(vertices)
		collision.shape=shape
		seabed.add_child(collision)
		scene.add_child(seabed)
	preload("res://scripts/world/nearshore_enrichment.gd").setup(scene)
	for old_bird in scene.find_children("CoastalGull", "", true, false):
		old_bird.get_parent().remove_child(old_bird)
		old_bird.queue_free()
	if not scene.has_node("IslandWeather"):
		var weather := Node3D.new()
		weather.name = "IslandWeather"
		weather.set_script(load("res://scripts/weather/island_weather.gd"))
		scene.add_child(weather)
	if not scene.has_node("IslandWildlife"):
		var wildlife := Node3D.new()
		wildlife.name = "IslandWildlife"
		wildlife.set_script(load("res://scripts/wildlife/island_wildlife.gd"))
		scene.add_child(wildlife)
	if not scene.has_node("Rowboat"):
		var controller=preload("res://scripts/boating/rowboat_controller.gd").new()
		controller.name="Rowboat"
		controller.boat_visual=scene.boat
		scene.add_child(controller)
	if not scene.has_node("Fishing"):
		var controller=preload("res://scripts/fishing/fishing_controller.gd").new()
		controller.name="Fishing"
		scene.add_child(controller)
	if not scene.has_node("IslandAdventure"):
		var adventure=preload("res://scripts/adventure/island_adventure.gd").new()
		adventure.name="IslandAdventure"
		scene.add_child(adventure)
