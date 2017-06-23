<#
    .Synopsis
    zEngine is a datacenter orchestration tool which processes playbooks to automate a series of related tasks.
    
    .Description
    zEngine provides a tool to combine tasks that need to be performed in sequence to support a business or IT process.  Please note attribute names and values are case sensitive when using the "import" feature.
    
    .PARAMETER Path
    Path to the XML playbook to execute. (Mandatory/Validated with Test-Path)
    
    .PARAMETER Cred
    Provide a credential object to execute individual tasks with. (Optional)
    
    .PARAMETER Secret
    The Secret parameter take a username and will attempt to create a Credential object from Secret Server. (Optional)

    .PARAMETER PassThru
    An optional parameter which will return the native powershell objects from each module. (Optional)
    
    .Example
    zEngine.ps1 -path robotstart.xml
    
    If no additional parameters other than path are specified the script will prompt for a credential set to use.  This command will process robotstart.xml, importing any other XML documents as needed.
    
    
    .Example
    zEngine.ps1 -path robotstart.xml -credential $cred
    
    Runs the script with a specified set of credentials for remote commands.
    
    
    .Example
    zEngine.ps1 -path robotstart.xml -credential $cred -PassThru
    
    Runs the script with a specified set of credentials for remote commands and will return the native powershell objects provided by each module.  Useful for reporting an potentially pipeline applications.
    
    
    .Example
    zEngine.ps1 -path robotstart.xml -credential $cred -verbose
    
    Runs the script with a specified set of credentials for remote commands and will display the native powershell objects provided by each module in the verbose stream 

    .LINK
        
    .ROLE
    Development

    .Notes
    Should we automatically remove the Transcript file or just reference it in the Eventlog entry without the content.  Size limitations on event log entries could be a problem
    Should we check to ensure services exist before changing them?
    Domain qualification required for credentials when run in the lab?
#>
#Requires -version 5

#region Parameters
[cmdletbinding(SupportsShouldProcess=$True,DefaultParameterSetName="Creds")]
Param(
    [parameter(Mandatory=$true)]
    [validatescript({Test-Path $_})]
    [string]$path,

    [parameter(mandatory=$false,ParameterSetName="Creds")]
    [alias("Credential")]
    [pscredential]$cred,

    [parameter(mandatory=$true,ParameterSetName="RunAs")]
    [alias("RunAs")]
    [string]$Secret,

    [parameter(mandatory=$false)]
    [switch]$PassThru
)
#endregion


#region Main
#Load all the modules for zEnginer
$Capitalize = (Get-Culture).TextInfo
$Global:PSCmdlet=$pscmdlet
#Clear the error records
$Error.Clear()

#The Global:Routing_Table will be used by several functions, so at run time I am making it available to all modules and functions loaded by this script.
$Global:Routing_Table=@{}
[string]$root_element="playbook"
$Global:Attribute_Table=@{
    Playbook=@()
    Play=@("Name","Role","Order","Method","Import","Credential")
    Role=@("Name","Import")
    Server=@("Name","Order")
}

$zEngineDir=split-path -parent $pscmdlet.MyInvocation.MyCommand.source
$zEngineConfig=[xml](get-content "$zEngineDir\zEngine.config")
$Reserved_Task_Types=[array]$zEngineConfig.config.common.ReservedTaskTypes -split ","
$module_directory=$zEngineConfig.config.common.moduledirectory

import-module -Name "\\pdnas01\Scripts\Modules\RCIS-Command.psm1" -Verbose:$false -force -erroraction stop
import-module -Name $zEngineDir\zXML.psm1 -Verbose:$false -force -erroraction stop
import-module -Name $zEngineDir\zHelper.psm1 -Verbose:$false -WarningAction SilentlyContinue -force  -erroraction stop #Added SilentlyContinue because ConvertTo is not considered an approved verb despite being used by common cmdlets.

#Test to see if the eventlog source is already configured,if its not add it.         
[boolean]$Log_Source_Exists=try{[System.Diagnostics.EventLog]::SourceExists('zEngine')}catch{$false}
if(-not($Log_Source_Exists))
    {
        out-message -message "Windows Event Source zEngine does not exist.  A new window will be launched as a Local Administrator to create the event source." -type Error -destination all
        Start-Process $PSHOME\powershell.exe -Verb RunAs -ArgumentList "-noprofile","-Command  `"New-EventLog -LogName Application -Source zEngine`"" -Wait
                
        #Retry, if this fails its time to bail
       [boolean]$Log_Source_Exists=try{[System.Diagnostics.EventLog]::SourceExists('zEngine')}catch{$false}
if(-not($Log_Source_Exists))
        {
            out-message "Event Source does not exist, please rerun the script with Local Administrator privileges." -type Error -destination all
            Exit
        }
    }

#Load all modules from the module path
$module_path=join-path (split-path -parent $pscmdlet.MyInvocation.MyCommand.source) $module_directory
$module_list=get-childitem $module_path -Filter *.psm1 | select -ExpandProperty fullname
foreach($module in $module_list)
    {
        $loaded_module=import-module -name $module -Verbose:$false -force -PassThru
        $route_value=Invoke-Expression "$loaded_module\get-zTask"  
        $parameter_hashtable=Invoke-Expression "$loaded_module\get-zTaskParameters"
        $task_parameters=$parameter_hashtable["attributes"]
                           
        if($Reserved_Task_Types -contains $route_value)
            {                
                write-zlog "Module $($loaded_module) is attempting to use a Reserved Task Type `"$($Route_value)`".  The following Task Types cannot be used in a module [$($ReservedTaskTypes)].  Module will not be loaded."
                out-message -message "Module $($loaded_module) is attempting to use a Reserved Task Type `"$($Route_value)`".  The following Task Types cannot be used in a module [$($ReservedTaskTypes)].  Module will not be loaded." -type Error -destination All
                continue               
            }
        elseif(($route_value -eq $null) -or ($route_value -eq ""))
            {
                out-message -message "Module $($loaded_module) did not return a value for get-zTask.  Module will not be loaded." -type Error -destination All
                exit 
            }
        elseif(($parameter_hashtable -eq $null) -or ($task_parameters -eq ""))
            {
                out-message -message "Module $($loaded_module) did not return a value for get-zTaskParameters.  Module will not be loaded." -type Error -destination All
                exit 
            }
        elseif($Global:Routing_Table.ContainsKey($route_value))
            {
                out-message -message "Module $($loaded_module) is attempting to use Task Type `"$($Route_value)`" which was already loaded by $($Global:Routing_Table.$route_value).  Module will not be loaded." -type Error -destination All                
                exit               
            }
        else
            {
                $Global:Routing_Table.$route_value=$loaded_module
                $Global:Attribute_Table.$route_value=$task_parameters   
            }
    }

#Set the default credentials to be used in the script
if($PSCmdlet.ParameterSetName -eq "RunAs")
    {
        $secretcred=Get-rSecret -Secret $Secret -CredentialObject
        if($secret -eq $null)
            {
                out-message -message "Unable  to get secret $($Secret)" -type Error -destination All -action Stop     
            }
        elseif($?)
            {
                $cred=$secretcred
            }
    }
elseif($PSCmdlet.ParameterSetName -eq "creds")
    {
        if($cred -eq $null)
            {
                $cred=get-credential
            }
    }


If(-not(Test-rCredential -Cred $cred))
{
    out-message -message "Unable to validate $($cred.UserName).  Script will exit." -type Error -destination All -action Stop
}


#Playbook files need to be parsed and merged before execution
#Import-zXML handles linking XML documents as well as producing the flattened file necessary
#for zEngine to do its work. Import-zXML will transform the provided file and returns
#a new file that has been composed and validated
$ComposedXML=Import-zXML -path $path -Debug:$DebugPreference -Verbose:$VerbosePreference

if(-not(Test-zXML -xml $ComposedXML))
{
    out-message -message "XML Validation failed.  Script will now exit." -type Error -destination All -action Stop                 
    exit
}


#VMWare plugins dont work well with modules.  The snapins don't properly unload after execution
#In the main script we will call the load at the beginning and then unload at the end.
if(get-module zVM)
{
out-message "Connecting to vCenter." -destination Console
Try{connect-zVM -credential $cred}
catch{Throw "Unable to connect to vCenter."}

}

#Load the ComposedXML
#foreach($play in $ComposedXML.DocumentElement.childnodes)
foreach($play in $ComposedXML.DocumentElement.selectnodes("//play"))
    {
        $message="Processing Play: $($Capitalize.ToTitleCase($play.name))"
        out-message -message $message -type Info -destination All
        
        #If credentials are specified in the play they should be used instead
        #However if Secret Server does not return a secret then revert back to
        #the credential object supplied to zEngine.
        if($play.credential)
            {
                $play_credentials=Get-rSecret -Secret $play.credential -CredentialObject
                if($play_credentials -eq $null)
                    {
                        out-message -message "Unable to obtain secret $($play.credential) for $($play.name)" -type Warning -destination All
                        write-warning "Unable to obtain secret $($play.credential) for $($play.name)"
                        $play_credentials=$cred
                    }
            }
        else
            {
                $play_credentials=$cred
            }
        
        foreach($task in $play.childnodes)
            {                
                $message="$($Capitalize.ToTitleCase($task.task)). $($Capitalize.ToTitleCase($task.localname)) set to $($Capitalize.ToTitleCase($task.action)) for $($Capitalize.ToTitleCase($task.name)) on $($task.computername)"
                out-message -message $message -type Info -destination all
                if($Global:PSCmdlet.MyInvocation.BoundParameters["Confirm"].IsPresent)
                    {
                        $choice=Read-host "Continue? [Y/N]"
                        if($choice -eq "N"){return}
                    }

                if($task.credential){$task_credential=Get-rSecret -Secret $task.credential -CredentialObject}
                else{$task_credential=$play_credentials}
                $params=@{}
                $params.task = $task
                $params.play = $play
                $params.credential = $task_credential
                if($PSCmdlet.MyInvocation.BoundParameters[“Verbose”].IsPresent)
                {
                    $params.verbose=$true
                }
                if($PSCmdlet.MyInvocation.BoundParameters[“Debug”].IsPresent)
                {
                    $params.debug=$true
                }
                if($PSCmdlet.MyInvocation.BoundParameters[“Whatif”].IsPresent)
                {
                    $params.whatif=$true
                }
                
                $taskname=$task.localname
                $modulename=$Global:Routing_Table.$taskname.name
                if(-not([string]::IsNullOrEmpty($modulename)))
                {
                    
                    Invoke-Expression "$modulename\Invoke-zTask @params"                
                }
            }
    }

#VMWare modules get loaded by the zVM module.  Those modules load other modules that must be unloaded at the end of execution.
#otherwise the Snapin becomes unuseable
if(get-module zVM){disconnect-zVM}

if($error){out-message -message $Error -type Error}
#endregion



