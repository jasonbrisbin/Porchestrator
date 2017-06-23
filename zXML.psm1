#Requires -version 5
<#
    .Synopsis
    zXML is a module which supports zEngine with XML document functions

    .Description
    This module provides the capabilities to link XML documents, associate plays and roles, as well as validate the XML document elements against zEngine modules.
        
    .Notes
    Version 5 was required due to the New-TemporaryFile command used in composing an XML document.   
#>

function Merge-zXML
    {
        <#
            .Synopsis
            Merges XML document elements into a master document
            
            .Description
            Provides the ability to compose an XML document from various documents linked together with the attribute "Import".  This function returns an XML document.
            
            .Parameter Path
            Provide the UNC path to an XML document to process Imports on.
            
            .Output
            Creates and returns an XML Document object which can be written to disk or passed on to other functions.
            
            .Role
            Development
            
            .Notes
            Version: 1
            Author: Jason Brisbin
            
        #>
        [cmdletbinding()]
        Param(
        [parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_})]
        [string]$path
        )
        Begin
            {
                Try
                    {
                        $xml=[xml](get-content $path)
                        $xml=ConvertTo-zXMLlowercase -xml $xml
                    }
                Catch
                    {
                        #Write-Error "Unable to load XML document $path."
                        out-message -message "Unable to load XML document $path." -type Error -destination all
                    }
                $script:ImportDepth++
                $maxdepth=10
                if($script:ImportDepth -ge $maxdepth)
                    {
                        #Write-Error "There are more than $($maxdepth) nested XML documents to complete merge." -erroraction Stop
                        out-message -message "There are more than $($maxdepth) nested XML documents to complete merge." -erroraction Stop -type Error -destination all
                    }
            }
        Process
            {
                #This XPath Query will return all nodes that an an attribute named import and store that in a collection
                #There are 2 types of imports supported
                #Local = import from the current document
                
                $collection=$xml.SelectNodes("//*[@import]")
                if($collection.count -gt 0)
                    {
                        foreach($xmlnode in $collection)
                            {
                                $ConfirmPreference="None"
                                $tree="--"*($script:ImportDepth-1)
                                #write-verbose "$($tree)$($xmlnode.name) [$(split-path -leaf $xmlnode.import)]"
                                out-message -message "$($tree)$($xmlnode.name) [$(split-path -leaf $xmlnode.import)]" -type Verbose -destination Console
                                #write-debug "Current Depth: $($script:ImportDepth) ($($xmlnode.import))"
                                out-message -message "Current Depth: $($script:ImportDepth) ($($xmlnode.import))" -type Debug -destination Console
                                #Validate the path is accesible and load the XML
                                if(-not(Test-Path $XmlNode.import))
                                    {
                                        Throw [System.IO.FileNotFoundException] "File $($XmlNode.import) not found."
                                        exit
                                    }
                                
                                #$import_xml=[xml](get-content $xmlnode.import)
                                if($XmlNode.import -eq $path){Throw "Circular reference detected. Cannot merge $($XmlNode.import) with $path as defined in $($xmlnode.name)." }
                                
                                #Now that we have the content of the XML, we need to see if that file has any imports.
                                #File A, could import FIle B and File B could import File C...
                                $import_xml=Merge-zXML -path $xmlnode.import
                                
                                #Case insensitivity for matching Play Names from a doc using Import to the xml that was imported.
                                $node=$import_xml.SelectSingleNode("//*[@name='$($xmlnode.name)']")
                                
                                #Load the first matching playname
                                
                                if($node.count -eq 0)
                                    {
                                        #Write-Error "$($xmlnode.name) was not found in $($xmlnode.import)."
                                        out-message -message "$($xmlnode.name) was not found in $($xmlnode.import)." -type Error
                                        Exit
                                    }
                                
                                #Replace the original XML node with the new play
                                $xml.DocumentElement.ReplaceChild(($xml.ImportNode($node,$true)),$xmlnode) | out-null
                            }
                    }
            }
        End
            {
                $xml=Copy-zTarget -xml $xml
                $script:ImportDepth--
                return $xml
            }
    }

function Format-zXML
    {
        <#
            .Synopsis
            Merges XML document elements into a master document
            
            .Description
            Provides the ability to compose and XML document from various documents linked together with the attribute "Import".
            
            .Parameter Path
            Provide the UNC path to an XML document to process Imports on.
            
            .Output
            Creates and returns an XML Document object which can be written to disk or passed on to other functions.
            
            .Role
            Development
            
            .Notes
            Version: 1
            Author: Jason Brisbin
            
        #>
        [cmdletbinding()]
        Param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [xml]$xml
        )
        Begin
            {
                $xml=ConvertTo-zXMLlowercase -xml $xml
            }
        Process
            {
                #Read each play
                #Serial = individiual steps for each server by order specfied, add computername attribute
                #parallel = simple list of of servers added to computername attribute
                $play_list=$xml.SelectNodes("//play")
                foreach($play in $play_list)
                    {
                        #Set defaults for Method and Order
                        if($play.method -eq $null){$play.setAttribute("method","serial")}
                        if($play.order -eq $null)
                            {
                                #Write-Warning "Servers will be processed in order listed in the XML document for $($play.name)."
                                $server_id=$play.SelectNodes("server").order -join ","
                                $play.setAttribute("order",$server_id)
                            }
                        
                        $serverlist=@()
                        $play_order=$play.order.split(",")
                        foreach($id in $play_order)
                            {
                                #If order was specified in Play but Not in Server elements then server list will be empty
                                $serverlist+=$play.SelectNodes("server") | where{$_.order -eq $id} | select -ExpandProperty name
                            }
                        #Handle the case if the order was present in play but in the server elements.
                        if($serverlist -eq $null)
                        {
                            $serverlist=$play.SelectNodes("server")
                        }
                        

                        if($play.method -eq "serial")
                            {
                                #Serial                                
                                $tasklist=$play.selectnodes("*[not(self::server)]")
                                    $tasklist | foreach{if($_.computername)
                                            {
                                                #Write-Error "Computername is not allowed in task $($task.name) in play $($play.name)" -erroraction stop
                                                out-message -message "Computername is not allowed in task $($task.name) in play $($play.name)" -erroraction stop -type Error -destination all
                                            }
                                    }
                                $counter=0
                                foreach($server in $serverlist)
                                    {
                                        foreach($task in $tasklist)
                                            {
                                                $newtask=$task.clonenode($true)
                                                $newtask.RemoveAttribute("order")
                                                
                                                $tasknum=++$counter
                                                $newtask.setAttribute("computername",$server)
                                                $newtask.setAttribute("task",$tasknum)
                                                $play.appendChild($newtask) | out-null
                                            }
                                    }
                            }
                        
                        elseif($play.method -eq "parallel")
                            {
                                #parallel
                                $serverlist_string=$serverlist -join ","
                                $tasklist=$play.selectnodes("*[not(self::server)]")
                                    $tasklist | foreach{if($_.computername)
                                            {
                                                #Write-Error "Computername is not allowed in task $($task.name) in play $($play.name)" -erroraction stop
                                                out-message -message "Computername is not allowed in task $($task.name) in play $($play.name)" -erroraction stop -type Error -destination all
                                            }
                                    }
                                
                                $counter=0
                                foreach($task in $tasklist)
                                    {
                                        $tasknum=++$counter
                                        $task.setAttribute("computername",$serverlist_string)
                                        $task.setAttribute("task",$tasknum)
                                    }
                                
                            }
                        $play.SelectNodes("*[not(@computername)]") | ForEach-Object{$play.RemoveChild($_)} | out-null
                        $play.SelectNodes("server") |  ForEach-Object{$play.RemoveChild($_)}  | out-null
                    }
            }
        End
            {
                return [xml]$xml
            }
    }

Function Test-zXML
    {
        <#
            .Description
            Test-zXML will take a provided zXML element and ensure it is well formed based
            on installed modules and the the playbook document structure.
        #>
        [cmdletbinding()]
        Param(
        [parameter(Mandatory=$true,valuefrompipeline=$true)]
        [xml]$xml
        )
        Begin
            {
                <#
                    The attribute table is a lookup table built by querying modules to find supported tasks
                    and their parameters.  Name represents keywords for which a module supports using the get-ztask function
                    from each module in the module directory.  Value represents the parameters accepted by a module
                    using the get-ztaskparameters function of that module.
                    
                    Example Attribute Table:
                    Name                           Value
                    ----                           -----
                    ScheduledTask                  {ComputerName, Name, Credential}
                    Play                           {Name, Role, Order, Method...}
                    Process                        {ComputerName, Name, Credential, workingdirectory...}
                    IISSite                        {ComputerName, Name, Credential}
                    IISAppPool                     {ComputerName, Name, Credential}
                    Role                           {Name, Import}
                    playbook                       {}
                    Script                         {ComputerName, Name, Credential}
                    Wait                           {ComputerName, Name, Time, Seconds}
                    Service                        {ComputerName, Name, Credential}
                #>
                <#[hashtable]$attributetable=@{}
                [string]$root_element="playbook"
                [array]$attributetable.$root_element=@()
                [array]$attributetable.Play=@("Name","Role","Order","Method","Import","Credential")
                [array]$attributetable.Role=@("Name","Import")
                [array]$attributetable.Server=@("Name","order")#>
                [array]$excludedattributes=@("Task","Action")
                #$module_list=get-module z* | where{$_.Exportedfunctions.ContainsKey("get-ztask")}
                
                #Loading the routing table from the SCRIPT scope set by zEngine gives me the definitive list about what was loaded.
               # $module_list=$Global:routing_table.values | select -ExpandProperty Name
                
                <#
                foreach($module in $module_list)
                    {
                        
                        $task=Invoke-Expression "$module\get-zTask"
                        $parameter_hashtable=Invoke-Expression "$module\get-zTaskParameters"
                        $task_parameters=$parameter_hashtable["attributes"]
                        $attributetable.$task=$task_parameters
                    }
                #>
            }
        Process
            {
                <#
                    Any test that fails will set this to false in addition to
                    Writting an error
                #>
                [boolean]$result=$true
                
                <#
                    ValidateTask attributes align with module properties
                    An XML Navigator creates a record set which allows for easy navigation
                    Much like an ADO record set
                    This functions like a cursor
                #>
                $XMLNavigator=$xml.CreateNavigator()
                
                <#
                    Moves the cursor (current record to beginning of the document a.k.a #document
                    then navigates to the firstelement which will be our root of <playbook>
                #>
                #Write-Information -MessageData "Performing XML validation."
                out-message -message "Performing XML validation." -type Info -destination All
                $XMLNavigator.MoveToRoot() #<?xml...
                $null=$XMLNavigator.MoveToFirstChild() #<playbook>
                if($XMLNavigator.HasAttributes)
                    {
                        #Write-Error "Root node `"$($xmlnavigator.localname)`" may not contain attributes."
                        out-message -message "Root node `"$($xmlnavigator.localname)`" may not contain attributes." -type Error -destination all
                        $result=$false
                        return $result
                    }
                $depth=0


                <#
                    The repeat loop will use a pathing algorythm.  It performs 1 move per iteration. The script will always try to:
                    1. Move down the hierarchy if possible (children)
                    2. Move sideways if there are no children (siblings)
                    3. If there are niether siblings or children, move up the hierarchy (parents)
                #>

                :DocumentLoop While($XMLNavigator.NodeType -ne "Root")
                    {
                        [boolean]$element_is_valid=$true
                        If($XMLNavigator.MoveToFirstChild()){$depth++} #children
                        elseif($XMLNavigator.MoveToNext()){$depth=$depth} #siblings
                        else #parents
                            {                                
                                while(-not($XMLNavigator.MoveToNext()))
                                    {
                                        $null=$XMLNavigator.MoveToParent()
                                        $depth--
                                        
                                        #stop processing as we are at the top of the document.
                                        #this break statement will stop execution and move back to the loop label "DocumentLoop"
                                        if($XMLNavigator.NodeType -eq "Root")
                                            {
                                                #write-verbose "XML Document Validation Complete."
                                                out-message -message "XML Document Validation Complete." -type Verbose -destination all
                                                break DocumentLoop
                                            }
                                    }
                            }
                        


                        #Validate parameters
                        #If the element is a comment then local name will be an empty string.
                        if($XMLNavigator.LocalName -eq ""){continue}

                        #Check to make sure the new Element is of an appropriate type using the attribute table (Playbook,Play,Service,Process,Etc)
                        If(-not(Test-zXMLElement -elementtype $XMLNavigator.LocalName -attributetable $Global:Attribute_Table))
                            {
                                $result=$false
                                $element_is_valid=$false
                                #Write-Error "Invalid task type `"$($XMLNavigator.localname)`" specified.  Acceptable tasks types are [$($Global:Attribute_Table.keys)].`n$($xmlnavigator.outerxml)."
                                out-message -message "Invalid task type `"$($XMLNavigator.localname)`" specified.  Acceptable tasks types are [$($Global:Attribute_Table.keys)].`n$($xmlnavigator.outerxml)." -type Error -destination All
                            }
                        
                        #If the element is valid and is the lowest branch in the tree, collect its attributes
                        elseif($XMLNavigator.HasAttributes)
                            {
                                $attributes=Get-zXMLAttribute -xmlnavigator $xmlnavigator | where{$excludedattributes -notcontains $_}
                                #$attributes+="name"
                                [boolean]$valid=Test-zXMLAttribute -attributetable $Global:Attribute_Table -Attributes $attributes -xmlnavigator $XMLNavigator
                                if(-not($valid))
                                    {
                                        #Write-Error "Attributes provided are invalid.  Attributes in task: $($attributes).  Valid attributes: $($Global:Attribute_Table[$XMLNavigator.localname])."
                                        out-message -message "Attributes provided are invalid.  Attributes in task: $($attributes).  Valid attributes: $($Global:Attribute_Table[$XMLNavigator.localname])." -type Error -destination All
                                        $element_is_valid=$false
                                        $result=$false
                                    }
                            }
                        
                        #Collect and print debug output
                        $cursor_name=$XMLNavigator.GetAttribute("name",$null)
                        $cursor_task=$XMLNavigator.GetAttribute("task",$null)
                        $cursor_element=$XMLNavigator.localname
                        $space="    " * $depth
                        $message="Level: $depth "
                        if($element_is_valid){$message+="VALID "}
                        else{$message+="ERROR "}
                        $message+="$space<$cursor_element "
                        if($cursor_name){$message+=" name=$cursor_name" }
                        if($cursor_task){$message+=" task=$cursor_task" }
                        #write-debug $message
                        out-message -message $message -type Debug -destination all
                    }
                
                #Result will be TRUE as defined in the initialization unless a test fails.  then that line fails
                return $result
            }
    }

Function Get-zXMLAttribute
    {
        <#
            .Description
            This function takes and XPathNavigator (cursor location) and collects all of the
            element attributes.  It returns an array with all of the attributes
        #>
        Param(
        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Xml.XPath.XPathNavigator]$XMLNavigator
        )
        
        [array]$zAttributes=@()
        if($XMLNavigator.MoveToFirstAttribute())
            {
                do
                    {
                        $zAttributes+=$XMLNavigator.LocalName
                    }while($xmlnavigator.MoveToNextAttribute())
                
                #Attibutes of elements are implemented as children of elements
                #once all attributes have been collected you need to move the cursor up a level
                #to continue working with elements
                #I suspect the SCOPE IS SCRIPT or GLOBAL for XMLNavigators so you need to leave the cursor where you found it.
                $null=$XMLNavigator.MoveToParent()
            }
        return $zAttributes
    }

Function Test-zXMLElement
    {
        <#
            .Description
            Ensures that EVERY element in the xml document is handled by zEngine or by an installed module
            
        #>
        Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$elementtype,
        
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [hashtable]$attributetable
        )
        <#
            Attributetable is a hashtable and ContainsKey will check the Hashtable name property
        #>
        if($attributetable.keys -icontains $elementtype)
            {
                return $True
            }
        Else
            {
                return $False
            }
    }

function Test-zXMLAttribute
    {
        <#
            .Description
            Checks all attributes from a given XMLElement against the attribute table.
        #>
        Param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [array]$Attributes,
        
        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [hashtable]$attributetable,
        
        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Xml.XPath.XPathNavigator]$xmlnavigator
        )
        
        [boolean]$result=$true
        $elementtype=$XMLNavigator.LocalName
        
        #Loop through the array of attribute values (name,action,task,computername,etc)
        foreach($item in $Attributes)
            {
                #Lookup the values in the attribute table for (Service,Play,Playbook,etc)
                #check that array to see if it contains the attribute vale
                #Icontains ignores case!
                #if it not found report the error and diagnostic information.
                if($attributetable[$elementtype] -icontains $item)
                    {
                        $result=$True
                    }
                Else
                    {
                        $result=$False
                        <#
                        Write-Warning "`"$Item`" is an invalid parameter for element type $elementtype"
                        Write-Warning "Acceptable values: $($attributetable[$elementtype] | sort)"
                        Write-Warning "Values supplied: $($attributes | sort)"
                        Write-Error "Invalid parameter specified.`nSource: $($xmlnavigator.OuterXml)"
                        #>

                        out-message -message "`"$Item`" is an invalid parameter for element type $elementtype" -type Warning -destination All
                        out-message -message "Acceptable values: $($attributetable[$elementtype] | sort)" -type Warning -destination All
                        out-message -message "Values supplied: $($attributes | sort)" -type Warning -destination All
                        out-message -message "Invalid parameter specified.`nSource: $($xmlnavigator.OuterXml)" -type Error -destination All

                        
                    }
            }
        return $result
    }

function Copy-zTarget
    {
        [cmdletbinding()]
        Param(
        [xml]$xml
        )
        Begin
            {
                
            }
        Process
            {
                #This XPath Query will return all nodes that an an attribute named import and store that in a collection
                #There are 2 types of imports supported
                #Local = import from the current document
                $role_list=$xml.SelectNodes("//role")
                $play_list=$xml.SelectNodes("//play")
                
                foreach($play in $play_list)
                    {
                        
                        #if($play.hasChildNodes)
                        if($play.server.count -eq 0)
                            {
                                $server_list=(($role_list.where({$_.name -eq $play.role})).server)
                                foreach($server in $server_list)
                                    {
                                        $node=$server.clonenode($true)
                                        $play.appendChild($node) | out-null
                                    }
                            }
                    }
                
                #May need to remove the Target node to support nested playbooks.
                $target=$xml.SelectSingleNode("//target")
                if($target)
                    {
                        $xml.playbook.RemoveChild($target) | out-null
                    }
                return $xml
            }
        End
            {
                
            }
    }

Function Import-zXML
    {
        [cmdletbinding()]
        Param(
        [parameter(Mandatory=$true)]
        [validatescript({Test-Path $_})]
        [string]$path
        )
        
        #Logging interface
        
        If ($PSBoundParameters['Debug'])
            {
                $DebugPreference = 'Continue'
            }
        
        [int]$script:ImportDepth=0
        
        #Write-Information -MessageData "`nMerging XML Files in $path`n"
        out-message -message "Merging XML Files in $path"
        #$Master = Merge-zXML -xml $Master
        $Master = Merge-zXML -path $path
        $master = format-zXML -xml $Master
        
        #Write-Verbose "Merge complete`n"
        out-message -message "Merge complete" -type Verbose -destination All
        $Composed=New-TemporaryFile
        $Master.save($Composed.fullname)
                
        
        Write-Eventlog -LogName Application -Source zEngine -EntryType Information -Message (get-content $Composed | Out-String) -EventId 1001
        remove-item $Composed
        return $master
    }

Function ConvertTo-zXMLlowercase
    {
        Param(
        [xml]$xml
        )
        $xml_lowercase=[xml]($xml.OuterXml.ToLower())
        return $xml_lowercase
    }


Function Update-zXMLTemplate
{
    #Certain reserved words exist outside of modules they must be excluded from the dynamic generation of the template.
    $exclude_elements=@("Playbook","Role","Play","Server")

    #All tasks will be provided a computername based on the role assignment, however they cannot be specified directly inside a task.  It can only be done via role assignment
    $exclude_properties=@("ComputerName")
    
    #Collect the list of elements to add to Plays, excluding our reserved words
    $assignment_list=$Attribute_Table.keys | Where{$exclude_elements -inotcontains $_} | Sort-Object

    #Load the started.xml document which contains the basic document structure.
    $module_path=get-module zXML | select -ExpandProperty modulebase 
    $starter_path=Join-Path $module_path "template\Starter.xml"
    $template_path=Join-Path $module_path "template\Template.xml"
    $template=[xml](get-content $starter_path) 

    #Select the play node as modules can only extend our play options.
    $play_template=$template.DocumentElement.SelectSingleNode("Play")

    #Add each element to Plays including their require properties/attributes
    foreach($assignment in $assignment_list)
    {        
        $element=[System.Xml.XmlElement]($template.CreateElement($assignment))
        foreach($attribute in $global:Attribute_Table[$assignment])
        {
            if($exclude_properties -inotcontains $attribute)
            {
                $element.SetAttribute($attribute,$null)
            }
        }
        $play_template.AppendChild($element) | out-null
    }
    $template=ConvertTo-zXMLlowercase -xml $template
    $template.Save($template_path)

}

<#
Export-ModuleMember -Function Import-zXML
Export-ModuleMember -Function Copy-zTarget
Export-ModuleMember -Function Merge-zXML
Export-ModuleMember -Function Format-zXML
Export-ModuleMember -Function Test-zXML
Export-ModuleMember -Function ConvertTo-zXMLlowercase

Import-zXML,Copy-zTarget,Merge-zXML,Format-zXML,Test-zXML,ConvertTo-zXMLlowercase
#>


