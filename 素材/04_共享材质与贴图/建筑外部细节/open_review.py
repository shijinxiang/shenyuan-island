import bpy
p=r'D:\浪费GPT额度\小温的游戏\素材\Blender模型\整岛灰模_v08_建筑细节\深渊岛_建筑细节_v08.blend'
bpy.ops.wm.open_mainfile(filepath=p)
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=p)
