#Requires -module RCIS-Command
<#
    .SYNOPSIS
    zHelper provides utility functions for zEngine and its related modules.
    
    .DESCRIPTION
    Provides common output and testing functions for zEngine and it's modules.
    
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

#Modules do not inherit the $Global scope which sets command defaults for the user session via RCIS-Command
#This will clone those settings (Proxy Settings and Powershell Remoting settings for IncluePortinSPN
$PSDefaultParameterValues=$Global:PSDefaultParameterValues.clone()

#endregion


function ConvertTo-zObject
    {
        [cmdletbinding()]
        Param(
        [parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [System.Object]$InputObject,
        [String]$TypeName
        )
        Process
            {
                $record=new-object psobject
                $properties_list=$InputObject | get-member -MemberType Properties
                foreach($property in $properties_list)
                    {
                        add-member -InputObject $record -Name $property.name -value $inputobject.($property.name) -MemberType NoteProperty
                    }
                $record.psobject.TypeNames.Insert(0, "$TypeName")
                $record
            }
    }

function Output-zObject
    {
        [cmdletbinding(SupportsShouldProcess=$true)]
        Param(
        [Parameter(mandatory=$false,ValueFromPipeline=$true)]
        [System.Object]$InputObject,
        
        [Parameter(mandatory=$false)]
        [System.Object]$task,
        
        [Parameter(mandatory=$false)]
        [System.Object]$play

        )
        
        Process
            {
                $callstack=Get-PSCallStack
                foreach($call in $callstack)
                {
                    if($call.arguments -match "PassThru=True")
                    {$PassThru=$True}
                    if($call.arguments -match "verbose")
                    {$VerbosePreference="Continue"}
                }
                if($InputObject -eq $null)
                    {
                        return
                    }
                else
                    {
                        $InputObject | add-member -Name Play -MemberType NoteProperty -Value $play.name
                        $InputObject | add-member -Name Role -MemberType NoteProperty -Value $play.role
                        $InputObject | add-member -Name Task -MemberType NoteProperty -Value $task.name
                        $InputObject | add-member -Name Action -MemberType NoteProperty -Value $task.action
                        $InputObject | add-member -Name Time -MemberType NoteProperty -Value (get-date)
                        if($VerbosePreference -eq "Continue")
                            {
                                $message=$InputObject | format-table -AutoSize | out-string
                                #Write-Verbose $message
                                out-message -message $message -type Verbose -destination all
                            }
                        if($PassThru)
                            {
                                $InputObject
                            }
                    }
            }
    }

Function Test-IsVirtual
    {
        <#
            .SYNOPSIS
            Test-IsVirtual performs a quick WMI query to see if a machine is a VM or not.
            
            .DESCRIPTION
            Returns $False if the computer is physical and $True is it is virtual
            
            .Parameter Computername
            The machine name to perform the lookup against

            .Parameter Credential
            Alternate credentials if need to connect to that machine.
            
            .Examples
            Test-IsVirtual -ComputerName dvbox02.dvcorp.rcis.com

            Will check to see if DVBOX02 is a virtual

            .NOTES
            Author:   Jason Brisbin
            Version:  .1
            Date:     6/21/2016
            
            .LINK
            
            .ROLE
            Development
        #>
        [cmdletbinding()]
        param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$ComputerName,
        
        [parameter(Mandatory=$true)]
        [pscredential]$credential
        )        
        Process
            {   
                
                Try
                {
                    if(Test-Connection -ComputerName $ComputerName -count 1 -Quiet)
                    {
                    $result=Get-WmiObject win32_computersystem -ComputerName $ComputerName -Credential $cred                   
                    if($result.Manufacturer -contains "VMWare")
                    {
                        $false
                    }
                    Else
                    {
                        $true
                    }
                    }
                    else
                    {
                        Throw "Unable to connect to $Computername"
                    }
                }
                Catch
                {
                    #Write-Error $_
                    out-message -message $_ -type Error -destination All
                }
            }
    }

Function Test-IsAlive
    {
        <#
            .SYNOPSIS
            Test-IsAlive pings a remote device to see if it's powered on.
            
            .DESCRIPTION
            Returns $False if the computer is down and $True is it is online
            
            .Parameter Computername
            The machine name to perform the lookup against
            
            .Examples
            Test-IsAlive -ComputerName dvbox02.dvcorp.rcis.com

            Will check to see if DVBOX02 responds to ping

            .NOTES
            Author:   Jason Brisbin
            Version:  .1
            Date:     6/21/2016
            
            .LINK
            
            .ROLE
            Development
        #>
        [cmdletbinding()]
        param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$ComputerName,

        [parameter(Mandatory=$true)]
        [pscredential]$credential

        )        
        Process
            {   
                $sessionOptions = New-PSSessionOption -IncludePortInSPN
				if (-not ($global:PSDefaultParameterValues.'test-wsman:sessionoption')) { $global:PSDefaultParameterValues.Add("test-wsman:sessionoption", $sessionOptions) }
                Try
                {
                    if(Test-Connection -ComputerName $ComputerName -count 1 -Quiet -ErrorAction SilentlyContinue)
                    {
                        if(Test-WSMan -ComputerName $ComputerName -Credential $credential -Authentication default -ErrorAction SilentlyContinue)
                        {
                            #Write-Verbose "Successfully connected to $Computername with WinRM"
                            out-message -message "Successfully connected to $Computername with WinRM" -type Verbose -destination all
                            $true
                        }
                        elseif(Invoke-command -computername $computername -Credential $credential -ScriptBlock{$true} -ErrorAction SilentlyContinue)
                        {
                            #Write-Verbose "Successfully connected to $Computername with WinRM"
                            out-message -message "Successfully connected to $Computername with WinRM" -type Verbose -destination all
                            $true
                        }
                        else
                        {
                            #Write-Verbose "Unable to connect to $Computername with WinRM"
                             out-message -message "Unable to connect to $Computername with WinRM" -type Verbose -destination all
                            $false  
                        }
                        
                    }
                    else
                    {
                        #Write-Verbose "Unable to ping $Computername"
                        out-message -message "Unable to ping $Computername" -type Verbose -destination All
                        $false
                    }

                }
                Catch
                {
                    #Write-Verbose $_
                    out-message -message $_ -type Verbose -destination All
                    $false                    
                }
            }
    }

Function Wait-UntilAlive
    {
        <#
 
        #>

        [cmdletbinding(SupportsShouldProcess=$true)]
        param
        (      
            [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [alias("VM","Guest","Name")]
            [string]$ComputerName,

            [parameter(Mandatory=$false)]
            [boolean]$State=$true,

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

                                Try
                                {                                
                                    #Get the PowerState of 1 or Many VM's
                                    #Compare that to DesiredState ($state)
                                    #If they all match $state operation was successful
                                    #Otherwise continue to wait until the Timeout has been reached
                                    
                                    Do                              
                                    {
                                        #Write-Verbose "Testing connection to $ComputerName for $state." 
                                        out-message -message "Testing connection to $ComputerName for $state." -type Verbose -destination all

                                        $Duration=New-TimeSpan -Start $StartTime -end (get-date)
                                        if($duration.seconds -ge $timeout)
                                        {
                                            Throw "The wait operation has timed out for $($computername -join ", ")"
                                            Break
                                        }
                                        $report=test-isalive -ComputerName $computername -credential $Credential                                                                        
                                        if(($currentstates.count -eq 1) -and ($currentstates -eq $state))
                                        {
                                            Break
                                        }
                                        start-sleep -Seconds $Interval
                                    }
                                    while($report -ne $state) 


               
                                }
                                Catch
                                {
                                    #write-error $_
                                    out-message -message $_ -type Error -destination All
                                    Return
                                }
                                               
                
            }
        
        End
            {

            }
    }

Function Get-zParameters
{
Param(
[Parameter(Mandatory=$true)]
[String]$Function
)
    Try
        {
            $properties=(get-command $function -ErrorAction Stop).ParameterSets | select -ExpandProperty parameters |  select -ExpandProperty name
        }        
    Catch
        {
            #Write-Error "$function was not found"
            out-message -message "$function was not found" -type Error -destination All
            Return
        }
    
    $defaultParameters=@(
    "Verbose"            
    "Debug"              
    "ErrorAction"        
    "WarningAction"      
    "InformationAction"  
    "ErrorVariable"     
    "WarningVariable"    
    "InformationVariable"
    "OutVariable"        
    "OutBuffer"
    "PipelineVariable"
    "WhatIf" 
    "Confirm"
    )
        $unique_properties=$properties|Where{$defaultParameters -notcontains $_}
        return $unique_properties
}

function Test-zParameters
    {
        Param(
        [system.object]$task,
        [system.object]$parameters
        )
        $taskproperties=$task | get-member -MemberType Properties | select -expandproperty name | where {$_ -ne "task"}
        if($parameters -notcontains "action"){$parameters+="action"} #all tasks require an action parameter for Routing, but this is not needed by every function as a parameter
        $unique_properties=$taskproperties|Where{$parameters -notcontains $_}
        if($unique_properties -eq $null)
            {
                Return $true
            }
        Else
            {
                Throw "Parameter mismatch for type $($task.localname):$($task.name) of play $($play.name).`nParameters can be:$parameters"
            }
    }

function out-message()
    {
        param
        (
        [string]$message,       
        
        [ValidateSet("Error","Info","Debug","Warning","Verbose")]
        [alias("t","cat","category")]
        [string]$type="Info",
        
        [ValidateSet("All","Windows","Log","Console")]
        [alias("Target","Dest","D")]
        [string]$destination="All",

        [ValidateSet("Continue","SilentlyContinue","Stop","Ignore","Inquire")]
        [string]$action="Continue"
        )

        #timestamp will be appended to each message in the log file.
        $timestamp=get-date -format "MM/dd/yyyy hh:mm:ss tt"
        if($Global:PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){$VerbosePreference="Continue"}
        else{$VerbosePreference="SilentlyContinue"}
        if($Global:PSCmdlet.MyInvocation.BoundParameters["debug"].IsPresent){$DebugPreference="Continue"}
        else{$DebugPreference="SilentlyContinue"}

        #column sizes
        $function_max_size=25
        $type_max_size=8
        $timestamp_maxsize=25
        $pshost = get-host
        $pshost.ui.RawUI.BufferSize.width=500
        #Needed to create well formatted console output
        $max_message=($pshost.ui.rawUI.buffersize.width) - ($function_max_size + $type_max_size)

        #Records the name of the function inside the logfile and on console output/
        [string]$function=(Get-PSCallStack)[1].functionname       

        $function_exist=$function -replace "(<.+>)",""
        
        #If there is no function create the function placeholder "Script Body"
        #The function name may include a script block token.....so make it pretty
        if($function_exist.Length -eq 0)
            {
                $function="Script Main"
            }
        else
            {
                
                $function=$function.replace("<",":").replace(">","")
            }

        #Format the function column
        if($function.length -lt $function_max_size)
            {
                #Pad the string
                $padding=$function_max_size-$function.length
                $function=$function.PadRight($function_max_size)

                 #Convert the text into Title Casing
                $type=(Get-Culture).TextInfo.ToTitleCase($type)
                $function=(Get-Culture).TextInfo.ToTitleCase($function)    
            }
        else
            {
                #Trim the string                
                $function=$function.Substring(0,$function_max_size-5)
                $function=$function+"...  "                 
                $type=(Get-Culture).TextInfo.ToTitleCase($type)
                $function=(Get-Culture).TextInfo.ToTitleCase($function)
            }
       
    

        #This gets the name of the script calling the module
        #This is the source we will use for writting Windows Events
        #We will also use this to setup the central log store
        $callingscript=(Get-PSCallStack | where {$_.ScriptName -ne $null} |select -last 1).command

        #Build the UNC path and then check to see if a folder exists for this log already.
        $logdirectory=$VarStore.technologies.powershell.logging.path
        $logdirectory=join-path $logdirectory $callingscript.replace(".ps1","")
        if(-not(test-path $logdirectory)){new-item -ItemType Directory -Path $logdirectory}
        $logfile="$($env:Computername)$(get-date -f _yyyy-MM-dd).log"
        $logfile=join-path $logdirectory $logfile


    
        #Format the type column, type is constrained with Validate Set so no need to handle anything other than accepted values.
        if($type.length -lt $type_max_size)
            {
                $padding=$type_max_size-$type.length
                $type_formatted=$type.PadRight($type_max_size)
            }

        #Format the timestamp column
        if($timestamp.length -lt $timestamp_maxsize)
            {
                $padding=$timestamp_maxsize-$timestamp.length
                $timestamp=$timestamp.PadRight($timestamp_maxsize)
            }
            

        #Setup flags for output streams to control where we send messages.
        [boolean]$output_console=$false
        [boolean]$output_log=$false
        [boolean]$output_windows=$false
        
        switch($destination)
        {
            "All"
                {
                    $output_console=$true
                    $output_log=$true
                    $output_windows=$true
                }
            "Console" {$output_console=$true}
            "Windows" {$output_windows=$true}
            "Log"     {$output_log=$true}                   
        }
        
        $message=$function+$message
        
        if($output_windows)
        {


        }

        if($output_log)
        {
            $logmessage=$timestamp+$type_formatted+$message
            Out-File -InputObject $logmessage -FilePath $logfile -Encoding ascii -append -WhatIf:$False
        }

        if($output_console)
        {
            #Format the length of the console message        
            $consolemessage=$message
            if($consolemessage.length -gt $max_message){$consolemessage=$message.substring(0,$max_message)}

            switch($type)
                {
                    "Debug"
                        {                                                          
                            write-debug $consolemessage
                            break
                        }
                   "Verbose"
                        {
                            write-verbose $consolemessage
                            break
                        }
                    "Warning"
                        {
                            write-warning $consolemessage -WarningAction $action
                            break
                        }
                    "Error"
                        {
     
                            write-Warning $consolemessage -WarningAction $action
                            break
                        }
                    "Info"
                        {
                            $consolemessage=$type_formatted+$consolemessage
                            Write-Information -MessageData $consolemessage -InformationAction $action
                            break
                        }
                    default
                        {
                            write-Output $consolemessage
                            break
                        }
                }
        
        }
    }


Export-ModuleMember -Function out-Message
Export-ModuleMember -Function ConvertTo-zObject
Export-ModuleMember -Function Test-IsVirtual
Export-ModuleMember -Function Test-IsAlive
Export-ModuleMember -Function Wait-UntilAlive
Export-ModuleMember -Function Get-zParameters
Export-ModuleMember -Function Test-zParameters
Export-ModuleMember -Function Output-zObject
