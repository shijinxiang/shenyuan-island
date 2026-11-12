extends SceneTree
var dependencies:Dictionary={}

func _initialize() -> void:
	scan("res://")
	var arguments:=OS.get_cmdline_user_args()
	var output:="res://../整理记录/运行诊断/资源依赖_latest.json" if arguments.is_empty() else arguments[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(dependencies,"  "))
	print("RESOURCE_DEPENDENCIES ",dependencies.size())
	quit()

func scan(path:String) -> void:
	for directory in DirAccess.get_directories_at(path):
		if not directory.begins_with("."):scan(path.path_join(directory))
	for filename in DirAccess.get_files_at(path):
		if filename.get_extension().to_lower() in ["scn","res","tscn","tres","gd","glb","gltf","gdshader","gdshaderinc"]:
			var resource_path:=path.path_join(filename)
			dependencies[resource_path]=Array(ResourceLoader.get_dependencies(resource_path))
