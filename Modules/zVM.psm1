#Requires -module RCIS-Command
#requires -module zHelper
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
$defaultDisplaySet = "ComputerName","PowerState","Version","Cluster"
$defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet(‘DefaultDisplayPropertySet’,[string[]]$defaultDisplaySet)
$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
#endregion


#region Functions
#Define all local script functions.
Function connect-zVM
{
    Param(
    [parameter(mandatory=$true)]
    [alias("Credential")]
    [pscredential]$cred
    )
    Import-Module VMware.VimAutomation.Core -Global -verbose:$false #These are the modules you are looking for.
    if(!($?)){Throw "Unable to load VMware PowerCLI module. It may not be installed on this computer. Script cannot continue."; Exit 1}

    #Set some powercli default configurations that make scripting output much cleaner
    $params=@{}
    $params.DefaultVIServerMode="Multiple"
    $params.InvalidCertificateAction="Ignore"
    $params.DisplayDeprecationWarnings=$false
    $params.Scope="Session"
    $params.confirm=$false
    Try{Set-PowerCliConfiguration @params | Out-Null}
    Catch{Write-Error "An error occured with the VMWare module. You must close your Powershell Host and restart this script." -ErrorAction Stop}
    $viserver=($VarStore.technologies.vmware.vcenter | where {$_.site -eq "Anoka"}).name
    connect-viserver -Server $viserver -credential $cred -Debug:$false -warningaction SilentlyContinue | out-null
}


Function get-zVM
    {
        <#
            .SYNOPSIS
            Get-zVM return VM status information from VMWare
            
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
        [string[]]$ComputerName="*",
        [parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$action,
        [parameter(Mandatory=$true)]
        [pscredential]$credential
        )
        
        Begin
            {
                
            }
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -last 1).command
                foreach($server in $ComputerName)
                    {
                        if($server -match ".com"){$server=$server.split(".")[0]}
                        #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                        if($PSCmdlet.ShouldProcess("$($server) $($service)",$function))
                            {
                                Try
                                {
                                $report=get-vm -name $server -Debug:$false -ErrorAction SilentlyContinue -ErrorVariable vm_error
                                if($vm_error){throw $vm_error}
                                if($report -ne $null)
                                    {
                                        $report=$report | ConvertTo-zObject -TypeName "zVM"
                                        $report | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                        $report | Add-Member -Name Cluster -MemberType NoteProperty $report.VMHost.Parent
                                        $report | Add-Member -MemberType MemberSet -name PSStandardMembers $PSStandardMembers -Force
                                        $report
                                    }
                                }
                                Catch
                                {
                                    Write-Error "Unable to get VM status for $server"
                                    Return
                                }
                            }
                    }
                
            }
        
        End
            {

            }
    }

Function start-zVM
    {
        <#
            .SYNOPSIS
            Get-zVM return VM status information from VMWare
            
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
        [string[]]$ComputerName="*",

        [parameter(Mandatory=$true)]
        [pscredential]$credential,

        [switch]$wait
        )
        
        Begin
            {
               
            }
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -last 1).command
                foreach($server in $ComputerName)
                    {
                        if($server -match ".com"){$server=$server.split(".")[0]}
                        #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                        if($PSCmdlet.ShouldProcess("$($server) $($service)",$function))
                            {
                                Try
                                {
                                $report=Start-VM -VM $server -Confirm:$false -verbose:$false -ErrorAction SilentlyContinue -ErrorVariable vm_error                                                               
                                if($vm_error){throw $vm_error}
                                if($wait)
                                    {
                                        $report=wait-zVM -ComputerName $server -Credential $credential -State PoweredOn -Timeout 60 -Interval 5
                                        $report | Add-Member -MemberType MemberSet -name PSStandardMembers $PSStandardMembers -Force
                                        $report
                                    }
                                elseif($report -ne $null)
                                    {
                                        $report=$report | ConvertTo-zObject -TypeName "zVM"
                                        $report | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                        $report | Add-Member -Name Cluster -MemberType NoteProperty $report.VMHost.Parent
                                        $report | Add-Member -MemberType MemberSet -name PSStandardMembers $PSStandardMembers -Force
                                        $report
                                    }
                                }
                                Catch
                                {
                                    Write-Error $vm_error[0]
                                    Return
                                }
                            }
                    }
                
            }
        
        End
            {

            }
    }

Function stop-zVM
    {
        <#
            .SYNOPSIS
            Get-zVM return VM status information from VMWare
            
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
        [string[]]$ComputerName="*",

        [parameter(Mandatory=$true)]
        [pscredential]$credential,

        [switch]$wait
        )
        
        Begin
            {
 
            }
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -last 1).command
                foreach($server in $ComputerName)
                    {
                        if($server -match ".com"){$server=$server.split(".")[0]}
                        #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                        if($PSCmdlet.ShouldProcess("$($server) $($service)",$function))
                            {
                                Try
                                {                                
                                $task=Stop-VMGuest -VM $server -Confirm:$false -verbose:$false -ErrorAction SilentlyContinue -ErrorVariable vm_error                                                                                                
                                $report=$task.vm
                                if($vm_error){throw $vm_error}
                                if($wait)
                                    {
                                        $report=wait-zVM -ComputerName $server -Credential $credential -State PoweredOff -Timeout 60 -Interval 5
                                        $report | Add-Member -MemberType MemberSet -name PSStandardMembers $PSStandardMembers -Force
                                        $report
                                    }                                
                                elseif($report -ne $null)
                                    {
                                        $report=$report | ConvertTo-zObject -TypeName "zVM"
                                        $report | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                        $report | Add-Member -Name Cluster -MemberType NoteProperty $report.VMHost.Parent
                                        $report | Add-Member -MemberType MemberSet -name PSStandardMembers $PSStandardMembers -Force
                                        $report
                                    }
                                }
                                Catch
                                {
                                    Write-Error $vm_error[0]
                                    Return
                                }
                            }
                    }
                
            }
        
        End
            {

            }
    }

Function wait-zVM
    {
        <#
            .SYNOPSIS
            Get-zVM return VM status information from VMWare
            
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
        param
        (      
            [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [alias("VM","Guest","Name")]
            [string[]]$ComputerName,

            [parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [validateset("PoweredOn","PoweredOff")]
            [string]$State,

            [ValidateRange(1,3600)]
            [int]$Timeout=60,

            [ValidateRange(1,3600)]
            [int]$Interval=5,

            [parameter(Mandatory=$true)]
            [pscredential]$Credential        
        )
        
        Begin
            {
                $StartTime=Get-Date
            }
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -last 1).command
                foreach($server in $ComputerName)
                {
                        if($server -match ".com"){$server=$server.split(".")[0]}
                        #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                        if($PSCmdlet.ShouldProcess("$($server) $($service)",$function))
                            {
                                Try
                                {                                
                                    #Get the PowerState of 1 or Many VM's
                                    #Compare that to DesiredState ($state)
                                    #If they all match $state operation was successful
                                    #Otherwise continue to wait until the Timeout has been reached
                                    while($true)                               
                                    {
                                        $Duration=New-TimeSpan -Start $StartTime -end (get-date)
                                        if($duration.seconds -ge $timeout)
                                        {
                                            Throw "The wait operation has timed out for $($server -join ", ")"
                                            Break
                                        }
                                        Write-Verbose "Waiting for $server to be $state."                             
                                        $report=get-vm -name $server -Debug:$false -verbose:$false -ErrorAction SilentlyContinue -ErrorVariable vm_error                                
                                    
                                        if($vm_error){throw $vm_error}
                                        $currentstates=$report.powerstate | select -Unique
                                    
                                        if(($currentstates.count -eq 1) -and ($currentstates -eq $state))
                                        {
                                            Break
                                        }
                                        start-sleep -Seconds $Interval
                                    }


                                    if($report -ne $null)
                                        {
                                            $report=foreach($record in $report)
                                            {
                                                $record=$record | ConvertTo-zObject -TypeName "zVM"
                                                $record | Add-Member -Name ComputerName -MemberType NoteProperty -Value $record.name
                                                $record | Add-Member -Name Cluster -MemberType NoteProperty $record.VMHost.Parent
                                                $record | Add-Member -MemberType MemberSet -name PSStandardMembers $PSStandardMembers -Force
                                                $record
                                            }
                                            $report
                                        }
                                }
                                Catch
                                {
                                    write-error $_
                                    #Write-Error "Unable to get VM status for $($computername)"
                                    Return
                                }
                            }   
                            }                 
                
            }
        
        End
            {

            }
    }

Function disconnect-zVM
{
        
        Remove-Module -Name "VMware.VimAutomation.Core" -ErrorAction SilentlyContinue -Force
        Remove-Module -Name "VMware.VimAutomation.Sdk" -ErrorAction SilentlyContinue -Force
        Remove-PSSnapin -Name "VMware.VimAutomation.Core" -ErrorAction SilentlyContinue
}


Function get-zTask
{
    return "VM"
}

Function get-zTaskParameters
    {
        <#
        .Description
        Get-zTaskParameters returns a hashtable listing the valid actions for this module.
        #>
        $task_parameters=@{}
        $task_parameters.attributes=@("ComputerName","Name","Credential","Wait")
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
        [pscredential]$cred
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
                $params=@{}
                $params.computername = $servers
                $params.credential = $cred
                if($task.wait -eq "true"){$params.wait=$true}
                $params.whatif = $WhatIfPreference
                
                switch($task.action)
                    {
                        "stop"
                            {
                                $function_name="stop-zVM"
                                Foreach($item in $server_list)
                                    {
                                        $state=get-zVM -ComputerName $item -credential $cred
                                        if($state.powerstate -eq "PoweredOn")
                                            {
                                                $servers+=$item  
                                            }
                                            else
                                            {
                                                Write-Error "$server is already powered off and will not be shutdown again per task $($task.name) in play $($play.name)."
                                                continue
                                            }              
                                    }
                                $params.computername = $servers
                                break
                            }
                                                
                        "start"
                            {
                                $function_name="start-zVM"
                                Foreach($item in $server_list)
                                    {
                                        $state=get-zVM -ComputerName $item -credential $cred
                                        if($state.powerstate -eq "PoweredOff")
                                            {
                                                $servers+=$item  
                                            }
                                            else
                                            {
                                                Write-Error "$server is already online and will not be powered on again per task $($task.name) in play $($play.name)."
                                                continue
                                            }              
                                    }
                                $params.computername = $servers
                                break
                            }
                        
                        
                        default {<#you should never be here#>Throw "Invalid action $($task.action) specified in $($task.name) of play $($play.name).";exit}
                    }
                
                #Print Debug Information
                
                $callstack=Get-PSCallStack                
                $module=$callstack[0].ScriptName
                $message="`nTask:  $($task.outerxml)"
                $message+="`nModule:  $module"
                $message+="`nFunction:  $function_name" 
                write-debug "$message"              

                #Route message and execute     
                if($servers.count -eq 0){return}           
                $Return=Invoke-Expression "$function_name @params"
                $Return | output-zobject -play $play -task $task
            }
    }

#endregion



#region Script
#Main script which performs all desired activities and calls functions as needed.
Export-ModuleMember -Function Get-zVM
Export-ModuleMember -Function Start-zVM
Export-ModuleMember -Function Stop-zVM
Export-ModuleMember -Function Wait-zVM
Export-ModuleMember -Function disconnect-zVM
Export-ModuleMember -Function connect-zVM
Export-ModuleMember -Function Get-zTask
Export-ModuleMember -Function Invoke-zTask
Export-ModuleMember -Function Get-zTaskParameters
#endregion








