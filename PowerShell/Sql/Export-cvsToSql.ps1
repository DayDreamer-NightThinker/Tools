
[CmdletBinding()]
param(
    [string] $ServerName ,
    [string] $Database ,
    [string] $userName ,
    [string] $password ,
    [string] $inputFile,
    [string] $table 

)
Write-Host ">> cvsToSQL ServerName s $ServerName u $userName p $password "

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ( ! (Test-Path -path  $inputFile  -PathType Leaf  )) {
    Write-Host ">> no merge "
    exit 0
}
$ret = import-csv -path $inputFile  

$query = "insert into " + $table + " "  
$ret | select-object -First 1 | % { 
    $V = '(';  
    ( Get-Member -InputObject $_ -MemberType NoteProperty | % { $V += $($_.Name) + "," } );
    $V = $V -replace "\,$"
    $V += ')'
    $query += $V
}

$query += ' values '
Import-Module SqlServer

1..[math]::ceiling($ret.count / 1000) | % { 
    $queryValue = "";
    $skip = ($_ - 1) * 1000 ;
    $ret | select-object  -skip $skip -First 1000 | % {
        $V = ' ('  
        $Me = $_
        ( Get-Member -InputObject $_ -MemberType NoteProperty | % { $V += "'" + ( $Me.$($_.Name) -replace "'", "''") + "'," } );
        $V = $V -replace "\,$"
        $V += '),'
        $queryValue += $V	
    }

    $excquery = $query + ($queryValue -replace '\,$')
    
    $qresult = Invoke-Sqlcmd -ServerInstance $ServerName -Database $Database -Username $userName -Password $password -Query $excquery
    

}    




