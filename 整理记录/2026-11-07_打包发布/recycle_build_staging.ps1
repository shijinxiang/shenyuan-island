$ErrorActionPreference='Stop'
Add-Type -AssemblyName Microsoft.VisualBasic
$stagingFolders=@('D:\浪费GPT额度\小温的游戏\_build','D:\浪费GPT额度\深渊岛_交付_2026-11-07\_打包工作')
$basePath='D:\浪费GPT额度\'
$records=@()
foreach($stagingFolder in $stagingFolders){
    if(-not (Test-Path -LiteralPath $stagingFolder)){continue}
    $resolvedFolder=(Resolve-Path -LiteralPath $stagingFolder).Path
    if($resolvedFolder -ne $stagingFolder -or -not $resolvedFolder.StartsWith($basePath,[StringComparison]::OrdinalIgnoreCase)){throw '临时目录范围校验失败'}
    $item=Get-Item -LiteralPath $resolvedFolder -Force
    if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw '不能处理重解析目录'}
    $active=Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*' -and $_.CommandLine -like ('*'+$resolvedFolder+'*') }
    if($active){throw '临时目录仍被Godot使用'}
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($resolvedFolder,[Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,[Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
    $records+=[PSCustomObject]@{Path=$resolvedFolder;Action='Sent to Recycle Bin';Restorable=$true}
}
$records | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot '临时构建清理.json') -Encoding utf8
$records | Format-Table -AutoSize
