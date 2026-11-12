from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parent.parent
TEMP = Path(r"C:\Users\SHIJINXIANG\AppData\Local\Temp")
HISTORY = [
    ("H01", "abyss-water-20261109", "treading_grip_front.png", "踩水时恢复鱼叉中段握持"),
    ("H02", "abyss-water-20261109", "swimming_stowed.png", "游泳移动时收起鱼叉"),
    ("H03", "abyss-farming-20261110", "chop_in_game.png", "Baseball Hit首次挥击段接入砍树"),
    ("H04", "abyss-farming-20261110", "felled_tree_and_logs.png", "砍倒树木后留下树桩和多段木头"),
    ("H05", "abyss-farming-20261110", "wet_dry_mature_fields.png", "贴地耕地的湿润干裂与成熟作物"),
    ("H06", "abyss-farming-20261110", "dry_seedlings.png", "缺水地面干裂与幼苗阶段"),
    ("H07", "abyss-farming-20261110", "watering_in_game.png", "Watering浇水与水壶握持"),
    ("H08", "abyss-farming-20261110", "harvest_in_game.png", "Pick Fruit修改为单手收获动作"),
    ("H09", "abyss-farming-20261110", "character_status.png", "经验等级移入人物面板"),
    ("H10", "abyss-farming-20261110", "character_backpack.png", "人物面板中的背包页"),
    ("H11", "abyss-farming-20261110", "survival_shop.png", "生活补给和升级商品分类"),
    ("H12", "abyss-farming-20261110", "beach_buggy_driving.png", "低多边形沙滩车与Driving动作"),
    ("H13", "abyss-repairs-20261110", "storage_before.png", "箱子与背包双栏存取界面"),
    ("H14", "abyss-repairs-20261110", "storage_after.png", "存放后双栏物品状态同步"),
    ("H15", "abyss-repairs-20261110", "minimap_complete.png", "右上角小地图完整显示"),
    ("H16", "abyss-camera-map-20261110", "deep_sea_minimap.png", "深海远航时小地图扩大覆盖范围"),
    ("H17", "abyss-camera-map-20261110", "occlusion_blurred_wall.png", "遮挡时的人物模糊透视"),
    ("H18", "abyss-minimap-input-20261110", "minimap_zoomed_island.png", "小地图滚轮放大岛屿"),
    ("H19", "abyss-minimap-input-20261110", "minimap_panned.png", "小地图左键拖动平移"),
    ("H20", "abyss-minimap-input-20261110", "minimap_full_world.png", "地图缩小到全海域范围"),
    ("H21", "abyss-hunting-cooking-20261110", "bow_on_boat.png", "船上持弓瞄准"),
    ("H22", "abyss-hunting-cooking-20261110", "delicious_bag.png", "美味的彩色菜名前缀和食物背包"),
    ("H23", "abyss-hotbar-interaction-20261110", "hover_tree_outline.png", "鼠标悬停树木显示白边"),
    ("H24", "abyss-hotbar-interaction-20261110", "selected_tree_hover_plot.png", "相邻树木和耕地分别悬停及选中"),
    ("H25", "abyss-hotbar-interaction-20261110", "selected_boat_hover_fish.png", "水中上船与抓鱼分别选择"),
    ("H26", "abyss-hotbar-drag-fix-20261110", "backpack_drag_equipment.png", "背包拖拽工具到五格快捷栏"),
    ("H27", "abyss-hotbar-drag-fix-20261110", "storage_drag_equipment.png", "开箱时从人物背包拖入快捷栏"),
    ("H28", "abyss-stable-camera-20261111", "fixed_distance_blurred_subject.png", "遮挡保留手动镜距并柔和透视人物"),
    ("H29", "abyss-stable-camera-20261111", "driving_forest_fixed_camera.png", "树林内驾车的稳定跟随镜头"),
    ("H30", "abyss-grip-ground-bow-20261111", "camera_actual_1.png", "仰视镜头保持在真实地面上方"),
    ("H31", "abyss-grip-ground-bow-20261111", "main_scene_axe_grip.png", "掌心向内后的斧头主场景握持"),
    ("H32", "abyss-grip-ground-bow-20261111", "main_scene_axe_steel_grip.png", "钢斧沿用同一修正握点"),
    ("H33", "abyss-grip-ground-bow-20261111", "main_scene_source_bow.png", "按原始弓箭动作恢复左右手和缩窄帽檐"),
]


def main():
    entries = []
    for key, directory, filename, caption in HISTORY:
        source = TEMP / directory / filename
        destination = ROOT / "实机证据" / (key + "_" + filename)
        if source.is_file():
            shutil.copy2(source, destination)
        elif not destination.is_file():
            raise FileNotFoundError(destination)
        entries.append({"id": key, "path": str(destination), "name": filename,
                        "original_path": str(source), "caption": caption,
                        "kind": "本轮开发阶段主场景运行截图",
                        "sha256": hashlib.sha256(destination.read_bytes()).hexdigest()})
    current = json.loads((ROOT / "实机证据/最新实机截图索引.json").read_text(encoding="utf-8"))
    for item in current:
        item["name"] = Path(item["path"]).name
        item["kind"] = "2026年11月11日最新发布PCK实机复核截图"
        item["sha256"] = hashlib.sha256(Path(item["path"]).read_bytes()).hexdigest()
        entries.append(item)
    broken = ROOT / "实机证据/问题复现/尸体材质丢失.png"
    entries.append({"id": "D01", "path": str(broken), "name": broken.name,
                    "caption": "发布截图复核中发现的尸体材质丢失",
                    "kind": "已修复问题的实际运行画面",
                    "sha256": hashlib.sha256(broken.read_bytes()).hexdigest()})
    (ROOT / "新增图片索引.json").write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Copied and indexed {len(entries)} original runtime screenshots")


if __name__ == "__main__":
    main()
