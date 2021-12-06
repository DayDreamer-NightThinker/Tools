
[CmdletBinding()]
param(
    [string] $file = "",
    [string] $outFile = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$searchString = "result"

$rowStart = (Select-String -Path $file -Pattern $searchString -List ).toString().split(":")[2]
$rowLast = (Select-String -Path $file -Pattern $searchString | Select-Object -Last 1 ).toString().split(":")[2]

Write-Host ">> Get row number $rowStart  and  $rowLast"

$emptyStr = [string]::Empty
Get-content -Path $file | select-object  -Skip $rowStart -First ($rowLast - 1 - $rowStart) | % { $_ -replace 'undefined', 'null' }  |  out-file $outFile

Write-Host ">> convert $file  to  $outFile"