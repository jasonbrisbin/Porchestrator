#Requires -module RCIS-Command
<#
    .SYNOPSIS
    zService module provides windows orchestration for windows services
    
    .DESCRIPTION
    A simple wrapper for xxx-service cmdlets with usefull features to enable/disable/start/stop scheduled tasks on remote servers.
    
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

Function start-zProcess
    {
        <#
            .SYNOPSIS
            Starts a process on a remote server
            
            .DESCRIPTION
            Returns a powershell object/collection containing scheduled tasks details on a remote machine.
            
            .Parameter ComputerName
            Supply the computer name to collect scheduled task information from.  This can be provided from the pipeline.  Single computernames and arrays are excepted however hostnames must be fully qualified domain names.
            
            .Parameter Name
            The name of the scheduled task to collect information on.
            
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

        [parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [alias("Process")]
        [string]$Name="*",

        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$commandline="",

        [string]$workingdirectory="",

        [parameter(Mandatory=$true)]
        [pscredential]$credential
        )
        
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command
                foreach($server in $ComputerName)
                    {
                        #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                        if($PSCmdlet.ShouldProcess("$($server) $($process)",$function))
                            {
                                    <#
                                    $scriptblock={
                                        param($path,$arguments,$wait,$workingdirectory)
                                        $process_arguments=@{}
                                        $process_arguments.filepath="`"$path`""
                                        $process_arguments.passthru=$true
                                        $process_arguments.wait=$true
                                        if($arguments){$process_arguments.argumentlist=$arguments}
                                        if($workingdirectory){$process_arguments.workingdirectory=$workingdirectory}
                                        if($wait){$process_arguments.wait=$true}
                                        $process_arguments
                                        Try
                                        {
                                        start-transcript
                                            Start-Process @process_arguments 
                                            Stop-Transcript                                       
                                        }
                                        Catch
                                        {
                                             Write-Error "Unable to start process $path on $($env:Computername)"
                                             Return
                                        }}
                                    $report=Invoke-Command -ComputerName $server -HideComputerName -Credential $credential -ArgumentList $path,$arguments,$wait,$workingdirectory -ScriptBlock $scriptblock
                                    $report
                                #>
                                $arguments=@{}
                                $arguments.commandline=$commandline
                                if($workingdirectory){$arguments.currentdirectory=$workingdirectory}
                                $CimSessions=New-CimSession -ComputerName $server -Credential $credential -Verbose:$false
                                $result=Invoke-CimMethod -CimSession $CimSessions –ClassName Win32_Process –MethodName "Create" –Arguments $arguments -Verbose:$false
                                $result=ConvertTo-zObject -InputObject $result -TypeName "zProcess"
                                $result | Add-Member -Name Name -MemberType NoteProperty -Value $name
                                $result | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                $result | Add-Member MemberSet PSStandardMembers $PSStandardMembers
                                $result
                            }
                    }
            }
        End{}
    }

Function stop-zProcess
    {
        <#
            .SYNOPSIS
            Starts a process on a remote server
            
            .DESCRIPTION
            Returns a powershell object/collection containing scheduled tasks details on a remote machine.
            
            .Parameter ComputerName
            Supply the computer name to collect scheduled task information from.  This can be provided from the pipeline.  Single computernames and arrays are excepted however hostnames must be fully qualified domain names.
            
            .Parameter Name
            The name of the scheduled task to collect information on.
            
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

        [parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [alias("Process")]
        [string]$Name="*",
        
        [parameter(Mandatory=$false)]
        [AllowNull()]
        [string]$workingdirectory,
        
        [parameter(Mandatory=$false)]
        [AllowNull()]
        [string]$commandline,

        [parameter(Mandatory=$true)]
        [pscredential]$credential
        )
        
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command
                foreach($server in $ComputerName)
                    {
                        #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                        if($PSCmdlet.ShouldProcess("$($server) $($process)",$function))
                            {                                                                    
                                $CimSessions=New-CimSession -ComputerName $server -Credential $credential -Verbose:$false
                                $ProcessList = Get-CimInstance -CimSession $CimSessions -ClassName Win32_Process -Filter "Name = '$name'";
                                if([string]::IsNullOrEmpty($ProcessList))
                                {
                                    write-warning "No process named $Name was found."
                                    $result=New-Object psobject -Property @{
                                        name=$Name
                                        processid=-1
                                    }
                                    $result = ConvertTo-zObject -InputObject $result -TypeName "zProcess"                            
                                }
                                else
                                {
                                    $result = $ProcessList | Invoke-CimMethod -CimSession $CimSessions –MethodName "Terminate" -Verbose:$false
                                    $result = ConvertTo-zObject -InputObject $result -TypeName "zProcess"                                
                                    $result | Add-Member -Name ProcessID -MemberType NoteProperty -Value 0 -Force
                                }
                                
                                $result | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                $result | Add-Member MemberSet PSStandardMembers $PSStandardMembers    
                                $result
                            }
                    }
            }
        End{}
    }


Function get-zProcess
    {
        <#
            .SYNOPSIS
            Starts a process on a remote server
            
            .DESCRIPTION
            Returns a powershell object/collection containing scheduled tasks details on a remote machine.
            
            .Parameter ComputerName
            Supply the computer name to collect scheduled task information from.  This can be provided from the pipeline.  Single computernames and arrays are excepted however hostnames must be fully qualified domain names.
            
            .Parameter Name
            The name of the scheduled task to collect information on.
            
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

        [parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [alias("Process")]
        [string]$Name="*",

        [parameter(Mandatory=$false)]
        [AllowNull()]
        [string]$workingdirectory,
        
        [parameter(Mandatory=$false)]
        [AllowNull()]
        [string]$commandline,

        [parameter(Mandatory=$true)]
        [pscredential]$credential
        )
        
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command
                foreach($server in $ComputerName)
                    {
                        #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                        if($PSCmdlet.ShouldProcess("$($server) $($process)",$function))
                            {                                    
                                $arguments=@{}
                                $arguments.commandline=$commandline
                                if($workingdirectory){$arguments.currentdirectory=$workingdirectory}
                                $CimSessions=New-CimSession -ComputerName $server -Credential $credential -Verbose:$false
                                $result = Get-CimInstance -ClassName Win32_Process;                                
                                $result=ConvertTo-zObject -InputObject $result -TypeName "zProcess"
                                $result | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                $result | Add-Member MemberSet PSStandardMembers $PSStandardMembers
                                $result
                            }
                    }
            }
        End{}
    }

Function get-zTask
{
return "Process"
}

Function get-zTaskParameters
    {
        <#
        .Description
        Get-zTaskParameters returns a hashtable listing the valid actions for this module.
        #>
        $task_parameters=@{}
        $task_parameters.attributes=@("ComputerName","Name","Credential","workingdirectory","commandline")
        $task_parameters.actions=@("Start","Stop")
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
                $params.workingdirectory=$task.workingdirectory
                $params.commandline=$task.commandline
                switch($task.action)
                    {
                        "start"
                            {
                                $function_name="Start-zProcess"
                                break
                            }
                        "stop"
                            {
                                $function_name="Stop-zProcess"
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
Export-ModuleMember -Function Start-zProcess
Export-ModuleMember -Function Stop-zProcess
Export-ModuleMember -Function Get-zProcess
Export-ModuleMember -Function Get-zTask
Export-ModuleMember -Function get-zTaskParameters
Export-ModuleMember -Function Invoke-zTask
#endregion



