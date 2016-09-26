
<#

Author: I. Strachan
Version:
Version History:

Purpose: Get Active Directory Report Unit tests and send notification to Slack

#>

#region import module and saved credentials/tokens
Import-Module PSSlack

#Jaap Brassers blog on saving credentials. Saved slack's token as a password
#http://www.jaapbrasser.com/quickly-and-securely-storing-your-credentials-powershell/
$savedCreds = Import-CliXml -Path "${env:\userprofile}\Hash.Cred"
$token = $savedCreds.'udm-slack'.GetNetworkCredential().Password
$exportDate = Get-Date -Format ddMMyyyy
#endregion

#region Main 
$pesterADDS = Invoke-Pester $PSScriptRoot\AD.Operations*  -OutputFile $PSScriptRoot\ADConfiguration.NUnit.xml -OutputFormat NUnitXml -PassThru

#run reportunit against DFSnShares.NUnit.xml and display result in browser
& .\tools\ReportUnit\reportunit.exe $PSScriptRoot\ADConfiguration.NUnit.xml
Invoke-Item $PSScriptRoot\ADConfiguration.NUnit.html

#Export Pester results to xml
$pesterADDS | Export-Clixml $PSScriptRoot\PesterResults-ADDS-$($exportDate).xml -Encoding UTF8
#endregion

#region Send Slack notification of Pester results
$iconEmoji = @{$true = ':white_check_mark:';$false=':red_circle:'}[$pesterADDS.FailedCount -eq 0]
$color = @{$true='green';$false='red'}[$pesterADDS.FailedCount -eq 0]

#SlackFields
$Fields = [PSCustomObject]@{
    Total   = $pesterADDS.TotalCount
    Passed  = $pesterADDS.PassedCount
    Failed  = $pesterADDS.FailedCount
    Skipped = $pesterADDS.SkippedCount
    Pending = $pesterADDS.PendingCount
} | New-SlackField -Short

$slackAttachments = @{
   Color      =  $([System.Drawing.Color]::$color)
   PreText    = 'AD operational readiness Results'
   AuthorName = '@irwins'
   AuthorIcon = 'https://raw.githubusercontent.com/irwins/PowerShell-scripts/master/wrench.png' 
   Fields     =  $Fields
   Fallback   = 'Your client is bad'
   Title      = 'Pester counts'
   TitleLink  = 'https://www.youtube.com/watch?v=IAztPZBQrrU'
   Text       = @{$true='Everything passed';$false='Check failed tests'}[$pesterADDS.FailedCount -eq 0]
}

New-SlackMessageAttachment @slackAttachments |
New-SlackMessage -Channel 'pester' -IconEmoji $iconEmoji -AsUser -Username '@irwins' |
Send-SlackMessage -Token $token
#endregion