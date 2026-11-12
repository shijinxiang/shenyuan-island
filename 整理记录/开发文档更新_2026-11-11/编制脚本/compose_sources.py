from pathlib import Path
import json
import re

from update_content import FEATURES, full_update, team_updates

HERE = Path(__file__).resolve().parent.parent
OLD = HERE.parent / "开发文档编制_2026-11-07"
CHANGES = []


def replace(text, before, after, kind="自然表达"):
    if before not in text:
        raise ValueError("Missing source passage " + before[:65])
    CHANGES.append({"type": kind, "before": before, "after": after})
    return text.replace(before, after)


def polish(text):
    replacements = {
        "编号用于本次编制，不代表文件生成时间。": "编号用于本次文档的配图定位。",
        "问题若来自坡度变化，应先调整地形或柱长，而不是把整座码头往上抬。": "问题若来自坡度变化，先回查地形和柱长，再复核码头与岸面的连接高度。",
        "夜里隐藏的不仅是人物，还包括交互和碰撞。": "夜里停用人物显示、交互和碰撞。",
        "海床缓坡不仅提升画面，也决定人物何时游泳、船何时搁浅以及鱼能否进入。": "海床缓坡影响浅海画面、人物进入游泳的时机、船只搁浅和鱼的活动范围。",
        "Swimming To Edge不是整段直接循环，而是截取第101至151帧作为SwimIdle": "Swimming To Edge截取第101至151帧，循环播放为SwimIdle",
        "这是当前布局配置的实例规模，不代表697个不同物种。": "这697个对象包含同种鱼的重复实例。",
        "生物分布不仅影响观赏，也决定可钓目标、徒手捕捉和危险位置。": "生物分布决定可钓目标、徒手捕捉位置和危险区域，也影响水域观感。",
        "这些图用于理解结构和材质 并非拓扑或尺度测量图": "这些图用于理解结构和材质 网格和尺寸另由源模型核对",
        "预留不代表完整家具布置已经完成。": "这一阶段记录的是预留位置，床灯箱在本轮接入。",
        "而不是只交一张结果图": "并保存组件、网格和导出文件",
        "而不是把所有微小裂缝都做成几何": "，细小裂缝交给材质表达",
        "而不是仅优化外立面": "，并让外观与这些尺寸对应",
        "而不是只在极远天空放一张图": "，使低云在近景也能被观察到",
        "而不是把泡沫带整体扩宽": "，并保留原来的窄带宽度",
        "而不是继续粗暴压缩旧网格": "，再导出用于重复摆放的运行模型",
        "不能只靠一张截图就宣称整个系统无问题": "结论应限于已经检查的场景",
        "而不是互相认定对方文件已经“没问题”": "，按入口位置逐项核查模型和碰撞",
        "而不是只展示一份一开始就正确的策划书": "，把需求调整与返工一并讲清",
        "不是要求全岛树木都减少": "调整范围限于内湖新增棕榈",
        "不是三条硬色带": "颜色在控制范围内连续混合",
        "不是静态统一图标": "预览由物品模型实时渲染",
        "不是三名组员已完成的实时成果": "属于概念参考阶段",
        "这不是当前": "该图对应早期",
    }
    for before, after in replacements.items():
        if before in text:
            text = replace(text, before, after)
    lines = []
    for line in text.splitlines():
        if not line.lstrip().startswith(">") and not line.startswith("工程定位"):
            line = line.replace("；", "。")
        if not line.lstrip().startswith(">") and ("—" in line or "–" in line):
            original = line
            line = line.replace("码头—沙滩—木屋", "码头、沙滩和木屋").replace("码头—小屋", "码头与小屋")
            line = line.replace("—", "与").replace("–", "至")
            if line != original:
                CHANGES.append({"type": "连接方式", "before": original, "after": line})
        line = line.replace("，，", "，")
        line = line.replace("用户下调的是内湖沙滩新增棕榈的数量和大小比例，调整范围限于内湖新增棕榈。", "用户下调了内湖沙滩新增棕榈的数量和大小比例。")
        lines.append(line)
    return "\n".join(lines) + "\n"


def full_document():
    text = (OLD / "完整开发过程.md").read_text(encoding="utf-8")
    text = replace(text, "图文开发记录与工程说明", "图文开发记录与0.2.0工程说明", "版本范围")
    text = replace(text, "编制日期 2026 年 11 月 7 日", "更新日期 2026 年 11 月 11 日", "版本范围")
    text = replace(text, "记录范围 从需求制定到当前可运行原型与项目归档", "记录范围 从需求制定到0.2.0生活狩猎系统与最新双包交付", "版本范围")
    start = text.index("《深渊岛》是一个")
    end = text.index("[TOC]")
    introduction = """《深渊岛》以环形海岛为舞台，玩家扮演女渔夫小爱，在岛上捕鱼、耕种、伐木、采集和烹饪，与商人闻舟交换物资并完成委托。本轮增加了鳄鱼、枪弓、东海沉船、沙滩车、睡眠储物、地图和五格工具栏，狩猎按击倒、处理尸体、取肉的顺序完成。

第1至22章保留2026年11月7日以前的开发过程和阶段参数，第23至31章记录本次对话推进到11月11日的新增功能及修复。早期镜头、商店、作物和动作规则均注明所属阶段，0.2.0的操作与数值以本轮章节和随包运行说明为准。

材料包括24张原始制作流程图、阶段实机图、当前代码和模型资料，以及本轮从发布PCK采集的运行截图。新截图使用隔离测试存档，预置工具与物资，便于检查指定状态。每张图片保留来源、版本、场景和文件摘要。数值结算、连续位移和保存失败恢复同时参照运行记录。

正文保留需求变更、返工原因和实际交付路径。没有人员姓名和工时记录的阶段，按操作顺序叙述。源模型、参考图和实际运行画面分别注明用途。项目根目录为D:\\浪费GPT额度\\小温的游戏。

"""
    CHANGES.append({"type": "完整阅读后更新导言", "before": text[start:end], "after": introduction})
    text = text[:start] + introduction + text[end:]
    text = replace(text, "### 15.3 当前商店与种植基线", "### 15.3 11月7日商店与种植基线", "历史参数定位")
    text = replace(text, "这组数值是当前代码的原型参数，不是经过完整经济平衡后的正式定价。", "这组数值对应11月7日的原型参数。多日农耕和混合物资定价在本轮第23、24章更新。", "历史参数定位")
    text = replace(text, "## 20 当前完成范围与未完成范围", "## 20 11月7日阶段的完成范围", "历史参数定位")
    text = replace(text, "### 20.3 尚不能写成已完成的内容", "### 20.3 当时的待完成范围", "历史参数定位")
    text = replace(text, "| 遮挡人物透视 | 取消 | 用户要求撤销 |", "| 遮挡人物透视 | 当时取消 | 本轮按后续要求接入模糊透视 见第27章 |", "需求变更")
    text = replace(text,
        "曾经还实现遮挡时显示人物轮廓的轻微透视，用户随后要求取消，因此不属于当前默认表现。摄像机穿模使用碰撞安全调整解决，不能把已取消的透视效果重新作为镜头修复措施。",
        "这一阶段曾试过遮挡人物轮廓，随后按用户要求撤销，镜头采用碰撞安全调整。本轮用户重新指定模糊透视，并要求去掉树木遮挡引起的缩距，相关变化见第27、30章。", "需求变更")
    text = replace(text,
        "后续最值得继续完善的是首次游玩体验与视觉稳定性。玩家从苏醒开始，进屋取竿，第一次钓鱼，拾起渔获，再于清晨找闻舟交换，每一步都应知道接下来能做什么。短流程稳定后，再补家具生活、正式种植和长期探索。",
        "11月7日的维护计划从首次游玩短流程继续向家具生活、正式种植和长期探索推进。玩家苏醒、进屋取竿、第一次钓鱼、拾起渔获和清晨交易需要连续可理解。本轮随后接入床灯箱、多日农耕和两条商人委托，过程见第23章起。", "历史计划与新结果衔接")
    marker = "## 附录A 制作流程配图索引"
    updates, appendix = full_update().split("## 附录C 本轮需求与实机证据对照", 1)
    text = text.replace(marker, updates + "\n" + marker, 1)
    text += "\n## 附录C 本轮需求与实机证据对照" + appendix
    return polish(text)


def team_document():
    text = (OLD / "三人分工开发记录.md").read_text(encoding="utf-8")
    text = replace(text, "编制日期 2026 年 11 月 7 日", "更新日期 2026 年 11 月 11 日", "版本范围")
    text = replace(text, "以实际开发过程整理的三人责任划分与具体工作记录", "覆盖0.2.0的三人责任划分与具体工作记录", "版本范围")
    start = text.index("本文把《深渊岛》已有开发工作")
    end = text.index("[TOC]")
    introduction = """本文按资源建模、内容规划、场景搭建与运行接入整理《深渊岛》的三人分工。组员一负责可用模型、骨骼与动作，组员二负责玩法规则与需求变更，组员三负责Godot接入、交互、存档和发布。每部分保留交付文件、交接关系和返工记录。

组员一、二、三是责任划分框架，现有记录未提供可逐项确认历史操作的三名人员姓名。实际贡献可由小组结合源文件与过程记录确认。生成工具、免费资源和MCP的使用在对应步骤说明。

原有章节记录11月7日前的工作，各部分新增小节补入本轮对话截至11月11日的农耕、海岸生存、狩猎烹饪、快捷交互和尸体处理。当前版本为0.2.0。原型参数随迭代调整，历史表格保留所属阶段，最新操作与数值见新增小节及游戏运行说明。

实机证据包含阶段截图和最新发布PCK复核图。后者使用预置工具的隔离存档，记录截图来源与版本；连续动作、数值和失败恢复配合运行检查阅读。完整时间顺序及全部需求对照见配套整体文档。

"""
    CHANGES.append({"type": "完整阅读后更新导言", "before": text[start:end], "after": introduction})
    text = text[:start] + introduction + text[end:]
    text = replace(text, "### 11 商人作息和鱼获交换", "### 11 11月7日商人与种植基线", "历史参数定位")
    text = replace(text,
        "用户取消遮挡透视后，不再将其作为默认功能。",
        "这一阶段按用户要求撤销遮挡透视，本轮又接入指定的模糊透视。", "需求变更")
    text = replace(text,
        "当前只实现轻量风险机制，复杂武器、闪避和敌人等级尚未制作。",
        "11月7日阶段采用轻量风险机制。本轮接入枪弓和狩猎技艺，闪避和敌人等级仍属后续范围。", "需求变更")
    text = replace(text,
        "应主动说明原型参数与长期设计的区别。价格、成长时长与攻击次数是初始基线，完整农业、灯塔结局和外界地图尚未做完。内容规划可以提出它们，但不能替代运行成果。",
        "汇报时注明参数所属版本。此处价格、成长时长和攻击次数属于11月7日基线，本轮更新到多日农业和狩猎流程；灯塔结局、外界地图和长期经营平衡继续列入后续范围。", "当前范围更新")
    text = replace(text,
        "当前还需继续完善完整家具生活、长期经营、图鉴和任务线，强化动作与水体细节，并检查更多设备和窗口比例。后续任务继续按模型、内容和接入分到具体负责人，并在清单中记录完成状态。",
        "0.2.0已经接入床灯箱、多日农耕、狩猎烹饪和商人委托。后续仍需扩充图鉴、灯塔结局、外岛探索和长期经营平衡，并继续检查动作、水体以及不同设备和窗口比例。新增任务继续按模型、内容和运行接入分配责任。", "当前范围更新")
    additions = team_updates()
    text = text.replace("## 第二部分 组员二负责游戏内容规划", additions[1] + "\n## 第二部分 组员二负责游戏内容规划", 1)
    text = text.replace("## 第三部分 组员三负责游戏场景搭建", additions[2] + "\n## 第三部分 组员三负责游戏场景搭建", 1)
    text = text.replace("## 三人共同推进顺序", additions[3] + "\n## 三人共同推进顺序", 1)
    new_case = """### 例五 本轮尸体与剥皮小刀

组员二提出购买小刀后才能取肉，确认6条鱼加3份木材或8个萝卜加3份木材的交换条件。组员一交付木柄小刀、握点和切割动作，组员三接入尸体保存、处理进度与物品结算。发布截图发现冻结网格材质丢失时，先补齐表面材质，再重新导出并复拍。

同一轮交接还处理了大型鲨鱼的绑定边界，冻结到实际姿态后按体长整理尸体。水中用可触及侧面，腿和空闲手保留踩水动作。处理取消、重复操作和写入失败都需要保留一致的尸体与物品状态。

[FIG N16 最新发布包中带材质的完整尸体]

[FIG N18 用小刀处理后的肉类进入背包]

"""
    text = text.replace("## 分工交付清单", new_case + "## 分工交付清单", 1)
    text += "\n## 本轮分工与需求索引\n\n| 需求编号 | 主责 | 修改内容 |\n"
    text += "\n".join(f"| {f['id']} | 组员{['一','二','三'][f['owner']-1]} | {f['title']} |" for f in FEATURES)
    text += "\n\n本轮原始图片、版本记录和编制脚本位于整理记录\\开发文档更新_2026-11-11。每项需求的完整实机图片编号同时收录于整体文档附录C。\n"
    return polish(text)


def main():
    full = full_document()
    team = team_document()
    for filename, text in [("完整开发过程.md", full), ("三人分工开发记录.md", team)]:
        (HERE / filename).write_text(text, encoding="utf-8")
    report = {"skill": r"C:\Users\SHIJINXIANG\.codex\skills\humanizer\SKILL.md",
              "review_scope": "两份原文和本轮新增段落全文阅读；保留原始参数、代码路径、来信原文和阶段图说明",
              "changes": CHANGES, "new_requirements": len(FEATURES),
              "review_again": "渲染后再检查段落、版本条件、对照图片和可读性"}
    (HERE / "Humanizer润色记录.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"requirements": len(FEATURES), "recorded_edits": len(CHANGES),
                      "full_chars": len(full), "team_chars": len(team)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
