#requires -RunAsAdministrator
Param(
    $name
)
$script=$MyInvocation.MyCommand.source
$parent=split-path -parent $script
$exe=Join-Path $parent "duh.xml"
if($name -eq $null){$name=split-path $parent -leaf}
new-service -name $name -DisplayName $name -BinaryPathName $exe
