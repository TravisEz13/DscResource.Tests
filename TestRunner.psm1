<#
    .SYNOPSIS
        Runs all tests (including common tests) on all DSC resources in the given folder.

    .PARAMETER ResourcesPath
        The path to the folder containing the resources to be tested.

    .EXAMPLE
        Start-DscResourceTests -ResourcesPath C:\DscResources\DscResources
#>
function Start-DscResourceTests
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $ResourcesPath
    )
    
    $testsPath = $pwd
    Push-Location -Path $ResourcesPath

    Get-ChildItem | ForEach-Object {
        $moduleName = $_.Name
        $destinationPath = Join-Path -Path $ResourcesPath -ChildPath $moduleName

        Write-Verbose -Message "Copying common tests from $testsPath to $destinationPath"
        Copy-Item -Path $testsPath -Destination $destinationPath -Recurse -Force 

        Push-Location -Path $moduleName
        
        Write-Verbose "Running tests for $moduleName"
        Invoke-Pester

        Pop-Location
    }

    Pop-Location
}

<#
    .SYNOPSIS
        Runs tests based on a moduleInfoList

    .PARAMETER List
        The BuildInfoList to run the tests based on

    .EXAMPLE
        Invoke-AppveyorTest -ModuleInfoList $list

#>
Function Invoke-AppveyorTest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateScript({ Test-BuildInfoList -list $_})]
        [PsObject[]] $ModuleInfoList
    )
    Write-Info 'Starting Test stage...'

    foreach($moduleInfo in $moduleInfoList)
    {
        $ModuleName = $moduleInfo.ModuleName
        $ModulePath = $moduleInfo.ModulePath
        $ModulePath = $moduleInfo.ModulePath

        if(test-path -Path $modulePath)
        {
            $CodeCoverage = $moduleInfo.CodeCoverage
            $tests = $moduleInfo.Tests
            $tests | %{ 
                $results = Invoke-RunTest -Path $_ -CodeCoverage $CodeCoverage
                $resultTable = Invoke-ProcessTestResults -results $results
                $script:failedTestsCount += $resultTable.failedTestsCount
                $script:PassedTestsCount += $resultTable.PassedTestsCount
            }
        }
    }

    if((Get-Command -Name Set-AppveyorBuildVariable -ErrorAction SilentlyContinue))
    {
        Set-AppveyorBuildVariable -Name PoshBuildTool_FailedTestsCount -Value $script:failedTestsCount
        Set-AppveyorBuildVariable -Name PoshBuildTool_PassedTestsCount -Value $script:PassedTestsCount
    }
    else
    {
        $env:PoshBuildTool_FailedTestsCount = $script:failedTestsCount
        $env:PoshBuildTool_PassedTestsCount = $script:PassedTestsCount
    }

    Write-Info "End Test Stage, Passed: $script:passedTestsCount ; failed $script:failedTestsCount"
}

function Invoke-ProcessTestResults
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [Object]
        $results
    )
    $failedTestsCount =0
    $passedTestsCount =0
    $CodeCoverageCounter = 1
    foreach($res in $results)
    {
        if($res)
        {
            Write-Info "processing result of type $($res.gettype().fullname)"
            $failedTestsCount += $res.FailedCount 
            $passedTestsCount += $res.PassedCount 
            $CodeCoverageTitle = 'Code Coverage {0:F1}%'  -f (100 * ($res.CodeCoverage.NumberOfCommandsExecuted /$res.CodeCoverage.NumberOfCommandsAnalyzed))
            
            if($res.CodeCoverage.MissedCommands.Count -gt 0)
            {
                $res.CodeCoverage.MissedCommands | ConvertTo-FormattedHtml -title $CodeCoverageTitle | out-file ".\out\CodeCoverage$CodeCoverageCounter.html"
            }
            else 
            {
                '' | ConvertTo-FormattedHtml -title $CodeCoverageTitle | out-file ".\out\CodeCoverage$CodeCoverageCounter.html"                            
            }
            
            $CodeCoverageCounter++
        }
    }
    return @{
        failedTestsCount = $failedTestsCount
        passedTestsCount = $passedTestsCount
    }
}

Export-ModuleMember -Function @( 'Start-DscResourceTests' )
