$buildInfoType = 'Microsoft.PowerShell.DSC.Build.ModuleInfo'

<#
    .SYNOPSIS
        Creates an object representing what should be built and tested

    .PARAMETER Auto
        Try to auotmatically create the object

    .PARAMETER ModuleName
        The name of the module

    .PARAMETER ModulePath
        The path to the module

    .PARAMETER CodeCoverage
        The path to the files to run CodeCoverage for

    .PARAMETER Tests
        The path to the tests to be run

    .EXAMPLE
        New-BuildModuleInfo -Auto

    .EXAMPLE
        New-BuildModuleInfo -ModuleName myModule -ModulePath C:\myModule -CodeCoverage @(C:\myModule\myModule.psm1) -tests @(C:\myModule\tests\myModule.tests.ps1)
#>
function New-BuildModuleInfo
{
    [CmdletBinding()]
    param
    (
        [Parameter(ParameterSetName='Auto', Mandatory=$true)]
        [switch]
        $Auto, 

        [Parameter(ParameterSetName='Auto')]
        [Parameter(ParameterSetName='Manual', Mandatory=$true)]
        [string]
        $ModuleName ,

        [Parameter(ParameterSetName='Auto')]
        [Parameter(ParameterSetName='Manual', Mandatory=$true)]
        [string]
        $ModulePath ,

        [string[]] $CodeCoverage = $null,

        [string[]] $Tests = $null
    )
    if($auto)
    {
        $psd1Path = (Get-ChildItem *.psd1 -recurse | Select-Object -first 1).FullName
        if([string]::IsNullOrWhiteSpace($modulePath))
        {
            $modulePath = Split-Path $psd1Path
        }
        if([string]::IsNullOrWhiteSpace($moduleName))
        {
            $moduleName = Split-Path -leaf $modulePath
        }

        if(!$CodeCoverage)
        {
            $CodeCoverage = @()
            Get-ChildItem (Join-path $modulePath *.psm1) -recurse | ForEach-Object { $CodeCoverage += $_.FullName }            
        }

        if(!$tests)
        {
            $tests = (Resolve-Path .\).ProviderPath
        }
    }

    $moduleInfo = New-Object PSObject -Property @{
            ModuleName = $ModuleName
            ModulePath = $ModulePath
            CodeCoverage = $CodeCoverage
            Tests = $Tests
        }
    $moduleInfo.pstypenames.clear()
    $moduleInfo.pstypenames.add($buildInfoType)
    return $moduleInfo
}

<#
    .SYNOPSIS
        Verified a parameter is a BuildInfoList type

    .PARAMETER List
        The object to verify is a BuildInfoList

    .EXAMPLE
        Test-BuildInfoList -List $list

#>
function Test-BuildInfoList
{
    [CmdletBinding()]
    param
    (
        $list
    )
    
    $list | ForEach-Object {
        if($_.pstypenames -inotcontains $buildInfoType)
        {
            throw "Must be an array of type $buildInfoType"
        }
    }
    return $true
}

<#
    .SYNOPSIS
        Writes information to the build log

    .PARAMETER Message
        The Message to write

    .EXAMPLE
        Write-Info -Message "Some build info"

#>
function Write-Info {
    [CmdletBinding()]
     param
     (
         [Parameter(Mandatory=$true, Position=0)]
         [string]
         $Message
     )

    Write-Host -ForegroundColor Yellow  "[Build Info] [$([datetime]::UtcNow)] $message"
}

Export-ModuleMember -Function @( 'New-BuildModuleInfo', 'Test-BuildInfoList', 'Write-Info' )