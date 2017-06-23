#Requires -module RCIS-Command
<#
    .SYNOPSIS
    zService module provides windows orchestration for windows services
    
    .DESCRIPTION
    A simple wrapper for WebAdministration cmdlets with usefull features to start/stop sites and apppools on remote servers.
    
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
$defaultDisplaySet = "ComputerName","Name","State","ServerAutoStart"
$defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet(‘DefaultDisplayPropertySet’,[string[]]$defaultDisplaySet)
$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
#Modules do not inherit the $Global scope which sets command defaults for the user session via RCIS-Command
#This will clone those settings (Proxy Settings and Powershell Remoting settings for IncluePortinSPN
$PSDefaultParameterValues=$Global:PSDefaultParameterValues.clone()
#endregion


#region Functions
#Define all local script functions.
Function get-zWebSite
    {
        <#
            .SYNOPSIS
            Get-zWebSite connects to a remote machine returns details regarding IIS Web Sites for orchestration
            
            .DESCRIPTION
            Returns a powershell object/collection containing IIS website details on a remote machine.
            
            .Parameter ComputerName
            Supply the computer name to collect scheduled task information from.  This can be provided from the pipeline.  Single computernames and arrays are excepted however hostnames must be fully qualified domain names.
            
            .Parameter Name
            The name of the website to collect information on.
            
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
        [alias("Site","Website")]
        [string[]]$Name="*",
        [parameter(Mandatory=$true)]
        [pscredential]$credential
        )
        
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -last 1).command
                foreach($server in $ComputerName)
                    {
                        
                        foreach($site in $Name)
                            {
                                #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                                if($PSCmdlet.ShouldProcess("$($server) $($name)",$function))
                                    {
                                            $report =Invoke-Command -ComputerName $server -HideComputerName -Credential $credential -ArgumentList $site -ScriptBlock {
                                                param($site)
                                                import-module $pshome\modules\webadministration
                                                $website=get-website -name $site | select name,id,serverautostart,state,physicalpath,applicationpool
                                                $website
                                            }
                                    }
                                if($report -ne $null)
                                    {
                                        $report=$report | ConvertTo-zObject -TypeName "zWebSites"
                                        $report | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                        $report | Add-Member -MemberType MemberSet -name PSStandardMembers $PSStandardMembers -Force
                                        $report
                                    }
                            }
                    }
            }
        End{}
    }

Function stop-zWebSite
    {
        <#
            .SYNOPSIS
            Stop-zWebSite connects to a remote machine stops a running IIS Web Site for orchestration
            
            .DESCRIPTION
            Returns a powershell object/collection containing IIS website details of shutdown website on a remote machine.
            
            .Parameter ComputerName
            Supply the computer name to stop a specified web site on.  This can be provided from the pipeline.  Single computernames and arrays are excepted however hostnames must be fully qualified domain names.
            
            .Parameter Name
            The name of the website to stop.
            
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
        [alias("Site","Website")]
        [string[]]$Name="*",
        [parameter(Mandatory=$true)]
        [pscredential]$credential
        )
        
        Process
            {  
                #Used to print a sensible WHATIF message              
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -last 1).command
                
                #Support an array of servers being passed to the function
                foreach($server in $ComputerName)
                    {
                        #support an array of sites passed to the function
                        foreach($site in $Name)
                            {
                                #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblock must be used
                                if($PSCmdlet.ShouldProcess("$($server) $($name)",$function))
                                    {
                                            $report =Invoke-Command -ComputerName $server -HideComputerName -Credential $credential -ArgumentList $site -ScriptBlock {
                                                param($site)
                                                import-module $pshome\modules\webadministration
                                                
                                                Try
                                                    {
                                                        $website=Stop-Website -name $site -Passthru
                                                        $website | select name,id,serverautostart,state,physicalpath,applicationpool
                                                    }
                                                Catch
                                                    {
                                                        Write-Error "Unable to stop website $site on $($env:Computername)"
                                                        Return
                                                    }
                                            }
                                    }

                                #Powershell remoting deserializes native objects and cannot easily be modified (alternate views or additional properties)
                                #Lets recast the object to a PSCustomObject and then tweak it for our needs.
                                if($report -ne $null)
                                    {
                                        $report=$report | ConvertTo-zObject -TypeName "zWebSites"
                                        $report | Add-Member -Name ComputerName -MemberType NoteProperty -Value $server
                                        $report | Add-Member -MemberType MemberSet -name PSStandardMembers $PSStandardMembers -Force
                                        $report
                                    }
                            }
                    }
            }
        End{}
    }

Function start-zWebSite
    {
        <#
            .SYNOPSIS
            Start-zWebSite connects to a remote machine and starts IIS Web Sites for orchestration
            
            .DESCRIPTION
            Starts and returns a powershell object/collection containing IIS websiteson a remote machine.
            
            .Parameter ComputerName
            Supply the computer name to start web sites on.  This can be provided from the pipeline.  Single computernames and arrays are excepted however hostnames must be fully qualified domain names.
            
            .Parameter Name
            The name of the website to start.
            
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

        #Support WHATIF
        [cmdletbinding(SupportsShouldProcess=$true)]
        
        param(
        
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName,
        
        [parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [alias("Site","Website")]
        [string[]]$Name="*",
        
        [parameter(Mandatory=$true)]
        [pscredential]$credential
        )
        
        Process
            {
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -last 1).command
                foreach($server in $ComputerName)
                    {
                        
                        foreach($site in $Name)
                            {
                                #Whatif parameter support is not natively supported for Invoke-Command, so this IF scriptblockr must be used
                                if($PSCmdlet.ShouldProcess("$($server) $($name)",$function))
                                    {
                                            $report =Invoke-Command -ComputerName $server -HideComputerName -Credential $credential -ArgumentList $site -ScriptBlock {
                                                param($site)
                                                import-module $pshome\modules\webadministration
                                                
                                                Try
                                                    {
                                                        $website=Start-Website -name $site -Passthru
                                                        $website | select name,id,serverautostart,state,physicalpath,applicationpool
                                                    }
                                                Catch
                                                    {
                                                        Write-Error "Unable to start website $site on $($env:Computername)"
                                                        Return
                                                    }
                                            }
                                    }
                                if($report -ne $null)
                                    {
                                        $report=$report | ConvertTo-zObject -TypeName "zWebSites"
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
    return "IISSite"
}

Function get-zTaskParameters
    {
        <#
        .Description
        Get-zTaskParameters returns a hashtable listing the valid actions for this module.
        #>
        $task_parameters=@{}
        $task_parameters.attributes=@("ComputerName","Name","Credential")
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
                switch($task.action)
                    {
                        "start"
                            {
                                $function_name="Start-zWebSite"
                                break
                            }
                        "stop"
                            {
                                $function_name="Stop-zWebSite"
                                break
                            }
                        default {Throw "Invalid action $($task.action) specified in $($task.name) of play $($play.name)."}
                    }
                
                If($validate)
                    {
                        $Return=Get-zParameters $function_name
                        if(-not(Test-zParameters -parameters $return -task $task))
                        {Throw "Error parsing task $($task.name) in play $($play.name)`n$($task.outerxml)"}
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
Export-ModuleMember -Function Get-zWebSite
Export-ModuleMember -Function Start-zWebSite
Export-ModuleMember -Function Stop-zWebSite
Export-ModuleMember -Function Get-zTask
Export-ModuleMember -Function get-zTaskParameters
Export-ModuleMember -Function Invoke-zTask
#endregion








