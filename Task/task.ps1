#requires -RunAsAdministrator
Param(
    $name
)
$script=$MyInvocation.MyCommand.source
$parent=split-path -parent $script
$xmlfile=Join-Path $parent "task.xml"
$taskxml=[xml](get-content $xmlfile)

if($name -eq $null){$name=split-path $parent -leaf}

Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue | out-null
if(-not($?))
{
$arguments="-noprofile -file $script -name $name -windowstyle hidden"
$taskxml.task.actions.exec.Arguments = $arguments.toString()
$taskxml.task.actions.exec.workingdirectory = $parent.toString()
Register-ScheduledTask -Xml $taskxml.InnerXml -TaskName $name
Start-ScheduledTask -TaskName $name
EXIT
}

New-EventLog -source $name -LogName Application -ErrorAction SilentlyContinue
$console = $host.ui.rawUI
$console.windowtitle="ScheduledTask $name"
while($true)
{
write-eventlog -logname Application -source $name -eventID 3001 -entrytype Information -message "Generating some new information $(get-date)" -category 1
$d=get-date -f "MM/dd/yyyy hh:mm:ss"
$message=$d+" created a new event"
Write-Information -MessageData $message -InformationAction Continue
$sleeptime=Get-Random -Minimum 45 -Maximum 90
start-sleep -Seconds $sleeptime
}