$ErrorActionPreference = 'Stop'
$assetRoot = [IO.Path]::GetFullPath('D:\浪费GPT额度\小温的游戏\素材')
$recordRoot = Join-Path $assetRoot '99_资产清单与整理记录'
$plan = Get-Content -LiteralPath (Join-Path $recordRoot '整理计划.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$oldRoot = [IO.Path]::GetFullPath($plan.old_root)
if ($oldRoot -ne (Join-Path $assetRoot 'Blender模型')) { throw 'Unexpected old root' }
function Assert-InRoot([string]$target, [string]$rootPath) {
    $full = [IO.Path]::GetFullPath($target)
    if (-not $full.StartsWith($rootPath.TrimEnd('\')+'\', [StringComparison]::OrdinalIgnoreCase)) { throw "Outside intended root: $full" }
    if (Test-Path -LiteralPath $full) {
        $actual = (Resolve-Path -LiteralPath $full).Path
        if (-not $actual.StartsWith($rootPath.TrimEnd('\')+'\', [StringComparison]::OrdinalIgnoreCase)) { throw "Resolved outside root: $actual" }
        if ((Get-Item -LiteralPath $full -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point not allowed: $full" }
    }
    return $full
}
$sceneCheck = Get-Content -LiteralPath (Join-Path $recordRoot '整岛替换检查.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $sceneCheck.terrain_and_building_geometry_unchanged) { throw 'Scene preservation check failed' }
foreach ($name in @('深渊岛_当前场景.blend','深渊岛_当前场景.glb')) {
    $file = Get-Item -LiteralPath (Join-Path $assetRoot ('02_整岛场景\'+$name))
    if ($file.Length -lt 1000000) { throw 'Missing scene output' }
}
if (-not (Test-Path -LiteralPath (Join-Path $recordRoot '保留模型贴图检查.json'))) { throw 'Missing retained texture audit' }
foreach ($asset in $plan.assets) {
    $null = Assert-InRoot $asset.model $assetRoot
    if (-not (Test-Path -LiteralPath $asset.model -PathType Leaf)) { throw 'Missing formal model' }
    $hash = (Get-FileHash -LiteralPath $asset.model -Algorithm SHA256).Hash
    if ($hash -ne $asset.sha256) { throw "Formal model hash mismatch: $($asset.id)" }
    if ($asset.source -eq '用户新模型') {
        $null = Assert-InRoot $asset.original_file $assetRoot
        if ((Get-FileHash -LiteralPath $asset.original_file -Algorithm SHA256).Hash -ne $asset.sha256) { throw 'User original hash mismatch' }
    }
}
# Validate every target before the first mutation.
foreach ($target in $plan.delete_old_paths) { $null = Assert-InRoot $target $oldRoot }
foreach ($entry in $plan.moves) {
    $null = Assert-InRoot $entry.src $assetRoot
    $null = Assert-InRoot $entry.dst $assetRoot
    if (Test-Path -LiteralPath $entry.dst) { throw "Destination already exists: $($entry.dst)" }
}
$audit = [Collections.Generic.List[object]]::new()
foreach ($target in $plan.delete_old_paths) {
    if (Test-Path -LiteralPath $target) {
        $item=Get-Item -LiteralPath $target
        $files=if($item.PSIsContainer){@(Get-ChildItem -LiteralPath $target -File -Recurse)}else{@($item)}
        $audit.Add([pscustomobject]@{action='delete_replaced_old';path=$target;files=$files.Count;bytes=($files|Measure-Object Length -Sum).Sum})
        Remove-Item -LiteralPath $target -Recurse -Force
    }
}
foreach ($entry in $plan.moves) {
    if (Test-Path -LiteralPath $entry.src) {
        $null = New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($entry.dst))
        Move-Item -LiteralPath $entry.src -Destination $entry.dst
        $audit.Add([pscustomobject]@{action='move_preserved';from=$entry.src;to=$entry.dst})
    }
}
foreach ($asset in $plan.assets) {
    if ($asset.source -eq '用户新模型') {
        if ((Get-FileHash -LiteralPath $asset.model -Algorithm SHA256).Hash -ne $asset.sha256) { throw 'Final original preservation check failed' }
        Remove-Item -LiteralPath $asset.original_file -Force
        $audit.Add([pscustomobject]@{action='relocate_user_original_verified';from=$asset.original_file;to=$asset.model;sha256=$asset.sha256})
    }
}
if ((Get-ChildItem -LiteralPath $oldRoot -Force | Measure-Object).Count -eq 0) { Remove-Item -LiteralPath $oldRoot }
$audit | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $recordRoot '实际删除与移动记录.json') -Encoding UTF8
Write-Output ('COMMITTED actions=' + $audit.Count)
