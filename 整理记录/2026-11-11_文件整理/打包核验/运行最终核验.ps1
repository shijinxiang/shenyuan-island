$ErrorActionPreference='Stop'
$packageProcessId=[int]([IO.File]::ReadAllText((Join-Path $PSScriptRoot '重打包进程.txt')).Trim())
$process=Get-Process -Id $packageProcessId -ErrorAction SilentlyContinue
if($process){$process.WaitForExit()}
& 'C:\Users\SHIJINXIANG\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -X utf8 (Join-Path $PSScriptRoot '核验整理后工程包.py')
if($LASTEXITCODE -ne 0){throw 'Organized source package verification failed'}
