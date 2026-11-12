param([string]$OutputFolder='')
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$engine=Join-Path $projectRoot '工具\Godot_4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$templateRoot=Join-Path $projectRoot '工具\Godot_4.7.2\export_templates\4.7.2.stable'
if(-not (Test-Path -LiteralPath $engine)){throw '缺少附带的 Godot 4.7.2 编辑器'}
if(-not (Test-Path -LiteralPath (Join-Path $templateRoot 'windows_release_x86_64.exe'))){throw '缺少 Windows 导出模板'}
$fontFile=Join-Path $projectRoot '游戏\assets\fonts\NotoSansSC-Regular.otf'
if(-not (Test-Path -LiteralPath $fontFile) -or (Get-Item -LiteralPath $fontFile).Length -lt 1024){throw '随包中文字体缺失或不完整'}
if(-not $OutputFolder){$OutputFolder=Join-Path $projectRoot '发布\Windows'}
$OutputFolder=[IO.Path]::GetFullPath($OutputFolder)
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$stageRoot=Join-Path $projectRoot ('_build\windows_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
$stageGame=Join-Path $stageRoot '游戏'
New-Item -ItemType Directory -Path $stageGame -Force | Out-Null
$utf8=New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path (Split-Path $stageRoot) '.gdignore'),'',$utf8)
[IO.File]::WriteAllText((Join-Path $OutputFolder '.gdignore'),'',$utf8)
$gameSource=Join-Path $projectRoot '游戏'
& robocopy $gameSource $stageGame /E /XD (Join-Path $gameSource '.godot') (Join-Path $gameSource 'addons\.godot_ai_update') /XF 'export_credentials.cfg' /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
if($LASTEXITCODE -ge 8){throw "复制运行工程失败 $LASTEXITCODE"}
# 已有导入缓存可以复用 原工程没有缓存时 Godot 会自动重建
$imported=Join-Path $gameSource '.godot\imported'
if(Test-Path -LiteralPath $imported){
  & robocopy $imported (Join-Path $stageGame '.godot\imported') /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
  if($LASTEXITCODE -ge 8){throw '复制导入缓存失败'}
  foreach($cacheName in @('global_script_class_cache.cfg','uid_cache.bin')){
    $cacheFile=Join-Path $gameSource ('.godot\'+$cacheName)
    if(Test-Path -LiteralPath $cacheFile){Copy-Item -LiteralPath $cacheFile -Destination (Join-Path $stageGame ('.godot\'+$cacheName))}
  }
}
$settingsFile=Join-Path $stageGame 'project.godot'
$settings=[IO.File]::ReadAllText($settingsFile)
$settings=[regex]::Replace($settings,'(?m)^_mcp_game_helper=.*\r?\n','')
$settings=[regex]::Replace($settings,'(?m)^enabled=PackedStringArray\([^\r\n]*\)','enabled=PackedStringArray()')
if($settings -notmatch '(?m)^config/use_custom_user_dir='){
  $settings=$settings.Replace('config/name="深渊岛"',"config/name=`"深渊岛`"`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"ShenyuanIsland`"")
}
[IO.File]::WriteAllText($settingsFile,$settings,$utf8)
$presetsFile=Join-Path $stageGame 'export_presets.cfg'
$presets=[IO.File]::ReadAllText($presetsFile)
foreach($buildType in @('debug','release')){
  $template=(Join-Path $templateRoot ('windows_'+$buildType+'_x86_64.exe')).Replace('\','/')
  $presets=[regex]::Replace($presets,'(?m)^custom_template/'+$buildType+'=.*$',('custom_template/'+$buildType+'="'+$template+'"'))
}
[IO.File]::WriteAllText($presetsFile,$presets,$utf8)
Write-Host '正在准备资源 首次导入可能需要几分钟'
& $engine --headless --path $stageGame --import --log-file (Join-Path $stageRoot 'import.log') *> (Join-Path $stageRoot 'import_console.log')
if($LASTEXITCODE -ne 0){throw 'Godot 导入失败 请查看 _build 中的 import.log'}
if(Select-String -LiteralPath (Join-Path $stageRoot 'import.log') -Pattern '^ERROR:|^SCRIPT ERROR:' -Quiet){throw '资源导入报告错误 请查看 _build 中的 import.log'}
Write-Host '正在导出 Windows 独立版'
& $engine --headless --path $stageGame --export-release 'Windows 独立版' (Join-Path $OutputFolder 'ShenyuanIsland.exe') --log-file (Join-Path $stageRoot 'export.log') *> (Join-Path $stageRoot 'export_console.log')
if($LASTEXITCODE -ne 0){throw 'Godot 导出失败 请查看 _build 中的 export.log'}
if(Select-String -LiteralPath (Join-Path $stageRoot 'export.log') -Pattern '^ERROR:|^SCRIPT ERROR:' -Quiet){throw '资源导出报告错误 请查看 _build 中的 export.log'}
$launch="@echo off`r`nchcp 65001 >nul`r`ncd /d `"%~dp0`"`r`nstart `"`" `"%~dp0ShenyuanIsland.exe`"`r`n"
[IO.File]::WriteAllText((Join-Path $OutputFolder '开始游戏.cmd'),$launch,$utf8)
$credits=Join-Path $OutputFolder '许可证与素材说明'
New-Item -ItemType Directory -Path $credits -Force | Out-Null
foreach($license in @('LICENSE.txt','COPYRIGHT.txt')){Copy-Item -LiteralPath (Join-Path $projectRoot ('工具\Godot_4.7.2\'+$license)) -Destination (Join-Path $credits ('Godot_'+$license))}
Copy-Item -LiteralPath (Join-Path $projectRoot '游戏\assets\licenses\THIRD_PARTY_CREDITS.txt') -Destination $credits
$fontLicense=Join-Path $projectRoot '游戏\assets\fonts\OFL.txt'
if(Test-Path -LiteralPath $fontLicense){Copy-Item -LiteralPath $fontLicense -Destination (Join-Path $credits 'NotoSansSC_OFL.txt')}
$instructions=@'
深渊岛 0.2.0 Windows 独立试玩版

先完整解压本文件夹，再双击“开始游戏.cmd”或 ShenyuanIsland.exe。
ShenyuanIsland.pck 必须与 EXE 放在一起，请勿只发送 EXE。
无需安装 Godot、Blender、Python、MCP，也不需要联网。
适用于 Windows 10/11 64 位以及支持 Vulkan 的显卡和相应驱动。
首次启动需要加载资源与编译着色器，请等候进入游戏。

WASD 移动，Shift 加速，右键360度旋转视角，滚轮缩放镜头，V切换俯视。
E与选中的物体交互。鼠标悬停出现白边，左键选择目标。
P人物面板，B/I背包。工具可从背包拖入下方五格栏，数字键1至5快速装备，再按同键收起。
水中Ctrl下沉，空格上浮。小地图内滚轮缩放，左键拖动，M打开大地图。
农耕、狩猎、烹饪、商人委托和沙滩车操作详见随包“操作说明.txt”。
正常模式天气自动变化；设置中开启创造模式后才可选择天气。
存档保存在当前 Windows 用户的 %APPDATA%\ShenyuanIsland 中。
本版包含农耕、生活、狩猎和商人委托的可运行流程。
'@
[IO.File]::WriteAllText((Join-Path $OutputFolder '先读我.txt'),$instructions,$utf8)
Copy-Item -LiteralPath (Join-Path $gameSource '运行说明.txt') -Destination (Join-Path $OutputFolder '操作说明.txt')
Write-Host ('导出完成 '+$OutputFolder)
[IO.File]::WriteAllText((Join-Path $OutputFolder '构建信息.txt'),('Shenyuan Island 0.2.0'+"`r`nGodot 4.7.2.stable.official.ed1daf0bf`r`nWindows x86_64 Release`r`n"+'Build '+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')+"`r`n"),$utf8)
