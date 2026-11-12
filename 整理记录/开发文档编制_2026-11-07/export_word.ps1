$ErrorActionPreference='Stop'
$docWork='D:\浪费GPT额度\小温的游戏\整理记录\开发文档编制_2026-11-07'
$docFolder='D:\浪费GPT额度\小温的游戏\需求\开发过程文档'
$wordApp=New-Object -ComObject Word.Application
$wordApp.Visible=$false
$wordApp.DisplayAlerts=0
$results=@()
try {
  foreach($docFile in Get-ChildItem -LiteralPath $docFolder -Filter '*.docx' -File){
    $wordDoc=$wordApp.Documents.Open($docFile.FullName,$false,$false)
    try {
      $wordDoc.Repaginate()
      $wordDoc.Fields.Update() | Out-Null
      foreach($contents in $wordDoc.TablesOfContents){$contents.Update()}
      $wordDoc.Repaginate()
      foreach($contents in $wordDoc.TablesOfContents){$contents.UpdatePageNumbers()}
      $wordDoc.Save()
      $pdfFolder=Join-Path $docWork $docFile.BaseName
      New-Item -ItemType Directory -Path $pdfFolder -Force | Out-Null
      $pdfFile=Join-Path $pdfFolder ($docFile.BaseName+'.pdf')
      $wordDoc.ExportAsFixedFormat($pdfFile,17)
      $results+=[PSCustomObject]@{Name=$docFile.Name;Pages=$wordDoc.ComputeStatistics(2);PDF=$pdfFile;TOC=$wordDoc.TablesOfContents.Count}
    } finally {$wordDoc.Close(0)}
  }
} finally {$wordApp.Quit()}
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $docWork 'Word导出记录.json') -Encoding utf8
$results | Format-Table -AutoSize
