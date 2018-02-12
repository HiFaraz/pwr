$pwrRoot = $PSScriptRoot;
$pwrName = (split-path -path $MyInvocation.MyCommand.Definition -leaf).split('.ps1')[0];
& "$pwrRoot\bin\pwr.ps1" @args;
