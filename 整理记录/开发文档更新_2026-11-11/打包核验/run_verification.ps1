$ErrorActionPreference='Stop'
$work=Split-Path $PSScriptRoot
$results=Get-Content -LiteralPath (Join-Path $PSScriptRoot '打包结果.json') -Raw | ConvertFrom-Json
if(@($results).Count -ne 2){throw 'Both distribution packages must finish before verification'}
& 'C:\Users\SHIJINXIANG\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -X utf8 (Join-Path $work '编制脚本\verify_latest.py')
if($LASTEXITCODE -ne 0){throw 'Package or relocation verification failed'}
