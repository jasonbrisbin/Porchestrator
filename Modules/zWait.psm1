#Requires -module RCIS-Command
<#
    .SYNOPSIS
    zWait module does exactly what it sounds like.....it makes you wait until a specified time or duration.
    
    .DESCRIPTION
    zWait is a simple wrapper for Start-Sleep allowing a time or duration to wait to be specified.
    
    .NOTES
    Author:   Jason Brisbin
    Version:  .1
    Date:     6/23/2016
    
    .LINK
    
    .ROLE
    Development
#>

#region Parameters
#endregion

#region Initialize
#Module Variables

#Create and Configure a default display set
$defaultDisplaySet = "ComputerName","Name","ProcessID","ReturnValue"
$defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet(‘DefaultDisplayPropertySet’,[string[]]$defaultDisplaySet)
$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

#Modules do not inherit the $Global scope which sets command defaults for the user session via RCIS-Command
#This will clone those settings (Proxy Settings and Powershell Remoting settings for IncluePortinSPN
$PSDefaultParameterValues=$Global:PSDefaultParameterValues.clone()

#endregion


#region Functions
#Define all local script functions.

Function wait-zTime
    {
        <#
            .SYNOPSIS
            Wait-zTime is used to pause a script until a designated time
            
            .DESCRIPTION
            Suspends processing by putting the thread to sleep
            
            .Parameter Time
            Supply the time to resume.
            
            .Examples
            wait-zTime -Time "8:40pm"

            Causes the current executing thread to sleep until 8:40 pm of the current day.

            .NOTES
            Author:   Jason Brisbin
            Version:  .1
            Date:     6/21/2016
            
            .LINK
            
            .ROLE
            Development
        #>
        [cmdletbinding(SupportsShouldProcess=$true)]
        param
        (      

            [parameter(Mandatory=$true,ParameterSetName="Time")]            
            [string]$Time,

            [parameter(Mandatory=$true,ParameterSetName="Seconds")]            
            [string]$Seconds,

            #Not Used
            #All tasks will contain a name for status reporting and
            #a computername to target.  This function affects the client machine
            [string]$Name, 

            #Not Used
            #All tasks will contain a name for status reporting and
            #a computername to target.  This function affects the client machine instead of a taget machine.
            [string[]]$Computername
        )
        
        Begin
            {
                if($time)
                {
                    $resumetime=get-date "$Time"
                    $seconds=($resumetime - (get-date)).TotalSeconds    
                }
                elseif($seconds)
                {
                    $resumetime=(get-date).AddSeconds($seconds)                
                }
            }
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command      
                if($resumetime -lt (get-date))
                {
                    Throw "The specified time $resumetime has already passed"
                }
               if($PSCmdlet.ShouldProcess("Wait until $($resumetime)",$function))
                {
                    Write-Verbose "Processing will be suspended until $($resumetime)"
                    
                    start-sleep -Seconds $seconds
                    
                    $script=(Get-PSCallStack |select -last 1).scriptname
                    Write-Verbose "Resuming $($script)"
                }                             
            }
        
        End
            {}
    }


Function get-zTask
{
return "Wait"
}

Function get-zTaskParameters
    {
        <#
        .Description
        Get-zTaskParameters returns a hashtable listing the valid actions for this module.
        #>
        $task_parameters=@{}
        $task_parameters.attributes=@("ComputerName","Name","Time","Seconds")
        $task_parameters.actions=@("Wait")
        return $task_parameters
    }


function Invoke-zTask
    {
        [cmdletbinding(SupportsShouldProcess=$true)]
        Param(
        [system.object]$task,
        
        [system.object]$play,
        
        [parameter(mandatory=$false)]
        [alias("Credential")]
        [pscredential]$cred,
        
        [switch]$Validate
        )
        Begin
            {
                If ($PSBoundParameters['Debug'])
                {
                    $DebugPreference = 'Continue'
                }
            }
        Process
            {
                $servers=$task.computername.split(",")
                $params=@{}
                $params.whatif = $WhatIfPreference
                if($task.time){$params.time=$task.time}
                elseif($task.seconds){$params.seconds=$task.seconds}
                switch($task.localname)
                    {
                        "wait"
                            {
                                $function_name="Wait-zTime"
                                break
                            }
                        default {Throw "Invalid action $($task.action) specified in $($task.name) of play $($play.name)."}
                    }
                
                If($validate)
                    {
                        $Return=Get-zParameters $function_name
                        if(-not(Test-zParameters -parameters $return -task $task))
                        {Throw "Error parsing task $($task.name) in play $($play.name)"}
                    }
                Else
                    {
                        $Return=Invoke-Expression "$function_name @params"
                        $return | output-zobject -play $play -task $task
                    }                             
            }
    }

#region Script
#Main script which performs all desired activities and calls functions as needed.
Export-ModuleMember -Function wait-zTime
Export-ModuleMember -Function Get-zTask
Export-ModuleMember -Function Get-zTaskParameters
Export-ModuleMember -Function Invoke-zTask
#endregion



