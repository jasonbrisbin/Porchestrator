#Requires -module zVM


Function stop-zWindows
    {
        <#
            .SYNOPSIS
            Stop-zWindows shuts down a windows machine remotely
            
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
            $sessionOptions = New-PSSessionOption -IncludePortInSPN
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command
                foreach($server in $ComputerName)
                    {                 
                        if($PSCmdlet.ShouldProcess("$($server)",$function))
                            {
                                Try
                                {   
                                    if(Test-IsAlive -ComputerName $Server -credential $credential)                             
                                    {
                                        Stop-Computer -ComputerName $server -Credential $credential -Force
                                    }
                                    else
                                    {
                                        Write-Warning "$($Server) is not accessible on the network."
                                    }
                                }
                                Catch
                                {
                                    Write-Error $_
                                    Return
                                }
                            }
                    }
                If($wait)
                {
                    foreach($server in $ComputerName)
                        {   
                            if($PSCmdlet.ShouldProcess("$($server)","Wait-zVM"))
                                {
                                    Try
                                    {                                       
                                        wait-zVM -ComputerName $server -Credential $credential -State PoweredOff -Timeout 60 -Interval 5                                                                                              
                                    }
                                    Catch
                                    {
                                        Write-Error $_
                                        Return
                                    }
                                }
                        }
                }
                
            }
        
        End
            {

            }
    }

Function start-zWindows
    {
        <#
            .SYNOPSIS
            Stop-zWindows shuts down a windows machine remotely
            
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
            $sessionOptions = New-PSSessionOption -IncludePortInSPN
                $function=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -first 1).command
                foreach($server in $ComputerName)
                    {                        
                        if($PSCmdlet.ShouldProcess("$($server)",$function))
                            {
                                Try
                                {   
                                    If(-not(Test-IsAlive -ComputerName $server -credential $credential))
                                    {
                                        Start-zVM -ComputerName $server -Credential $credential
                                    }
                                    else
                                    {
                                        Write-Warning "$($Server) is already online."
                                    }
                                }
                                Catch
                                {
                                    Write-Error $_
                                    Return
                                }
                            }
                    }
                if($wait)
                {
                foreach($server in $ComputerName)
                    {                        
                        if($PSCmdlet.ShouldProcess("$($server)","Wait-UntilAlive"))
                            {
                                Try
                                {                                       
                                    Wait-UntilAlive -ComputerName $server -Credential $credential -State $true -Timeout 60 -Interval 5
                                }
                                Catch
                                {
                                    Write-Error $_
                                    Return
                                }
                            }
                    }
                }
                
            }
        
        End
            {

            }
    }

Function get-zTask
    {
        <#
        .Description
        Get-zTask returns the Task type this module will support and will be used by zEngine for request routing
        #>
        return "Windows"
    }

Function get-zTaskParameters
    {
        <#
        .Description
        Get-zTaskParameters returns a hashtable listing the valid actions for this module.
        #>
        $task_parameters=@{}
        $task_parameters.attributes=@("ComputerName","name","Credential","wait")
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
                $params.credential = $cred
                if($task.wait -eq "true"){$params.wait=$true}
                $params.whatif = $WhatIfPreference
                
                switch($task.action)
                    {
                        "stop"
                            {
                                $function_name="stop-zWindows"
                                Foreach($item in $server_list)
                                    {
                                        if(Test-IsAlive -ComputerName $item -credential $cred)
                                            {
                                                $servers+=$item  
                                            }
                                            else
                                            {
                                                Write-Error "$server is not accessible and will be skipped for task $($task.name) in play $($play.name)."
                                                continue
                                            }              
                                    }
                                $params.computername = $servers
                                break
                            }
                                                
                        "start"
                            {
                                $function_name="start-zWindows"
                                Foreach($item in $server_list)
                                    {
                                        if(-NOT(Test-IsAlive -ComputerName $item -credential $cred))
                                            {
                                                $servers+=$item  
                                            }
                                            else
                                            {
                                                Write-Warning "$server is already online and will not be started per task $($task.name) in play $($play.name)."
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


Export-ModuleMember -Function Stop-zWindows
Export-ModuleMember -Function Start-zWindows
Export-ModuleMember -Function Get-zTask
Export-ModuleMember -Function Get-zTaskParameters
Export-ModuleMember -Function Invoke-zTask