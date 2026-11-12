# 深渊岛

低多边形风格的第三人称海岛生活游戏，使用 Godot 4.7.2 和 Forward+ 渲染。玩家可以钓鱼、潜水、种菜、伐木、烹饪、驾驶船和沙滩车，也可以接取商人委托、探索沉船和狩猎。

当前游戏版本为 **0.2.0**。本仓库从 2026 年 11 月 12 日建立版本历史，之前的开发过程保存在需求文档和实机记录中。

## 试玩

在仓库的 Releases 页面下载 `ShenyuanIsland_Windows_v0.2.0.zip`，完整解压后运行“开始游戏.cmd”。请把 EXE、同名 PCK 和许可证目录一起保留。Windows 版本需要支持 Vulkan 的显卡和驱动。

## 获取开发工程

安装 Git 和 Git LFS 后执行以下命令。

```powershell
git lfs install
git clone https://github.com/shijinxiang/shenyuan-island.git
cd shenyuan-island
git lfs pull
git lfs fsck
```

安装 Godot **4.7.2 Standard**，导入 `游戏/project.godot`，等待资源导入完成后按 F5 运行项目。主场景为 `游戏/scenes/coastal_beauty.scn`。

根目录的双击启动脚本使用本地便携版引擎。把官方 Windows 64 位引擎文件放到 `工具/Godot_4.7.2/` 即可沿用这些脚本，文件名保留为 `Godot_v4.7.2-stable_win64.exe` 和 `Godot_v4.7.2-stable_win64_console.exe`。导出还需要将同版本的 Windows 导出模板放到 `工具/Godot_4.7.2/export_templates/4.7.2.stable/`。引擎、模板和历史压缩归档由本地完整交付包保存。

编辑模型使用 Blender 5.2。工程中保留了可选 Godot AI 插件，协作者可按自己的环境启用或关闭。游戏操作见 [运行说明](游戏/运行说明.txt)。

本地执行仓库检查需要 Python 3，GitHub 自动检查会提供运行环境。

官方工具下载见 [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) 和 [Git LFS](https://git-lfs.com/)。

## 文件位置

| 目录 | 内容 |
| --- | --- |
| `游戏/scripts` | 按玩法划分的 GDScript |
| `游戏/scenes`、`游戏/shaders` | 场景和着色器 |
| `游戏/assets` | 游戏实际加载的模型、贴图、材质、字体和许可 |
| `素材` | 可编辑模型、动作原件、建模参考和制作脚本 |
| `需求` | 游戏规格、策划和两份开发过程文档 |
| `资料`、`整理记录` | 参考资料、实机截图、整理与核验记录 |
| `工具` | 本地导出、资源检查及维护脚本 |

`.uid` 和资源旁的 `.import` 设置随源文件提交。`.godot`、临时构建、导出产物、历史归档和本机引擎已配置忽略。

## 开发协作

日常修改从 `main` 新建功能分支，完成后提交 Pull Request。二进制 `.scn`、`.blend`、`.glb` 和 Word 文件开始编辑前，在对应 Issue 中约定负责人。

任务状态在[开发看板](https://github.com/users/shijinxiang/projects/2/views/2)中维护，依次为待处理、进行中、待验收和已完成。具体命令、交接要求与发布步骤见 [协作规范](CONTRIBUTING.md)。

## 版本与验证

- [版本记录](CHANGELOG.md)记录每次交付的改动。
- Issues 用于记录问题、功能和资产制作任务，模板包含复现与验收字段。
- Pull Request 模板记录改动范围、验证结果和实机证据。
- 仓库自动检查覆盖文件归类、大文件存储、LFS 指针和差异格式。
- Godot 运行资源核验脚本位于 `工具/项目整理/核验运行资源.gd`。实机玩法与画面通过本地 Godot 验收。

开发过程 Word 文档位于 `需求/开发过程文档/`，对应截图保存在 `整理记录/开发文档更新_2026-11-11/`。

## 素材来源

素材署名与许可保存在 `游戏/assets/licenses` 及各原始素材目录。沿用、修改和发布相关资源时请保留对应材料。仓库可见性为私有，项目和各第三方资产的授权分别以其权利人与原始许可为准。
