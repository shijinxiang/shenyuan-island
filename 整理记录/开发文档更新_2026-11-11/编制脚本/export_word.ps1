$ErrorActionPreference = 'Stop'
$documentWork = Split-Path $PSScriptRoot
$documentFolder = Join-Path $documentWork '成稿'
$renderFolder = Join-Path $documentWork '排版核验'
$wordApplication = New-Object -ComObject Word.Application
$wordApplication.Visible = $false
$wordApplication.DisplayAlerts = 0
$results = @()
try {
    foreach ($documentFile in Get-ChildItem -LiteralPath $documentFolder -Filter '*.docx' -File) {
        Write-Output ('Opening ' + $documentFile.Name)
        $wordDocument = $wordApplication.Documents.Open($documentFile.FullName, $false, $false)
        try {
            $wordDocument.Repaginate()
            $wordDocument.Fields.Update() | Out-Null
            foreach ($contents in $wordDocument.TablesOfContents) { $contents.Update() }
            $wordDocument.Repaginate()
            foreach ($contents in $wordDocument.TablesOfContents) { $contents.UpdatePageNumbers() }
            $wordDocument.Save()
            $pdfDirectory = Join-Path $renderFolder $documentFile.BaseName
            New-Item -ItemType Directory -Path $pdfDirectory -Force | Out-Null
            $pdfFile = Join-Path $pdfDirectory ($documentFile.BaseName + '.pdf')
            $wordDocument.ExportAsFixedFormat($pdfFile, 17)
            $results += [PSCustomObject]@{
                Name = $documentFile.Name
                Pages = $wordDocument.ComputeStatistics(2)
                Images = $wordDocument.InlineShapes.Count
                PDF = $pdfFile
                TOC = $wordDocument.TablesOfContents.Count
            }
            Write-Output ('Exported ' + $documentFile.Name)
        } finally { $wordDocument.Close(0) }
    }
} finally { $wordApplication.Quit() }
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $documentWork 'Word导出记录.json') -Encoding utf8
$results | Format-Table Name, Pages, Images, TOC -AutoSize
