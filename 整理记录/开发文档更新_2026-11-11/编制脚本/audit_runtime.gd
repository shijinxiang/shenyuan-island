extends SceneTree

const OUTPUT := "D:/浪费GPT额度/小温的游戏/整理记录/开发文档更新_2026-11-11/运行资源核验.json"
var checked := 0
var missing: Array = []

func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","CodexAbyssDependencyAudit20261111")
	for folder in ["res://scenes","res://assets","res://scripts"]:
		inspect_folder(folder)
	var report := {"version":ProjectSettings.get_setting("application/config/version"),"checked_resources":checked,"missing_dependencies":missing,"passed":missing.is_empty()}
	var file:=FileAccess.open(OUTPUT,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("RUNTIME_DEPENDENCY_AUDIT ",checked," missing=",missing.size())
	quit(0 if missing.is_empty() else 2)

func inspect_folder(folder:String) -> void:
	for child in DirAccess.get_directories_at(folder):
		inspect_folder(folder.path_join(child))
	for name in DirAccess.get_files_at(folder):
		if name.get_extension().to_lower() not in ["scn","tscn","res","tres","glb","gltf","gd"]:
			continue
		var path:=folder.path_join(name)
		checked+=1
		for dependency in ResourceLoader.get_dependencies(path):
			var resource:String=String(dependency).split("::")[-1]
			if not ResourceLoader.exists(resource):missing.append({"resource":path,"dependency":resource})
