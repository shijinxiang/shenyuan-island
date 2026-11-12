# 协作规范

## 开始修改

先更新主分支，再建立自己的分支。

```powershell
git switch main
git pull --ff-only
git lfs pull
git switch -c fix/tool-grip
```

分支按工作内容命名，例如 `feature/farming`、`fix/tool-grip`、`asset/crocodile-swim`、`docs/development-history`。

在 Issue 里写明预期效果、负责人与涉及文件。任务状态使用“待处理”“进行中”“待验收”“已完成”。模型、二进制主场景和 Word 文档同一时间由约定负责人修改，交接后再继续编辑。

创建 Issue 后，在右侧 Projects 中选择“深渊岛开发管理”，再到开发看板安排状态。负责人通过 Assignees 指派。

## 放置文件

- 功能代码放到 `游戏/scripts` 对应模块。
- 游戏加载的资源放到 `游戏/assets` 对应分类。
- 可编辑模型归入 `素材/06_游戏场景资产`，采用的动作原件归入 `素材/07_动作源文件`。
- 新下载、待筛选的资源先放 `素材/05_待选资源库`。
- 实机截图、制作资料和验收记录按现有专题目录保存。
- `.uid`、`.import` 设置和素材许可随对应资源一起提交。
- 本机缓存、引擎、导出产物、旧版压缩归档和凭据由 `.gitignore` 排除。

详细目录约定见根目录 `00_项目目录说明.txt`。模型交接需说明单位、尺寸、正面方向、握持点、骨骼层级、动画名称和导出路径。

## 提交与合并

提交前先检查文件列表，避免混入同目录下的其他工作。

```powershell
git status --short
git add <本次修改的文件或目录>
git diff --cached --stat
python 工具/版本管理/检查仓库.py
git diff --cached --check
git commit -m "fix: 修正工具握持方向"
git push -u origin HEAD
```

首次使用 Git 时，为当前仓库设置自己的提交姓名与邮箱。团队成员各自使用自己的身份。

Pull Request 写清改了什么、如何验证、关联 Issue 和需要接手的人。涉及画面、模型与动作时附实机截图或录屏。涉及存档时检查旧存档载入、操作中断及重复操作。验收通过后合并到 `main`，合并后删除已完成的功能分支。

LFS 配置由 `.gitattributes` 管理。新增大型资源类型时，先补充 LFS 规则再添加文件。删除工作区旧文件后，Git 历史仍会保留已提交版本，LFS 存储量也会随历史版本累计。

## 本地运行核验

完成资源导入后，可以通过同版本 Godot 的命令行运行依赖检查。路径按自己的安装位置调整。

```powershell
& './工具/Godot_4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path './游戏' --script '../工具/项目整理/核验运行资源.gd' -- '../整理记录/运行诊断/运行资源核验.json'
```

仓库自动检查负责文件与版本管理配置。提交人仍需从游戏正常入口验证本次玩法，记录实际结果。

## 发布版本

1. 在 `main` 合并准备交付的修改，确认仓库检查通过。
2. 同步 `project.godot`、导出预设中的版本号和 `CHANGELOG.md`。
3. 双击“一键导出Windows.cmd”，等待导入和导出完成。
4. 从源工程目录之外运行导出游戏，检查日志、存档、中文显示和本次改动。
5. 压缩整个 Windows 发布目录，保留 EXE、PCK、操作说明与许可证，计算 SHA256。
6. 为通过核验的提交建立版本标签，创建 Release，附游戏压缩包、校验值和更新说明。

当前 `v0.2.0` 对应现有游戏版本和已核验的 Windows 游戏包。首次建立仓库的日期为 2026 年 11 月 12 日。
