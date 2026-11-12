extends SceneTree
func _initialize():
 var folder="D:/浪费GPT额度/小温的游戏/游戏/assets/cooking/"
 var results=[]
 for file in DirAccess.get_files_at(folder):
  if not file.ends_with(".glb"): continue
  var doc=GLTFDocument.new()
  var state=GLTFState.new()
  var code=doc.append_from_file(folder+file,state)
  var scene=doc.generate_scene(state) if code==OK else null
  var meshes=[]
  if scene:
   for node in scene.find_children("*","",true,false): 
    if node is ImporterMeshInstance3D or node is MeshInstance3D: meshes.append(node.name)
  results.append({"file":file,"error":code,"meshes":meshes.size(),"Flame":meshes.has("Flame"),"Berries":meshes.has("Berries"),"Harvest":meshes.has("Harvest")})
  if scene:scene.free()
 var out=FileAccess.open("D:/浪费GPT额度/小温的游戏/素材/06_游戏场景资产/狩猎与烹饪/烹饪采集/godot_validation.json",FileAccess.WRITE)
 out.store_string(JSON.stringify(results,"  "))
 print(JSON.stringify(results))
 quit()


