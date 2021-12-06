#

# .\parse-Kibana.ps1 -action "phrase"
#download from report, run 

[CmdletBinding()]
param(
  [string] $sourceFile , 
  [string] $outputFile ,
  [string] $action = ""
)


$tags = [Ordered]@{
  "ReqRcv"      = [PSCustomObject]@{msg = "Consuming ISaveRequestJson"; srv = "doc-srv" };
  "evaStart"    = [PSCustomObject]@{msg = "RecommendationSavedEvaluatorConsumer" ; srv = "eval-srv" };
  "evaEnd"      = [PSCustomObject]@{msg = "SendResult:" ; srv = "eval-srv" };  
}

if ( $action -eq "phrase")
{
  $phrase =@()
  $tags.GetEnumerator() | %{ $phrase+='"' + ([pscustomobject]$_.value).msg  +'"' }
  $p= $phrase -join " or "
  $p
  return 
}

$qaInput = Import-Csv -Path $sourceFile
$qaInput | ? { ($_."kubernetes.namespace_name" -match 'rbrqa') -and ($_.message -match '^CId') }  | % { $_.correlationId = ($_.message.substring(5, 36)) }


$qaInput | % {  
  if ( $_.message.LastIndexOf('elapsed') -gt 0 ) {    
    $_ | Add-Member -NotePropertyName elapsed -NotePropertyValue ($_.message.substring($_.message.LastIndexOf('elapsed') + 8, $_.message.length - ($_.message.LastIndexOf('elapsed') + 8) )  )
  }
  elseif ($_.messgae -match 'returned recommendations') {
    $_ | Add-Member -NotePropertyName elapsed -NotePropertyValue ( $_.message.substring($_.message.firstIndexOf('"'), $_.message.lastIndexOf('"') - $_.message.firstIndexOf('"') ))
  }
  else {
    $_ | Add-Member -NotePropertyName elapsed -NotePropertyValue -1
  }
}

foreach ($entry in $tags.GetEnumerator()) {
  $qaInput | ? { $_.message -match ([pscustomobject]$entry.value).msg } | % { $_ | Add-Member -NotePropertyName tag -NotePropertyValue $entry.Name }
}


$groups = $qaInput | Sort-Object -Property  @{Expression = "correlationId"; Descending = $True }, @{Expression = "@timestamp"; Descending = $False } | Select-Object -Property correlationId, '@timestamp', tag, elapsed | Group-Object -Property correlationId #-AsHashTable -AsString

$pivotedData = foreach ($grp in $groups) {

  $props = @(
    @{ Name = 'correlationId' ; Expression = { ($grp.Group | Select-Object -ExpandProperty correlationId -Unique) } }
    foreach ($entry in $tags.GetEnumerator()) {
      @{ 
        Name       = $entry.Name 
        Expression = { $grp.Group |
          Where-Object tag -eq $entry.Name |
          Select-Object -ExpandProperty '@timestamp' -ExcludeProperty correlationId, tag }.GetNewClosure()
      }
    }      
  )

  $grp | Select-Object $props
}

#$pivotedData | Format-Table
$pivotedData | Sort-Object -Property  @{Expression = "ReqRcv"; Descending = $False } | ConvertTo-Csv | Out-File $outputFile 
