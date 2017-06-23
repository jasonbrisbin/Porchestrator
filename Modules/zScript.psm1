#Requires -module RCIS-Command
<#
    .SYNOPSIS
    zScript module provides windows orchestration for powershell scripts
    
    .DESCRIPTION
    A simple wrapper for working with powershell scripts remotely
    
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
$defaultDisplaySet = "ComputerName","ServiceName","DisplayName","Status","StartupType"
$defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet(‘DefaultDisplayPropertySet’,[string[]]$defaultDisplaySet)
$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
#Modules do not inherit the $Global scope which sets command defaults for the user session via RCIS-Command
#This will clone those settings (Proxy Settings and Powershell Remoting settings for IncluePortinSPN
$PSDefaultParameterValues=$Global:PSDefaultParameterValues.clone()

#endregion


#region Functions
#Define all local script functions.

Function start-zScript
    {
        <#
            .SYNOPSIS
            Starts a script on a remote server
            
            .DESCRIPTION
            Runs the specified script on the remote server.
            
            .Parameter ComputerName
            Supply the computer name to target.  This can be provided from the pipeline.  Single computernames and arrays are excepted however hostnames must be fully qualified domain names.
            
            .Parameter Path
            Specify the local path for the script

            .Parameter Arguments
            Specify optional arguments to be provided to the script
                        
            .Parameter Credential
            Provide alternate credentials to make the connection to the remote machine.
            
            .NOTES
            Author:   Jason Brisbin
            Version:  .1
            Date:     6/21/2016
            
            .LINK
            
            .ROLE
            Development
        #>
        [cmdletbinding(SupportsShouldProcess=$true)]
        param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName,
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$path="",
        [string]$arguments,
        [parameter(Mandatory=$true)]
        [pscredential]$credential,
        [parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [alias("Process")]
        [string]$Name="*"
        )
        
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -last 1).command
                foreach($server in $ComputerName)
                    {
                        #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                        if($PSCmdlet.ShouldProcess("$($server) $($path)",$function))
                            {
                                    $process_arguments=@{}
                                    $process_arguments.filepath=$path
                                    $process_arguments.computername=$server
                                    $process_arguments.credential=$credential
                                    if($arguments){$process_arguments.argumentlist=$arguments}                                    
                                    $report=Invoke-Command @process_arguments
                                    $report

                            }
                    }
            }
        End{}
    }
Function get-zTask
{
    return "Script"
}

Function get-zTaskParameters
    {
        <#
        .Description
        Get-zTaskParameters returns a hashtable listing the valid actions for this module.
        #>
        $task_parameters=@{}
        $task_parameters.attributes=@("ComputerName","Name","Credential","path","arguments")
        $task_parameters.actions=@("Start")
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
                $servers=@()
                $server_list=$task.computername.split(",")
                Foreach($item in $server_list)
                {
                    if(Test-IsAlive -ComputerName $item -credential $cred)
                        {
                            $servers+=$item  
                        }
                        else
                        {
                            Write-Warning "$server is not accessible and will be skipped for play $($play.name)."
                            continue
                        }              
                }
                if($servers.count -eq 0)
                {
                    out-message -type warning -destination all -message "There are no servers that are accessible for play $($play.name)."
                    return
                }
                $params=@{}
                $params.name = $task.name
                $params.computername = $servers
                $params.credential = $cred
                $params.whatif = $WhatIfPreference
                $params.path=$task.path
                $params.arguments=$task.arguments
                switch($task.action)
                    {
                        "start"
                            {
                                $function_name="Start-zScript"
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
Export-ModuleMember -Function Start-zScript
Export-ModuleMember -Function Get-zTask
Export-ModuleMember -Function get-zTaskParameters
Export-ModuleMember -Function Invoke-zTask
#endregion



