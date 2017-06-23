#Requires -module RCIS-Command
<#
    .SYNOPSIS
    zSchedueldTasks modules provides windows orchestration for scheduled tasks.
    
    .DESCRIPTION
    Uses the Schedule.Service COM interface to enable/disable/start/stop scheduled tasks on remote servers.
    
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
$defaultDisplaySet = 'ComputerName','Name','State','Enabled'
$defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet(‘DefaultDisplayPropertySet’,[string[]]$defaultDisplaySet)
$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
#Modules do not inherit the $Global scope which sets command defaults for the user session via RCIS-Command
#This will clone those settings (Proxy Settings and Powershell Remoting settings for IncluePortinSPN
$PSDefaultParameterValues=$Global:PSDefaultParameterValues.clone()
$PSSessionOption = New-PSSessionOption -OpenTimeOut 20000 -CancelTimeOut 20000 -IdleTimeOut 20000

#endregion

#region Functions
#Define all module functions.



Function Get-zScheduledTask
    {
        <#
            .SYNOPSIS
            Get-zSchedueldTasks connects to a remote machine returns details regarding Scheduled Tasks
            
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

        [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$Name="*",

        [parameter(Mandatory=$true)]
        [pscredential]$credential,

        [parameter(ValueFromPipeline=$false)]
        [switch]$Raw

        )
        
        Process
            {
                foreach($server in $ComputerName)
                    {
                            $scriptblock={
                                
                                param($name)
                                function get-taskfolders
                                {
                                    [cmdletbinding()]
                                    Param(
                                    [parameter(ValueFromPipeline=$true,Mandatory=$true)]
                                    [string]$folder
                                    )
                                    Process
                                    {
                                        $value=$schedule_Service.GetFolder("$folder").getfolders(1) | select -ExpandProperty Path

                                        if([string]::IsNullOrEmpty($value)){return $folder}
                                        else{$value | get-taskfolders}
                                    }
                                }
                                function get-tasks
                                {
                                    [cmdletbinding()]
                                    Param(
                                    [parameter(ValueFromPipeline=$true,Mandatory=$true)]
                                    [string]$folder
                                    )
                                    Process
                                    {
                                        $value=$schedule_Service.GetFolder("$folder").gettasks(1)

                                        if([string]::IsNullOrEmpty($value)){return}
                                        else{return $value}
                                    }
                                }
                                Try
                                    {
                                        $schedule_Service = New-Object -ComObject Schedule.Service
                                        $schedule_Service.Connect()
                                    }
                                Catch
                                    {
                                        Write-Error "Unable to create or connect to COMObject Schedule.Service"
                                        return
                                    }
                                Try
                                    {
                                                                            
                                        $schedule_folders=get-taskfolders -folder '\'
                                        $schedule_folders+='\'
                                        $schedule_folders | get-tasks | where{$_.name -like $name}
                                        #($schedule_Service.GetFolder("")).gettasks("") | where{$_.name -like $name}
                                        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($schedule_Service) | out-null
                                        Remove-Variable schedule_Service | out-null
                                    }
                                Catch
                                    {
                                        Write-Error "Unable to get list of scheduled tasks"
                                        return
                                    }
                                
                                
                            }
                        $scheduled_tasks=Invoke-Command -HideComputerName -ComputerName $server -ErrorAction Continue -Credential $credential -ScriptBlock $scriptblock -ArgumentList $name
                        if($raw){return $scheduled_tasks}
                        if($scheduled_tasks -ne $null)
                            {
                                $scheduled_tasks=foreach($item in $scheduled_tasks)
                                    {
                                        switch($item.state)
                                            {
                                                "0" {$item.state = "Unknown"}
                                                "1" {$item.state = "Disabled"}
                                                "2" {$item.state = "Queued"}
                                                "3" {$item.state = "Ready"}
                                                "4" {$item.state = "Running"}
                                            }
                                        ConvertTo-zObject -InputObject $item -TypeName "zScheduledTask"
                                    }
                                $scheduled_tasks | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                $scheduled_tasks | Add-Member MemberSet PSStandardMembers $PSStandardMembers
                                $scheduled_tasks
                            }
                    }
            }
    }

Function Stop-zScheduledTask
    {
        <#
            .SYNOPSIS
            Stop-zSchedueldTasks connects to a remote machine returns details regarding Scheduled Tasks
            
            .DESCRIPTION
            Stops the specified scheduled task on a remote machine.
            
            .Parameter ComputerName
            Supply the computer name to stop scheduled task on.  This can be either from the pipeline, specified directly as an array, or as a single computername however ALL hostnames must be fully qualified domain names.
            
            .Parameter Name
            The name of the scheduled task to stop.
            
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
        [alias("PSComputerName")]
        [string[]]$ComputerName,
        [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$Name="*",
        [parameter(Mandatory=$true)]
        [pscredential]$credential
        )
        
        Process
            {
            $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command
                foreach($server in $ComputerName)
                    {
                        
                            $scriptblock={
                                param($name)
                                Try
                                    {
                                        $schedule_Service = New-Object -ComObject Schedule.Service
                                        $schedule_Service.Connect()
                                    }
                                Catch
                                    {
                                        Write-Error "Unable to create or connect to COMObject Schedule.Service"
                                        return
                                    }
                                
                                Try
                                    {
                                        $change_task_list=($schedule_Service.GetFolder("")).gettasks("") | where{($_.name -like $name)}
                                    }
                                Catch
                                    {
                                        Write-Error "Unable to get list of scheduled tasks"
                                        return
                                    }
                                
                                foreach($change_task in $change_task_list)
                                    {
                                        if($change_task.state -eq 4)
                                        {
                                            try
                                                {
                                                    $change_task.Stop(0) | out-null
                                                    $change_task
                                                }
                                            catch
                                                {
                                                    Write-Error "An error occurred trying to stop $($change_task.name) on $($server)"
                                                }
                                        }
                                        Else
                                        {
                                            $change_task
                                        }
                                        
                                    }
                                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($schedule_Service) | out-null
                                Remove-Variable schedule_Service
                            }
                        
                        
                        if($PSCmdlet.ShouldProcess("$($server) $($name)","$function"))
                            {
                                $scheduled_tasks=Invoke-Command -HideComputerName -ComputerName $Computername -Credential $credential -ErrorAction Continue -ArgumentList $name -ScriptBlock $scriptblock
                                
                                if($scheduled_tasks -ne $null)
                                    {
                                        $scheduled_tasks=foreach($item in $scheduled_tasks)
                                            {
                                                switch($item.state)
                                                    {
                                                        "0" {$item.state = "Unknown"}
                                                        "1" {$item.state = "Disabled"}
                                                        "2" {$item.state = "Queued"}
                                                        "3" {$item.state = "Ready"}
                                                        "4" {$item.state = "Running"}
                                                    }
                                                ConvertTo-zObject -InputObject $item -TypeName "zScheduledTask"
                                            }
                                        $scheduled_tasks | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                        $scheduled_tasks | Add-Member MemberSet PSStandardMembers $PSStandardMembers
                                        $scheduled_tasks
                                    }
                            }
                        
                    }
                }
                }

Function Start-zScheduledTask
    {
                        <#
                            .SYNOPSIS
                            Start-zSchedueldTasks connects to a remote machine returns details regarding Scheduled Tasks
                            
                            .DESCRIPTION
                            Starts the specified scheduled task on a remote machine.
                            
                            .Parameter ComputerName
                            Supply the computer name to start scheduled task on.  This can be either from the pipeline, specified directly as an array, or as a single computername however ALL hostnames must be fully qualified domain names.
                            
                            .Parameter Name
                            The name of the scheduled task to start.
                            
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
                        [alias("PSComputerName")]
                        [string[]]$ComputerName,
                        [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                        [string]$Name="*",
                        [parameter(Mandatory=$true)]
                        [pscredential]$credential
                        )
                        
                        Process
                            {
                            $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command
                                foreach($server in $ComputerName)
                                    {
                                            $scriptblock={
                                                param($name)
                                                Try
                                                    {
                                                        $schedule_Service = New-Object -ComObject Schedule.Service
                                                        $schedule_Service.Connect()
                                                    }
                                                Catch
                                                    {
                                                        Write-Error "Unable to create or connect to COMObject Schedule.Service"
                                                        return
                                                    }
                                                Try
                                                    {
                                                        $change_task_list=($schedule_Service.GetFolder("")).gettasks("") | where{($_.name -like $name)}
                                                        
                                                    }
                                                Catch
                                                    {
                                                        Write-Error "Unable to get list of scheduled tasks"
                                                        return
                                                    }
                                                foreach($change_task in $change_task_list)
                                                    {
                                                       if($change_task.state -eq 3) 
                                                       {
                                                            try
                                                                {
                                                                    $change_task.Run(0) | out-null
                                                                    $change_task
                                                                }
                                                            catch
                                                                {
                                                                    Write-Error "An error occurred trying to start $($change_task.name) on $($server)`n"
                                                                }
                                                        }
                                                        Else
                                                        {
                                                            $change_task
                                                        }
                                                    }
                                                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($schedule_Service) | out-null
                                                Remove-Variable schedule_Service
                                            }
                                        
                                        if($PSCmdlet.ShouldProcess("$($server) $($name)","$function"))
                                            {
                                                $scheduled_tasks=Invoke-Command -HideComputerName -ComputerName $server -Credential $credential -ErrorAction Continue -ScriptBlock $scriptblock -ArgumentList $name
                                                if($scheduled_tasks -ne $null)
                                                    {
                                                        $scheduled_tasks=foreach($item in $scheduled_tasks)
                                                            {
                                                                switch($item.state)
                                                                    {
                                                                        "0" {$item.state = "Unknown"}
                                                                        "1" {$item.state = "Disabled"}
                                                                        "2" {$item.state = "Queued"}
                                                                        "3" {$item.state = "Ready"}
                                                                        "4" {$item.state = "Running"}
                                                                    }
                                                                ConvertTo-zObject -InputObject $item -TypeName "zScheduledTask"
                                                            }
                                                        $scheduled_tasks | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                                        $scheduled_tasks | Add-Member MemberSet PSStandardMembers $PSStandardMembers
                                                        $scheduled_tasks
                                                    }
                                            }
                                    }
                                
                            }
                    }
                
Function Enable-zScheduledTask
    {
                        <#
                            .SYNOPSIS
                            Enable-zSchedueldTasks connects to a remote machine and enables the specified Scheduled Tasks
                            
                            .DESCRIPTION
                            Enables the specified scheduled task on a remote machine.
                            
                            .Parameter ComputerName
                            Supply the computer name to Enable scheduled task on.  This can be either from the pipeline, specified directly as an array, or as a single computername however ALL hostnames must be fully qualified domain names.
                            
                            .Parameter Name
                            The name of the scheduled task to Enable.
                            
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
                        [alias("PSComputerName")]
                        [string[]]$ComputerName,
                        [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                        [string]$Name="*",
                        [parameter(Mandatory=$true)]
                        [pscredential]$credential
                        )
                        
                        Process
                            {
                            $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command
                                foreach($server in $ComputerName)
                                    {
                                        
                                            $scriptblock={
                                                param($name)
                                                Try
                                                    {
                                                        $schedule_Service = New-Object -ComObject Schedule.Service
                                                        $schedule_Service.Connect()
                                                    }
                                                Catch
                                                    {
                                                        Write-Error "Unable to create or connect to COMObject Schedule.Service"
                                                        return
                                                    }
                                                Try
                                                    {
                                                        $change_task_list=($schedule_Service.GetFolder("")).gettasks("") | where{($_.name -like $name)}
                                                    }
                                                Catch
                                                    {
                                                        Write-Error "Unable to get list of scheduled tasks"
                                                        return
                                                    }
                                                foreach($change_task in $change_task_list)
                                                    {
                                                    if($change_task.state -eq 1)
                                                    {
                                                        try
                                                            {
                                                                $change_task.Enabled=$true
                                                                $change_task
                                                            }
                                                        catch
                                                            {
                                                                Write-Error "An error occurred trying to enable $($change_task.name) on $($server)`n"
                                                            }
                                                    }
                                                    Else
                                                    {
                                                        $change_task
                                                    }
                                                    }
                                                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($schedule_Service) | out-null
                                                Remove-Variable schedule_Service
                                            }
                                        
                                        
                                        if($PSCmdlet.ShouldProcess("$($server) $($name)","$function"))
                                            {
                                                $scheduled_tasks=Invoke-Command -HideComputerName -ComputerName $server -Credential $credential -ErrorAction Continue -ScriptBlock $scriptblock -ArgumentList $name
                                                
                                                if($scheduled_tasks -ne $null)
                                                    {
                                                        $scheduled_tasks=foreach($item in $scheduled_tasks)
                                                            {
                                                                switch($item.state)
                                                                    {
                                                                        "0" {$item.state = "Unknown"}
                                                                        "1" {$item.state = "Disabled"}
                                                                        "2" {$item.state = "Queued"}
                                                                        "3" {$item.state = "Ready"}
                                                                        "4" {$item.state = "Running"}
                                                                    }
                                                                ConvertTo-zObject -InputObject $item -TypeName "zScheduledTask"
                                                            }
                                                        $scheduled_tasks | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                                        $scheduled_tasks | Add-Member MemberSet PSStandardMembers $PSStandardMembers
                                                        $scheduled_tasks
                                                    }
                                            }
                                    }
                                
                            }
                    }
                
Function Disable-zScheduledTask
    {
                        <#
                            .SYNOPSIS
                            Disable-zSchedueldTasks connects to a remote machine and disables specified Scheduled Tasks
                            
                            .DESCRIPTION
                            Disables the specified scheduled task on a remote machine.
                            
                            .Parameter ComputerName
                            Supply the computer name to Disable scheduled task on.  This can be either from the pipeline, specified directly as an array, or as a single computername however ALL hostnames must be fully qualified domain names.
                            
                            .Parameter Name
                            The name of the scheduled task to Disable.
                            
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
                        [alias("PSComputerName")]
                        [string[]]$ComputerName,
                        [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                        [string]$Name="*",
                        [parameter(Mandatory=$true)]
                        [pscredential]$credential
                        )
                        
                        Process
                            {
                            $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command
                                foreach($server in $ComputerName)
                                    {
                                        
                                            $scriptblock={
                                                param($name)
                                                $server=$env:COMPUTERNAME
                                                Try
                                                    {
                                                        $schedule_Service = New-Object -ComObject Schedule.Service
                                                        $schedule_Service.Connect()
                                                    }
                                                Catch
                                                    {
                                                        Write-Error "Unable to create or connect to COMObject Schedule.Service"
                                                        return
                                                    }
                                                
                                                Try
                                                    {
                                                        $change_task_list=$schedule_Service.GetFolder("").gettasks("") | where{($_.name -like $name)}
                                                    }
                                                Catch
                                                    {
                                                        Write-Error "Unable to get list of scheduled tasks"
                                                        return
                                                    }
                                                foreach($change_task in $change_task_list)
                                                    {
                                                        try
                                                            {
                                                                $change_task.Enabled=$false
                                                                $change_task
                                                            }
                                                        catch
                                                            {
                                                                Write-Error "An error occurred trying to disable $($change_task.name) on $($server)`n"
                                                            }
                                                        
                                                    }
                                                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($schedule_Service) | out-null
                                                Remove-Variable schedule_Service
                                            }
                                        
                                        
                                        if($PSCmdlet.ShouldProcess("$($server) $($name)","$function"))
                                            {
                                                $scheduled_tasks=Invoke-Command -HideComputerName -ComputerName $server -Credential $credential -ErrorAction Continue -ScriptBlock $scriptblock -ArgumentList $name
                                                if($scheduled_tasks -ne $null)
                                                    {
                                                        $scheduled_tasks=foreach($item in $scheduled_tasks)
                                                            {
                                                                switch($item.state)
                                                                    {
                                                                        "0" {$item.state = "Unknown"}
                                                                        "1" {$item.state = "Disabled"}
                                                                        "2" {$item.state = "Queued"}
                                                                        "3" {$item.state = "Ready"}
                                                                        "4" {$item.state = "Running"}
                                                                    }
                                                                ConvertTo-zObject -InputObject $item -TypeName "zScheduledTask"
                                                            }
                                                        $scheduled_tasks | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                                        $scheduled_tasks | Add-Member MemberSet PSStandardMembers $PSStandardMembers
                                                        $scheduled_tasks
                                                    }
                                            }
                                    }
                                
                            }
                    }

Function get-zTask
{
    return "ScheduledTask"
}

Function get-zTaskParameters
    {
        <#
        .Description
        Get-zTaskParameters returns a hashtable listing the valid actions for this module.
        #>
        $task_parameters=@{}
        $task_parameters.attributes=@("ComputerName","Name","Credential")
        $task_parameters.actions=@("Start","Stop","Enable","Disable")
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
                            Write-Warning "$item is not accessible and will be skipped for play $($play.name)."
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
                switch($task.action)
                    {
                        "stop" {$function_name="Stop-zScheduledTask";break}
                        "disable" {$function_name="Disable-zScheduledTask";break}
                        "enable" {$function_name="Enable-zScheduledTask";break}
                        "start" {$function_name="Start-zScheduledTask";break}
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
#endregion
                
                
#region Script
#Main script which performs all desired activities and calls functions as needed.
Export-ModuleMember -Function Get-zScheduledTask
Export-ModuleMember -Function Start-zScheduledTask
Export-ModuleMember -Function Stop-zScheduledTask
Export-ModuleMember -Function Enable-zScheduledTask
Export-ModuleMember -Function Disable-zScheduledTask
Export-ModuleMember -Function Get-zTask
Export-ModuleMember -Function get-zTaskParameters
Export-ModuleMember -Function Invoke-zTask
#endregion
                
                

