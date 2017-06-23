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
$defaultDisplaySet = "ComputerName","ServiceName","DisplayName","Status","StartupType"
$defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet(‘DefaultDisplayPropertySet’,[string[]]$defaultDisplaySet)
$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

#Modules do not inherit the $Global scope which sets command defaults for the user session via RCIS-Command
#This will clone those settings (Proxy Settings and Powershell Remoting settings for IncluePortinSPN
$PSDefaultParameterValues=$Global:PSDefaultParameterValues.clone()
#endregion


#region Functions
#Define all local script functions.
Function get-zService
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
        [parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [alias("ServiceName")]
        [string[]]$Name="*",
        [AllowNull()]
        [string]$action,
        [parameter(Mandatory=$true)]
        [pscredential]$credential
        )
        
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command
                foreach($server in $ComputerName)
                    {
                        
                        
                                #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                                if($PSCmdlet.ShouldProcess("$($server) $($service)",$function))
                                    {                                        
                                        $service_list=Invoke-Command -ComputerName $server -HideComputerName -Credential $credential -ArgumentList $name -ScriptBlock {
                                            param($name)
                                            $current_service=get-service -Name $name
                                            $current_service
                                        }
                                        
                                        
                                        $report=foreach($service in $service_list)
                                        {
                                        if($service -ne $null)
                                            {
                                                $service=$service | ConvertTo-zObject -TypeName "zService"
                                                
                                                #Windows 2008 Does not have a startmode
                                                if($service.startmode -eq $null)
                                                    {
                                                        Try
                                                        {
                                                            $startup=(Get-WmiObject -Class win32_service -ComputerName $server -Credential $credential | where{$_.name -eq $service}).startmode
                                                        }
                                                        Catch
                                                        {
                                                            out-message -type Error -destination all -message "$_.exception" -action Continue
                                                            $startup="Error"
                                                        }
                                                
                                                        $service | Add-Member -name StartMode -MemberType NoteProperty -Value $startup
                                                        $service | Add-Member -name StartupType -MemberType NoteProperty -Value $startup
                                                    }
                                                $service | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                                $service | Add-Member -MemberType MemberSet -name PSStandardMembers $PSStandardMembers -Force
                                                $service
                                            }
                                        $report
                                    }                            
                            }                        
                    }
            }
        End{}
    }

Function start-zService
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
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [alias("ServiceName")]
        [string[]]$Name,
        [AllowNull()]
        [string]$action,
        [parameter(Mandatory=$true)]
        [pscredential]$credential
        )
        
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command
                foreach($server in $ComputerName)
                    {                        
                        foreach($service in $Name)
                            {
                                #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                                if($PSCmdlet.ShouldProcess("$($server) $($service)",$function))
                                    {
                                            $report=Invoke-Command -ComputerName $server -Authentication Kerberos -HideComputerName -Credential $credential -ArgumentList $service -ScriptBlock {
                                                param($service)
                                                $current_service=get-service -Name $service
                                                if($current_service.StartType -eq "disabled")
                                                    {
                                                        #out-message -type error -destination all -message "Service $service is currently set to disabled on $($env:Computername) and can not be started."
                                                        out-message -message  "Service $service is currently set to disabled on $($env:Computername) and can not be started." -type Error -destination All
                                                        Return
                                                    }
                                                Try
                                                    {
                                                        $status=Start-Service -Name $service -PassThru
                                                    }
                                                Catch
                                                    {
                                                        #out-message -type error -destination all -message "Unable to start service $service on $($env:Computername)"
                                                        out-message -message  "Unable to start service $service on $($env:Computername)" -type Error -destination All
                                                        Return
                                                    }
                                                Try
                                                    {
                                                        $status.WaitForStatus('Running',(New-TimeSpan -seconds 30))
                                                    }
                                                Catch
                                                    {
                                                        #out-message -type error -destination all -message "Starting service $service timed out on $($env:Computername)"
                                                        out-message -message  "Starting service $service timed out on $($env:Computername)" -type Error -destination All
                                                        Return
                                                    }
                                                $status
                                            }
                                    }
                                if($report -ne $null)
                                    {
                                        $report=ConvertTo-zObject -InputObject $report -TypeName "zService"
                                        
                                        #Windows 2008 Does not have a startmode
                                        if($report.startmode -eq $null)
                                            {
                                                Try
                                                {
                                                    $startup=(Get-WmiObject -Class win32_service -ComputerName $server -Credential $credential | where{$_.name -eq $service}).startmode
                                                }
                                                Catch
                                                {
                                                    out-message -type Error -destination all -message "$_.exception" -action Continue
                                                    $startup="Error"
                                                }                                                
                                                $report | Add-Member -name StartMode -MemberType NoteProperty -Value $startup
                                                $report | Add-Member -name StartupType -MemberType NoteProperty -Value $startup
                                            }
                                        $report | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                        $report | Add-Member -MemberType MemberSet -name PSStandardMembers $PSStandardMembers -Force
                                        $report
                                    }
                            }
                    }
            }
        End{}
    }

Function stop-zService
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
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [alias("ServiceName")]
        [string[]]$Name,
        [AllowNull()]
        [string]$action,
        [parameter(Mandatory=$true)]
        [pscredential]$credential
        )
        
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command
                foreach($server in $ComputerName)
                    {
                        
                        foreach($service in $Name)
                            {
                                #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                                if($PSCmdlet.ShouldProcess("$($server) $($service)",$function))
                                    {
                                            $report=Invoke-Command -ComputerName $server -HideComputerName -Credential $credential -ArgumentList $service -ScriptBlock {
                                                param($service)
                                                $current_service=get-service -Name $service -ErrorAction Stop
                                                Try
                                                    {
                                                        $status=Stop-Service -Name $service -PassThru -force
                                                    }
                                                Catch
                                                    {
                                                        out-message -type error -destination all -message "Unable to stop service $service on $($env:Computername)"
                                                        Return
                                                    }
                                                Try
                                                    {
                                                        $status.WaitForStatus('Stopped',(New-TimeSpan -seconds 30))
                                                    }
                                                Catch
                                                    {
                                                        out-message -type error -destination all -message "Stopping service $service timed out on $($env:Computername)"
                                                        Return
                                                    }
                                                $status
                                            }
                                    }
                                if($report -ne $null)
                                    {
                                        $report=ConvertTo-zObject -InputObject $report -TypeName "zService"
                                        
                                        #Windows 2008 Does not have a startmode
                                        if($report.startmode -eq $null)
                                            {
                                              Try
                                                {
                                                    $startup=(Get-WmiObject -Class win32_service -ComputerName $server -Credential $credential | where{$_.name -eq $service}).startmode
                                                }
                                                Catch
                                                {
                                                    out-message -type Error -destination all -message "$_.exception" -action Continue
                                                    $startup="Error"
                                                }
                                                
                                                $report | Add-Member -name StartMode -MemberType NoteProperty -Value $startup
                                                $report | Add-Member -name StartupType -MemberType NoteProperty -Value $startup
                                            }
                                        $report | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                        $report | Add-Member -MemberType MemberSet -name PSStandardMembers $PSStandardMembers -Force
                                        $report
                                    }
                            }
                    }
            }
        End{}
    }

Function set-zService
    {
        <#
            .SYNOPSIS
            Set-zSchedueldTasks connects to a remote machine modified the StartMode.
            
            .DESCRIPTION
            Sets the service StartupType/StartMode on target machines.
            
            .Parameter ComputerName
            Supply the computer name to collect scheduled task information from.  This can be provided from the pipeline.  Single computernames and arrays are excepted however hostnames must be fully qualified domain names.
            
            .Parameter Name
            The name of the service to modify
            
            .Parameter Action
            Specify Automatic, Disabled, Boot, System, or Manual
            
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
        [alias("ServiceName")]
        [string[]]$Name,
        [parameter(Mandatory=$true)]
        [validateset("Automatic","Disable","Boot","System","Manual")]
        [string]$action,
        [parameter(Mandatory=$true)]
        [pscredential]$credential
        )
        
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command
                foreach($server in $ComputerName)
                    {
                        
                        foreach($service in $Name)
                            {
                                #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                                if($PSCmdlet.ShouldProcess("$($server) $($service)",$function))
                                    {
                                            $report=Invoke-Command -ComputerName $server -HideComputerName -Credential $credential -ArgumentList $service,$action -ScriptBlock {
                                                param($service,$action)
                                                $current_service=get-service -Name $service -ErrorAction Stop
                                                Try
                                                    {
                                                        $status=set-Service -Name $service -PassThru -StartupType $action
                                                    }
                                                Catch
                                                    {
                                                        out-message -type error -destination all -message "Unable to set service $service to $action on $($env:Computername)"
                                                        Return
                                                    }
                                                $status
                                            }
                                    }
                                if($report -ne $null)
                                    {
                                        $report=ConvertTo-zObject -InputObject $report -TypeName "zService"
                                        
                                        #Windows 2008 Does not have a startmode
                                        if($report.startmode -eq $null)
                                            {
                                                Try
                                                {
                                                    $startup=(Get-WmiObject -Class win32_service -ComputerName $server -Credential $credential -ErrorVariable err -ErrorAction SilentlyContinue | where{$_.name -eq $service}).startmode
                                                    if($?){throw $err}
                                                }
                                                Catch
                                                {
                                                    out-message -type Error -destination all -message "$server $_" -action Continue
                                                    $startup="Error"
                                                }
                                                $report | Add-Member -name StartMode -MemberType NoteProperty -Value $startup
                                                $report | Add-Member -name StartupType -MemberType NoteProperty -Value $startup
                                            }
                                        $report | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                        $report | Add-Member -MemberType MemberSet -name PSStandardMembers $PSStandardMembers -Force
                                        $report
                                    }
                            }
                    }
            }
        End{}
    }

Function get-zTask
    {
        <#
        .Description
        Get-zTask returns the Task type this module will support and will be used by zEngine for request routing
        #>
        return "Service"
    }

Function get-zTaskParameters
    {
        <#
        .Description
        Get-zTaskParameters returns a hashtable listing the valid actions for this module.
        #>
        $task_parameters=@{}
        $task_parameters.attributes=@("ComputerName","Name","Credential")
        $task_parameters.actions=@("Start","Stop","Enable","Disable","Manual","Automatic")
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
                            out-message -type warning -destination all -message "$item is not accessible and will be skipped for task $($task.name) in play $($play.name)."
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
                
                #make your changes here
                switch($task.action)
                    {
                        "stop"
                            {
                                $function_name="stop-zService"
                                $params.action=$null
                                break
                            }
                        
                        "disable"
                            {
                                $function_name="set-zService"
                                $params.action="disable"
                                break
                            }
                        "enable"
                            {
                                $function_name="set-zService"
                                $params.action="manual"
                                out-message -type warning -destination all -message "'Enable' service was specified which is invalid 'Manual' will be used instead."
                                break
                            }
                        "manual"
                            {
                                $function_name="set-zService"
                                $params.action="manual"
                                break
                            }
                        "automatic"
                            {
                                $function_name="set-zService"
                                $params.action="automatic"
                                break
                            }
                        "start"
                            {
                                $function_name="start-zService"
                                $params.action=$null
                                break
                            }
                        
                        
                        default {<#you should never be here#>Throw "Invalid action $($task.action) specified in $($task.name) of play $($play.name).";exit}
                    }

                $callstack=Get-PSCallStack                
                $module=$callstack[0].ScriptName
                $message="`nTask:  $($task.outerxml)"
                $message+="`nModule:  $module"
                $message+="`nFunction:  $function_name" 
                out-message -type debug -destination all -message "$message"              
                If($validate)
                    {
                        test-zTask -task $task
                    }
                Else
                    {
                        $Return=Invoke-Expression "$function_name @params"
                        $return | output-zobject -play $play -task $task
                    }
            }
    }

Function Test-zTask
    {
        [cmdletbinding(SupportsShouldProcess=$true)]
        Param(
        [system.object]$task
        )        
        Process
            {
                $common_parameters=@("ComputerName","Name","Credential","Action")
                $function_parameters=get-zTaskParameters
                if($function_parameters.actions -contains $task.action)
                {
                    $parameters=$function_parameters.attributes
                }
                else
                {                    
                    Throw "Invalid action $($task.action) specified in $($task.name) of play $($play.name)."
                }

                Test-zParameters -task $task -parameters $parameters                
            }        
    }

#region Script
#Main script which performs all desired activities and calls functions as needed.
Export-ModuleMember -Function Get-zService
Export-ModuleMember -Function Start-zService
Export-ModuleMember -Function Stop-zService
Export-ModuleMember -Function Set-zService
Export-ModuleMember -Function Resolve-zService
Export-ModuleMember -Function Get-zTask
Export-ModuleMember -Function Get-zTaskParameters
Export-ModuleMember -Function Invoke-zTask
#endregion










